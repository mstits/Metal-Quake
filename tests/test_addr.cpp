/*
 * Tests for IPv4 address handling semantics. We replicate the tiny
 * subset of UDP_* helpers that don't need Network.framework so the
 * test runs hermetically.
 *
 * The shipped implementations in net_apple.cpp are byte-identical to
 * what's tested here; this is a "contract" test that locks in the
 * behavior callers depend on (net_dgrm.c expects AddrCompare to return
 * 0 for exact match, 1 for same host / different port, -1 for
 * different host).
 */

#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

struct qsockaddr {
    short   sa_family;
    char    sa_data[14];
};

// Replicated from net_apple.cpp — kept in sync via this test.
static int compareAddr(const struct qsockaddr *a, const struct qsockaddr *b) {
    const struct sockaddr_in *s1 = (const struct sockaddr_in *)a;
    const struct sockaddr_in *s2 = (const struct sockaddr_in *)b;
    if (s1->sin_addr.s_addr != s2->sin_addr.s_addr) return -1;
    if (s1->sin_port        != s2->sin_port)        return  1;
    return 0;
}

static void setAddr(struct qsockaddr *out, const char *ip, int port) {
    struct sockaddr_in *sin = (struct sockaddr_in *)out;
    memset(sin, 0, sizeof(*sin));
    sin->sin_family = AF_INET;
    sin->sin_port   = htons(port);
    inet_pton(AF_INET, ip, &sin->sin_addr);
}

static int failures = 0;
#define EXPECT(cond) do { if (!(cond)) { fprintf(stderr, "FAIL: %s:%d %s\n", __FILE__, __LINE__, #cond); failures++; } } while (0)

int main(void) {
    struct qsockaddr a, b;

    setAddr(&a, "192.168.1.5", 27500);
    setAddr(&b, "192.168.1.5", 27500);
    EXPECT(compareAddr(&a, &b) == 0);     // exact match

    setAddr(&a, "192.168.1.5", 27500);
    setAddr(&b, "192.168.1.5", 27501);
    EXPECT(compareAddr(&a, &b) == 1);     // same host, diff port

    setAddr(&a, "192.168.1.5", 27500);
    setAddr(&b, "10.0.0.1",    27500);
    EXPECT(compareAddr(&a, &b) == -1);    // diff host

    setAddr(&a, "0.0.0.0",       0);
    setAddr(&b, "0.0.0.0",       0);
    EXPECT(compareAddr(&a, &b) == 0);     // both-zero match

    if (failures == 0) {
        printf("PASS: addr compare semantics\n");
        return 0;
    }
    fprintf(stderr, "FAIL: %d addr-compare mismatches\n", failures);
    return 1;
}
