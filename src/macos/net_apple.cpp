/**
 * @file net_apple.cpp
 * @brief Metal Quake — UDP driver on Apple's Network.framework.
 *
 * Implements the driver interface declared in net_udp.h. The driver
 * contract Quake expects is a BSD-ish "open a socket, optionally connect
 * it to a peer, write/read datagrams" model. Network.framework is
 * flow-oriented, so we bridge:
 *
 *   - UDP_OpenSocket(port)      -> nw_listener_t bound to local port,
 *                                  responses routed into the socket's
 *                                  recvQueue.
 *   - UDP_Listen(true)          -> single shared listener on port 27500
 *                                  for server-mode accept. New peers get
 *                                  their own socket slot via the
 *                                  pendingConnections ring so the engine
 *                                  sees them through UDP_CheckNewConnections.
 *   - UDP_Connect(sock, addr)   -> cached outbound nw_connection_t.
 *   - UDP_Write(sock, ..., addr)-> if addr is nullptr or matches the cached
 *                                  peer, reuse the cached connection. If
 *                                  addr differs, look up or create a
 *                                  one-shot connection for that peer in
 *                                  the socket's peer cache.
 *   - UDP_Read(sock, ..., *addr)-> dequeue from the socket's recvQueue;
 *                                  the source endpoint is extracted at
 *                                  receive time so the engine can tell
 *                                  peers apart.
 *   - UDP_Broadcast(sock, ...)  -> send to 255.255.255.255:27500. Responses
 *                                  arrive back on the socket's listener.
 *
 * The model is deliberately simple. Peer connections cache by a tiny
 * address-array and evict oldest when full; for a single Quake session
 * the peer count is <= maxplayers so eviction is rare.
 */

#include <Network/Network.h>
#include <dispatch/dispatch.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <string.h>

extern "C" {
    #define __QBOOLEAN_DEFINED__
    typedef int qboolean;
    #define true 1
    #define false 0
    #include "quakedef.h"
    #include "net_udp.h"
    #undef true
    #undef false
}

// ---------------------------------------------------------------------------
// Constants & shared state
// ---------------------------------------------------------------------------

#define MAX_CONNECTIONS       16
#define MAX_PEERS_PER_SOCKET  16
#define MAX_PACKET_SIZE       8192
#define RECV_QUEUE_SIZE       64
#define PENDING_QUEUE_SIZE    32
#define DEFAULT_PORT_STR      "27500"
#define DEFAULT_PORT          27500

struct RecvPacket {
    byte              data[MAX_PACKET_SIZE];
    int               len;
    struct qsockaddr  addr;
};

// Per-socket receive ring buffer. Head/tail are volatile because the
// producer runs on nwQueue while the consumer (engine) runs on the main
// thread; __sync_synchronize covers the read/write fence.
struct RecvQueue {
    RecvPacket  packets[RECV_QUEUE_SIZE];
    volatile int head;
    volatile int tail;
};

// Tiny address-keyed cache of outbound peer connections. Each entry
// represents a datagram conversation the socket has had with that peer;
// reusing the connection avoids per-send setup cost. The cache is
// FIFO-evicted when full, which is fine because Quake rarely talks to
// more than maxplayers peers from a single socket.
struct PeerConn {
    bool               inUse;
    struct qsockaddr   addr;
    nw_connection_t    conn;
};

struct Socket {
    bool                allocated;
    int                 localPort;
    nw_listener_t       listener;       // bound to localPort; accepts return traffic
    nw_connection_t     outboundConn;   // set by UDP_Connect, primary peer
    struct qsockaddr    outboundPeer;   // address of outboundConn, for matching
    PeerConn            peers[MAX_PEERS_PER_SOCKET];
    int                 nextPeerSlot;   // FIFO eviction pointer
    RecvQueue           rx;
};

static Socket           g_sockets[MAX_CONNECTIONS] = {};
static nw_listener_t    g_serverListener = nullptr;
static dispatch_queue_t g_nwQueue        = nullptr;

// Pending-socket ring — the server-side UDP_Listen feeds this, engine
// drains it via UDP_CheckNewConnections.
static struct {
    int          entries[PENDING_QUEUE_SIZE];
    volatile int head;
    volatile int tail;
} g_pending = {};

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

static int FindFreeSocket(void) {
    // Index 0 is reserved so "socket 0" doesn't collide with Quake's
    // convention of treating zero as "no socket" in some paths.
    for (int i = 1; i < MAX_CONNECTIONS; i++) {
        if (!g_sockets[i].allocated) return i;
    }
    return -1;
}

static bool AddrEqual(const struct qsockaddr *a, const struct qsockaddr *b) {
    const struct sockaddr_in *sa = (const struct sockaddr_in *)a;
    const struct sockaddr_in *sb = (const struct sockaddr_in *)b;
    return sa->sin_family     == sb->sin_family
        && sa->sin_port       == sb->sin_port
        && sa->sin_addr.s_addr == sb->sin_addr.s_addr;
}

static void QSockaddrToHostPort(const struct qsockaddr *addr, char *host, size_t hostLen, char *port, size_t portLen) {
    const struct sockaddr_in *sin = (const struct sockaddr_in *)addr;
    inet_ntop(AF_INET, &sin->sin_addr, host, (socklen_t)hostLen);
    snprintf(port, portLen, "%d", ntohs(sin->sin_port));
}

static bool EndpointToQSockaddr(nw_endpoint_t endpoint, struct qsockaddr *out) {
    if (!endpoint || !out) return false;
    memset(out, 0, sizeof(*out));
    struct sockaddr_in *sin = (struct sockaddr_in *)out;
    sin->sin_family = AF_INET;

    nw_endpoint_type_t type = nw_endpoint_get_type(endpoint);
    if (type != nw_endpoint_type_host && type != nw_endpoint_type_address) {
        return false;
    }
    const char *host = nw_endpoint_get_hostname(endpoint);
    uint16_t    port = nw_endpoint_get_port(endpoint);
    if (host) {
        if (inet_pton(AF_INET, host, &sin->sin_addr) != 1) {
            struct hostent *he = gethostbyname(host);
            if (!he || he->h_length < 4) return false;
            memcpy(&sin->sin_addr, he->h_addr_list[0], 4);
        }
    }
    sin->sin_port = htons(port);
    return true;
}

static nw_parameters_t MakeUDPParameters(void) {
    nw_parameters_t params = nw_parameters_create_secure_udp(
        NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION);
    nw_parameters_set_multipath_service(params, nw_multipath_service_interactive);
    // Allow fast reuse on rebind; LAN server browses will open + close
    // the same port in rapid succession.
    nw_parameters_set_reuse_local_address(params, true);
    return params;
}

// Enqueue an inbound packet into a socket's rx ring. Drops silently on
// overflow so a slow-reading engine doesn't stall the network thread.
static void EnqueueRx(int sock, const byte *data, int len, const struct qsockaddr *from) {
    if (sock < 0 || sock >= MAX_CONNECTIONS) return;
    RecvQueue &q = g_sockets[sock].rx;
    int next = (q.tail + 1) % RECV_QUEUE_SIZE;
    if (next == q.head) return;

    int copyLen = (len > MAX_PACKET_SIZE) ? MAX_PACKET_SIZE : len;
    memcpy(q.packets[q.tail].data, data, copyLen);
    q.packets[q.tail].len = copyLen;
    if (from) q.packets[q.tail].addr = *from;
    __sync_synchronize();
    q.tail = next;
}

static void PushPending(int sock) {
    int next = (g_pending.tail + 1) % PENDING_QUEUE_SIZE;
    if (next == g_pending.head) return;
    g_pending.entries[g_pending.tail] = sock;
    __sync_synchronize();
    g_pending.tail = next;
}

// Attach a continuous receive loop to a connection, routing everything
// into the given socket's rx queue. Works for both the server listener's
// per-peer connections and the client's outbound connection.
static void StartReceiveLoopOn(nw_connection_t conn, int sock) {
    if (!conn) return;
    nw_connection_receive(conn, 1, MAX_PACKET_SIZE,
        ^(dispatch_data_t content, nw_content_context_t ctx, bool is_complete, nw_error_t error) {
            (void)ctx;
            if (content) {
                const void *bytes;
                size_t      size;
                dispatch_data_t contiguous = dispatch_data_create_map(content, &bytes, &size);

                struct qsockaddr from;
                nw_endpoint_t remote = nw_connection_copy_endpoint(conn);
                if (!EndpointToQSockaddr(remote, &from)) memset(&from, 0, sizeof(from));

                EnqueueRx(sock, (const byte *)bytes, (int)size, &from);
                (void)contiguous;
            }
            if (!error && !is_complete) {
                StartReceiveLoopOn(conn, sock);
            }
        });
}

// Find or create a cached peer connection for a socket. Returns the
// cached nw_connection_t ready to send. NULL on failure.
static nw_connection_t GetOrCreatePeerConn(int sock, const struct qsockaddr *addr) {
    if (sock < 0 || sock >= MAX_CONNECTIONS || !g_sockets[sock].allocated) return nullptr;
    Socket &s = g_sockets[sock];

    for (int i = 0; i < MAX_PEERS_PER_SOCKET; i++) {
        if (s.peers[i].inUse && AddrEqual(&s.peers[i].addr, addr)) {
            return s.peers[i].conn;
        }
    }

    // Find a free slot or evict the oldest (FIFO via nextPeerSlot).
    int slot = -1;
    for (int i = 0; i < MAX_PEERS_PER_SOCKET; i++) {
        if (!s.peers[i].inUse) { slot = i; break; }
    }
    if (slot < 0) {
        slot = s.nextPeerSlot;
        s.nextPeerSlot = (s.nextPeerSlot + 1) % MAX_PEERS_PER_SOCKET;
        if (s.peers[slot].conn) {
            nw_connection_cancel(s.peers[slot].conn);
            s.peers[slot].conn = nullptr;
        }
    }

    char host[INET_ADDRSTRLEN], port[16];
    QSockaddrToHostPort(addr, host, sizeof(host), port, sizeof(port));
    nw_endpoint_t   ep     = nw_endpoint_create_host(host, port);
    nw_parameters_t params = MakeUDPParameters();
    nw_connection_t conn   = nw_connection_create(ep, params);
    if (!conn) return nullptr;

    nw_connection_set_queue(conn, g_nwQueue);
    nw_connection_start(conn);
    StartReceiveLoopOn(conn, sock);

    s.peers[slot].inUse = true;
    s.peers[slot].addr  = *addr;
    s.peers[slot].conn  = conn;
    return conn;
}

// ---------------------------------------------------------------------------
// Driver lifecycle
// ---------------------------------------------------------------------------

extern "C" int UDP_Init(void) {
    g_nwQueue = dispatch_queue_create("com.metalquake.network", DISPATCH_QUEUE_SERIAL);
    memset(g_sockets, 0, sizeof(g_sockets));
    memset(&g_pending, 0, sizeof(g_pending));
    Con_Printf("UDP_Init: Network.framework UDP driver ready\n");
    return 0;
}

extern "C" void UDP_Shutdown(void) {
    if (g_serverListener) {
        nw_listener_cancel(g_serverListener);
        g_serverListener = nullptr;
    }
    for (int i = 0; i < MAX_CONNECTIONS; i++) {
        Socket &s = g_sockets[i];
        if (s.listener)     { nw_listener_cancel(s.listener);     s.listener = nullptr; }
        if (s.outboundConn) { nw_connection_cancel(s.outboundConn); s.outboundConn = nullptr; }
        for (int p = 0; p < MAX_PEERS_PER_SOCKET; p++) {
            if (s.peers[p].conn) { nw_connection_cancel(s.peers[p].conn); s.peers[p].conn = nullptr; }
            s.peers[p].inUse = false;
        }
        s.allocated = false;
        s.rx.head = 0; s.rx.tail = 0;
    }
    g_pending.head = 0;
    g_pending.tail = 0;
}

// ---------------------------------------------------------------------------
// Server-mode listener (single shared — Quake's NET_Init path)
// ---------------------------------------------------------------------------

extern "C" void UDP_Listen(qboolean state) {
    if (state && !g_serverListener) {
        nw_parameters_t params = MakeUDPParameters();
        nw_endpoint_t   local  = nw_endpoint_create_host("0.0.0.0", DEFAULT_PORT_STR);
        nw_parameters_set_local_endpoint(params, local);

        g_serverListener = nw_listener_create(params);
        nw_listener_set_new_connection_handler(g_serverListener, ^(nw_connection_t peer) {
            // Allocate a socket slot for this incoming peer so the engine
            // sees each client as its own socket ID.
            int idx = FindFreeSocket();
            if (idx < 0) { nw_connection_cancel(peer); return; }
            g_sockets[idx].allocated    = true;
            g_sockets[idx].localPort    = DEFAULT_PORT;
            g_sockets[idx].outboundConn = peer;
            EndpointToQSockaddr(nw_connection_copy_endpoint(peer), &g_sockets[idx].outboundPeer);
            nw_connection_set_queue(peer, g_nwQueue);
            nw_connection_start(peer);
            StartReceiveLoopOn(peer, idx);
            PushPending(idx);
        });
        nw_listener_set_queue(g_serverListener, g_nwQueue);
        nw_listener_start(g_serverListener);
        Con_Printf("UDP_Listen: server listener on port %s\n", DEFAULT_PORT_STR);
    } else if (!state && g_serverListener) {
        nw_listener_cancel(g_serverListener);
        g_serverListener = nullptr;
        Con_Printf("UDP_Listen: server listener stopped\n");
    }
}

// ---------------------------------------------------------------------------
// Socket creation / destruction
// ---------------------------------------------------------------------------

extern "C" int UDP_OpenSocket(int port) {
    int idx = FindFreeSocket();
    if (idx < 0) return -1;

    Socket &s = g_sockets[idx];
    memset(&s, 0, sizeof(s));
    s.allocated = true;
    s.localPort = port;

    // Bind a listener on the requested port so return traffic (connect
    // replies, broadcast responses) flows back into this socket's rx
    // queue. Port 0 lets the OS pick an ephemeral port.
    char portStr[16];
    snprintf(portStr, sizeof(portStr), "%d", port);
    nw_parameters_t params = MakeUDPParameters();
    nw_endpoint_t   local  = nw_endpoint_create_host("0.0.0.0", portStr);
    nw_parameters_set_local_endpoint(params, local);

    s.listener = nw_listener_create(params);
    nw_listener_set_new_connection_handler(s.listener, ^(nw_connection_t peer) {
        // Each inbound datagram from a distinct remote endpoint arrives
        // as a new connection on the listener. Route it into this socket.
        nw_connection_set_queue(peer, g_nwQueue);
        nw_connection_start(peer);
        StartReceiveLoopOn(peer, idx);
    });
    nw_listener_set_queue(s.listener, g_nwQueue);
    nw_listener_start(s.listener);

    return idx;
}

extern "C" int UDP_CloseSocket(int sock) {
    if (sock < 0 || sock >= MAX_CONNECTIONS || !g_sockets[sock].allocated) return -1;
    Socket &s = g_sockets[sock];
    if (s.listener)     { nw_listener_cancel(s.listener);     s.listener = nullptr; }
    if (s.outboundConn) { nw_connection_cancel(s.outboundConn); s.outboundConn = nullptr; }
    for (int i = 0; i < MAX_PEERS_PER_SOCKET; i++) {
        if (s.peers[i].conn) { nw_connection_cancel(s.peers[i].conn); s.peers[i].conn = nullptr; }
        s.peers[i].inUse = false;
    }
    s.allocated = false;
    s.rx.head = 0; s.rx.tail = 0;
    return 0;
}

extern "C" int UDP_Connect(int sock, struct qsockaddr *addr) {
    if (sock < 0 || sock >= MAX_CONNECTIONS || !g_sockets[sock].allocated || !addr) return -1;
    Socket &s = g_sockets[sock];

    if (s.outboundConn) {
        nw_connection_cancel(s.outboundConn);
        s.outboundConn = nullptr;
    }

    char host[INET_ADDRSTRLEN], port[16];
    QSockaddrToHostPort(addr, host, sizeof(host), port, sizeof(port));
    nw_endpoint_t   ep     = nw_endpoint_create_host(host, port);
    nw_parameters_t params = MakeUDPParameters();
    s.outboundConn = nw_connection_create(ep, params);
    s.outboundPeer = *addr;

    nw_connection_set_queue(s.outboundConn, g_nwQueue);
    nw_connection_start(s.outboundConn);
    StartReceiveLoopOn(s.outboundConn, sock);
    return 0;
}

// ---------------------------------------------------------------------------
// Datagram I/O
// ---------------------------------------------------------------------------

extern "C" int UDP_CheckNewConnections(void) {
    if (g_pending.head == g_pending.tail) return -1;
    int sock = g_pending.entries[g_pending.head];
    __sync_synchronize();
    g_pending.head = (g_pending.head + 1) % PENDING_QUEUE_SIZE;
    return sock;
}

extern "C" int UDP_Read(int sock, byte *buf, int len, struct qsockaddr *addr) {
    if (sock < 0 || sock >= MAX_CONNECTIONS || !g_sockets[sock].allocated) return 0;
    RecvQueue &q = g_sockets[sock].rx;
    if (q.head == q.tail) return 0;

    int copyLen = q.packets[q.head].len;
    if (copyLen > len) copyLen = len;
    memcpy(buf, q.packets[q.head].data, copyLen);
    if (addr) *addr = q.packets[q.head].addr;

    __sync_synchronize();
    q.head = (q.head + 1) % RECV_QUEUE_SIZE;
    return copyLen;
}

extern "C" int UDP_Write(int sock, byte *buf, int len, struct qsockaddr *addr) {
    if (sock < 0 || sock >= MAX_CONNECTIONS || !g_sockets[sock].allocated) return -1;
    Socket &s = g_sockets[sock];

    // Decide which connection to send on.
    //   - If addr is null, use outboundConn (must have been set by UDP_Connect).
    //   - If addr matches outboundConn's peer, reuse outboundConn.
    //   - Otherwise look up / create a peer connection in the socket's cache.
    nw_connection_t conn = nullptr;
    if (!addr) {
        conn = s.outboundConn;
    } else if (s.outboundConn && AddrEqual(addr, &s.outboundPeer)) {
        conn = s.outboundConn;
    } else {
        conn = GetOrCreatePeerConn(sock, addr);
    }
    if (!conn) return -1;

    byte *sendBuf = (byte *)malloc(len);
    memcpy(sendBuf, buf, len);
    dispatch_data_t data = dispatch_data_create(sendBuf, len, g_nwQueue, ^{ free(sendBuf); });
    nw_connection_send(conn, data, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true,
        ^(nw_error_t error) {
            if (error) Con_Printf("UDP_Write: send error\n");
        });
    return len;
}

extern "C" int UDP_Broadcast(int sock, byte *buf, int len) {
    if (sock < 0 || sock >= MAX_CONNECTIONS || !g_sockets[sock].allocated) return -1;

    // Build a qsockaddr for 255.255.255.255:27500 and route through the
    // same peer-cache path as UDP_Write. That way broadcast responses
    // come back into the socket's rx queue via its listener.
    struct qsockaddr bcast;
    struct sockaddr_in *sin = (struct sockaddr_in *)&bcast;
    memset(&bcast, 0, sizeof(bcast));
    sin->sin_family     = AF_INET;
    sin->sin_addr.s_addr = htonl(INADDR_BROADCAST);
    sin->sin_port        = htons(DEFAULT_PORT);
    return UDP_Write(sock, buf, len, &bcast);
}

// ---------------------------------------------------------------------------
// Address helpers (mostly string / DNS conversion)
// ---------------------------------------------------------------------------

extern "C" char *UDP_AddrToString(struct qsockaddr *addr) {
    static char buf[64];
    struct sockaddr_in *sin = (struct sockaddr_in *)addr;
    snprintf(buf, sizeof(buf), "%s:%d",
             inet_ntoa(sin->sin_addr), ntohs(sin->sin_port));
    return buf;
}

extern "C" int UDP_StringToAddr(char *string, struct qsockaddr *addr) {
    struct sockaddr_in *sin = (struct sockaddr_in *)addr;
    memset(sin, 0, sizeof(*sin));
    sin->sin_family = AF_INET;

    char *colon = strrchr(string, ':');
    if (colon) {
        *colon = '\0';
        sin->sin_port        = htons(atoi(colon + 1));
        sin->sin_addr.s_addr = inet_addr(string);
        *colon = ':';
    } else {
        sin->sin_addr.s_addr = inet_addr(string);
        sin->sin_port        = htons(DEFAULT_PORT);
    }
    return 0;
}

extern "C" int UDP_GetSocketAddr(int sock, struct qsockaddr *addr) {
    struct sockaddr_in *sin = (struct sockaddr_in *)addr;
    memset(sin, 0, sizeof(*sin));
    sin->sin_family      = AF_INET;
    sin->sin_addr.s_addr = INADDR_ANY;

    if (sock < 0 || sock >= MAX_CONNECTIONS || !g_sockets[sock].allocated) {
        sin->sin_port = htons(DEFAULT_PORT);
        return 0;
    }
    int lport = g_sockets[sock].localPort > 0 ? g_sockets[sock].localPort : DEFAULT_PORT;
    sin->sin_port = htons(lport);
    return 0;
}

extern "C" int UDP_GetNameFromAddr(struct qsockaddr *addr, char *name) {
    struct sockaddr_in *sin = (struct sockaddr_in *)addr;
    strcpy(name, inet_ntoa(sin->sin_addr));
    return 0;
}

extern "C" int UDP_GetAddrFromName(char *name, struct qsockaddr *addr) {
    struct sockaddr_in *sin = (struct sockaddr_in *)addr;
    memset(sin, 0, sizeof(*sin));
    sin->sin_family = AF_INET;
    sin->sin_port   = htons(DEFAULT_PORT);

    sin->sin_addr.s_addr = inet_addr(name);
    if (sin->sin_addr.s_addr == INADDR_NONE) {
        struct hostent *he = gethostbyname(name);
        if (!he) return -1;
        memcpy(&sin->sin_addr, he->h_addr_list[0], he->h_length);
    }
    return 0;
}

extern "C" int UDP_AddrCompare(struct qsockaddr *addr1, struct qsockaddr *addr2) {
    struct sockaddr_in *s1 = (struct sockaddr_in *)addr1;
    struct sockaddr_in *s2 = (struct sockaddr_in *)addr2;
    if (s1->sin_addr.s_addr != s2->sin_addr.s_addr) return -1;
    if (s1->sin_port        != s2->sin_port)        return 1;
    return 0;
}

extern "C" int UDP_GetSocketPort(struct qsockaddr *addr) {
    return ntohs(((struct sockaddr_in *)addr)->sin_port);
}

extern "C" int UDP_SetSocketPort(struct qsockaddr *addr, int port) {
    ((struct sockaddr_in *)addr)->sin_port = htons(port);
    return 0;
}
