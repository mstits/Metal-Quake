#include <Network/Network.h>
#include <dispatch/dispatch.h>
#include <arpa/inet.h>
#include <netdb.h>

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
// Network.framework State
// ---------------------------------------------------------------------------
#define MAX_CONNECTIONS 16
static nw_listener_t udpListener = nullptr;
static nw_connection_t activeConnections[MAX_CONNECTIONS] = {nullptr};
static dispatch_queue_t nwQueue;

// ---------------------------------------------------------------------------
// Helper Functions
// ---------------------------------------------------------------------------
static void StartReceiving(int socket); // forward decl
static int FindFreeConnection() {
    for (int i = 1; i < MAX_CONNECTIONS; i++) {
        if (!activeConnections[i]) return i;
    }
    return -1;
}

// ---------------------------------------------------------------------------
// UDP Driver Interface
// ---------------------------------------------------------------------------
extern "C" int UDP_Init(void) {
    Con_Printf("UDP_Init: Initializing Network.framework...\n");
    nwQueue = dispatch_queue_create("quake.network", DISPATCH_QUEUE_SERIAL);
    return 0; // Success
}

extern "C" void UDP_Shutdown(void) {
    if (udpListener) {
        nw_listener_cancel(udpListener);
        udpListener = nullptr;
    }
    for (int i = 0; i < MAX_CONNECTIONS; i++) {
        if (activeConnections[i]) {
            nw_connection_cancel(activeConnections[i]);
            activeConnections[i] = nullptr;
        }
    }
}

extern "C" void UDP_Listen(qboolean state) {
    if (state && !udpListener) {
        nw_parameters_configure_protocol_block_t configure_udp = ^(nw_protocol_options_t udp_options) {
            // Optional UDP configuration
        };
        nw_parameters_t parameters = nw_parameters_create_secure_udp(NW_PARAMETERS_DISABLE_PROTOCOL, configure_udp);
        
        // Optimize for Game Mode / Low Latency
        nw_parameters_set_multipath_service(parameters, nw_multipath_service_interactive);
        
        nw_endpoint_t local_endpoint = nw_endpoint_create_host("0.0.0.0", "27500");
        nw_parameters_set_local_endpoint(parameters, local_endpoint);
        
        udpListener = nw_listener_create(parameters);
        
        nw_listener_set_new_connection_handler(udpListener, ^(nw_connection_t connection) {
            int idx = FindFreeConnection();
            if (idx != -1) {
                activeConnections[idx] = connection;
                nw_connection_set_queue(connection, nwQueue);
                nw_connection_start(connection);
                StartReceiving(idx);
            } else {
                nw_connection_cancel(connection);
            }
        });
        
        nw_listener_set_queue(udpListener, nwQueue);
        nw_listener_start(udpListener);
    } else if (!state && udpListener) {
        nw_listener_cancel(udpListener);
        udpListener = nullptr;
    }
}

extern "C" int UDP_OpenSocket(int port) {
    int idx = FindFreeConnection();
    if (idx == -1) return -1;
    // Create an inbound listener dynamically or return a virtual socket ID
    return idx;
}

extern "C" int UDP_CloseSocket(int socket) {
    if (socket >= 0 && socket < MAX_CONNECTIONS && activeConnections[socket]) {
        nw_connection_cancel(activeConnections[socket]);
        activeConnections[socket] = nullptr;
        return 0;
    }
    return -1;
}

extern "C" int UDP_Connect(int socket, struct qsockaddr *addr) {
    // Convert qsockaddr to nw_endpoint_t and establish outbound connection
    if (socket < 0 || socket >= MAX_CONNECTIONS) return -1;
    
    char port_str[16];
    sprintf(port_str, "%d", ntohs(((struct sockaddr_in *)addr)->sin_port));
    
    char ip_str[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &(((struct sockaddr_in *)addr)->sin_addr), ip_str, INET_ADDRSTRLEN);
    
    nw_endpoint_t endpoint = nw_endpoint_create_host(ip_str, port_str);
    nw_parameters_t parameters = nw_parameters_create_secure_udp(NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION);
    nw_parameters_set_multipath_service(parameters, nw_multipath_service_interactive);
    
    nw_connection_t connection = nw_connection_create(endpoint, parameters);
    activeConnections[socket] = connection;
    
    nw_connection_set_queue(connection, nwQueue);
    nw_connection_start(connection);
    StartReceiving(socket);
    
    return 0;
}

// ---------------------------------------------------------------------------
// Receive Queue — bridges async Network.framework to sync Quake reads
// ---------------------------------------------------------------------------
#define MAX_PACKET_SIZE 8192
#define RECV_QUEUE_SIZE 64

struct RecvPacket {
    byte data[MAX_PACKET_SIZE];
    int len;
    struct qsockaddr addr;
};

static struct {
    RecvPacket packets[RECV_QUEUE_SIZE];
    volatile int head;
    volatile int tail;
} recvQueues[MAX_CONNECTIONS] = {};

static void EnqueuePacket(int socket, const byte* data, int len, struct qsockaddr* addr) {
    auto& q = recvQueues[socket];
    int next = (q.tail + 1) % RECV_QUEUE_SIZE;
    if (next == q.head) return; // Queue full, drop packet
    
    int copyLen = (len > MAX_PACKET_SIZE) ? MAX_PACKET_SIZE : len;
    memcpy(q.packets[q.tail].data, data, copyLen);
    q.packets[q.tail].len = copyLen;
    if (addr) q.packets[q.tail].addr = *addr;
    __sync_synchronize();
    q.tail = next;
}

static void StartReceiving(int socket) {
    nw_connection_t conn = activeConnections[socket];
    if (!conn) return;
    
    nw_connection_receive(conn, 1, MAX_PACKET_SIZE, ^(dispatch_data_t content, nw_content_context_t context, bool is_complete, nw_error_t error) {
        if (content) {
            const void* bytes;
            size_t size;
            dispatch_data_t contiguous = dispatch_data_create_map(content, &bytes, &size);
            
            struct qsockaddr from_addr;
            memset(&from_addr, 0, sizeof(from_addr));
            
            EnqueuePacket(socket, (const byte*)bytes, (int)size, &from_addr);
            
            if (contiguous) {} // ARC manages
        }
        
        // Re-arm receive for next packet (continuous receive loop)
        if (!error && !is_complete) {
            StartReceiving(socket);
        }
    });
}

extern "C" int UDP_CheckNewConnections(void) {
    return -1; // Connection acceptance handled by nw_listener blocks
}

extern "C" int UDP_Read(int socket, byte *buf, int len, struct qsockaddr *addr) {
    if (socket < 0 || socket >= MAX_CONNECTIONS) return 0;
    
    auto& q = recvQueues[socket];
    if (q.head == q.tail) return 0; // Queue empty
    
    int copyLen = q.packets[q.head].len;
    if (copyLen > len) copyLen = len;
    memcpy(buf, q.packets[q.head].data, copyLen);
    if (addr) *addr = q.packets[q.head].addr;
    
    __sync_synchronize();
    q.head = (q.head + 1) % RECV_QUEUE_SIZE;
    
    return copyLen;
}

extern "C" int UDP_Write(int socket, byte *buf, int len, struct qsockaddr *addr) {
    if (socket >= 0 && socket < MAX_CONNECTIONS && activeConnections[socket]) {
        // Copy buffer for async send (original may be freed)
        byte* sendBuf = (byte*)malloc(len);
        memcpy(sendBuf, buf, len);
        dispatch_data_t data = dispatch_data_create(sendBuf, len, nwQueue, ^{ free(sendBuf); });
        nw_connection_send(activeConnections[socket], data, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t error) {
            if (error) {
                Con_Printf("UDP_Write: send error\n");
            }
        });
        return len;
    }
    return -1;
}

extern "C" int UDP_Broadcast(int socket, byte *buf, int len) {
    // Create a broadcast endpoint and send
    nw_endpoint_t broadcast = nw_endpoint_create_host("255.255.255.255", "27500");
    nw_parameters_t params = nw_parameters_create_secure_udp(NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION);
    nw_parameters_set_multipath_service(params, nw_multipath_service_interactive);
    nw_connection_t conn = nw_connection_create(broadcast, params);
    nw_connection_set_queue(conn, nwQueue);
    nw_connection_start(conn);
    
    byte* sendBuf = (byte*)malloc(len);
    memcpy(sendBuf, buf, len);
    dispatch_data_t data = dispatch_data_create(sendBuf, len, nwQueue, ^{ free(sendBuf); });
    nw_connection_send(conn, data, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t error) {
        nw_connection_cancel(conn);
    });
    return len;
}

// ---------------------------------------------------------------------------
// Address Resolution
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
    
    char* colon = strrchr(string, ':');
    if (colon) {
        *colon = '\0';
        sin->sin_port = htons(atoi(colon + 1));
        sin->sin_addr.s_addr = inet_addr(string);
        *colon = ':';
    } else {
        sin->sin_addr.s_addr = inet_addr(string);
        sin->sin_port = htons(27500);
    }
    return 0;
}

extern "C" int UDP_GetSocketAddr(int socket, struct qsockaddr *addr) {
    struct sockaddr_in *sin = (struct sockaddr_in *)addr;
    memset(sin, 0, sizeof(*sin));
    sin->sin_family = AF_INET;
    sin->sin_addr.s_addr = INADDR_ANY;
    sin->sin_port = htons(27500);
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
    sin->sin_port = htons(27500);
    
    sin->sin_addr.s_addr = inet_addr(name);
    if (sin->sin_addr.s_addr == INADDR_NONE) {
        // Try DNS lookup
        struct hostent *he = gethostbyname(name);
        if (he) {
            memcpy(&sin->sin_addr, he->h_addr_list[0], he->h_length);
        } else {
            return -1;
        }
    }
    return 0;
}

extern "C" int UDP_AddrCompare(struct qsockaddr *addr1, struct qsockaddr *addr2) {
    struct sockaddr_in *s1 = (struct sockaddr_in *)addr1;
    struct sockaddr_in *s2 = (struct sockaddr_in *)addr2;
    
    if (s1->sin_addr.s_addr != s2->sin_addr.s_addr) return -1;
    if (s1->sin_port != s2->sin_port) return 1; // Same addr, different port
    return 0; // Exact match
}

extern "C" int UDP_GetSocketPort(struct qsockaddr *addr) {
    return ntohs(((struct sockaddr_in *)addr)->sin_port);
}

extern "C" int UDP_SetSocketPort(struct qsockaddr *addr, int port) {
    ((struct sockaddr_in *)addr)->sin_port = htons(port);
    return 0;
}

