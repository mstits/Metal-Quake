// Tests for the lock-free SPSC audio ring buffer (src/macos/circlebuffer.hpp).
//
// Catches the class of bug TECHNICAL.md §8 describes hitting once: a mismatch
// between the proxy ring's internal cursors and the frames actually handed to
// Core Audio. Three properties are checked:
//
//   1. Single-threaded wrap-around: data written across the ring's wrap point
//      reads back intact and in order; framesConsumed tracks reads.
//   2. Underrun: reading more than is available returns only what's available
//      and never reads past the producer's tail.
//   3. Concurrent SPSC hand-off: with a producer that respects capacity, the
//      consumer observes every frame exactly once, in FIFO order, with no
//      torn frames — i.e. the acquire/release edges on head/tail are correct.

#include "circlebuffer.hpp"

#include <cstdio>
#include <cstdint>
#include <thread>
#include <vector>

static int g_failures = 0;

#define CHECK(cond, msg)                                                  \
    do {                                                                  \
        if (!(cond)) {                                                    \
            printf("  FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__);   \
            g_failures++;                                                 \
        }                                                                 \
    } while (0)

// Occupancy implied by the public head/tail cursors (frames not yet read).
static uint32_t Occupancy(const CircleBuffer& b) {
    uint32_t size = b.GetSizeFrames();
    uint32_t head = b.GetHead();
    uint32_t tail = b.GetTail();
    return (tail + size - head) % size;
}

// ---------------------------------------------------------------------------
// Test 1: wrap-around correctness (single-threaded)
// ---------------------------------------------------------------------------
static void test_wraparound() {
    printf("test_wraparound...\n");
    CircleBuffer buf;
    const uint32_t size = 8;
    buf.Init(size);

    // Prime the cursors near the end so the next write wraps.
    int16_t prime[5 * 2];
    for (int i = 0; i < 5; i++) { prime[i * 2] = (int16_t)i; prime[i * 2 + 1] = (int16_t)i; }
    buf.Write(prime, 5);
    float l[8], r[8];
    uint32_t got = buf.Read(l, r, 5);
    CHECK(got == 5, "primed read count");
    CHECK(buf.GetFramesConsumed() == 5, "framesConsumed after prime");

    // Now write 6 frames starting near the end of the ring -> spans the wrap.
    int16_t data[6 * 2];
    for (int i = 0; i < 6; i++) {
        data[i * 2]     = (int16_t)(1000 + i);
        data[i * 2 + 1] = (int16_t)(-(1000 + i));
    }
    buf.Write(data, 6);
    got = buf.Read(l, r, 6);
    CHECK(got == 6, "wrapped read count");
    bool ordered = true;
    for (int i = 0; i < 6; i++) {
        int16_t expL = (int16_t)(1000 + i);
        int16_t expR = (int16_t)(-(1000 + i));
        if ((int16_t)(l[i] * 32768.0f) != expL || (int16_t)(r[i] * 32768.0f) != expR)
            ordered = false;
    }
    CHECK(ordered, "wrapped data intact and in order");
    CHECK(buf.GetFramesConsumed() == 11, "framesConsumed accumulates across wrap");
}

// ---------------------------------------------------------------------------
// Test 2: underrun returns only what is available
// ---------------------------------------------------------------------------
static void test_underrun() {
    printf("test_underrun...\n");
    CircleBuffer buf;
    buf.Init(64);

    int16_t data[3 * 2] = {1, 1, 2, 2, 3, 3};
    buf.Write(data, 3);

    float l[16], r[16];
    uint32_t got = buf.Read(l, r, 16);   // ask for more than the 3 available
    CHECK(got == 3, "underrun returns available count only");
    CHECK(Occupancy(buf) == 0, "ring drained after underrun read");

    got = buf.Read(l, r, 16);            // empty ring
    CHECK(got == 0, "read on empty ring returns 0");
}

// ---------------------------------------------------------------------------
// Test 3: concurrent single-producer / single-consumer hand-off
// ---------------------------------------------------------------------------
static void test_concurrent_spsc() {
    printf("test_concurrent_spsc...\n");
    CircleBuffer buf;
    const uint32_t size = 1024;
    buf.Init(size);

    const uint64_t TOTAL = 2'000'000;       // frames to push through the ring
    std::atomic<bool> producerDone{false};

    // Each frame encodes its sequence number in BOTH channels (value = seq &
    // 0xFFFF). A torn read (left from one write, right from another) shows up
    // as left != right; a lost/duplicated/reordered frame breaks the
    // contiguous +1 sequence the consumer expects.
    std::thread producer([&]() {
        uint64_t seq = 0;
        std::vector<int16_t> chunk(256 * 2);
        while (seq < TOTAL) {
            // A well-behaved producer never overruns: leave one slot free so
            // the empty/full ambiguity (tail==head) always reads as empty.
            uint32_t freeFrames = size - Occupancy(buf) - 1;
            if (freeFrames == 0) { std::this_thread::yield(); continue; }
            uint32_t n = (uint32_t)std::min<uint64_t>(TOTAL - seq, freeFrames);
            if (n > 256) n = 256;
            for (uint32_t i = 0; i < n; i++) {
                int16_t v = (int16_t)((seq + i) & 0xFFFF);
                chunk[i * 2]     = v;
                chunk[i * 2 + 1] = v;
            }
            buf.Write(chunk.data(), n);
            seq += n;
        }
        producerDone.store(true, std::memory_order_release);
    });

    uint64_t consumed = 0;
    bool seqInit = false;
    uint16_t expected = 0;
    bool torn = false, outOfOrder = false;
    float l[512], r[512];

    while (true) {
        uint32_t n = buf.Read(l, r, 512);
        for (uint32_t i = 0; i < n; i++) {
            int16_t lv = (int16_t)(l[i] * 32768.0f);
            int16_t rv = (int16_t)(r[i] * 32768.0f);
            if (lv != rv) torn = true;
            uint16_t val = (uint16_t)lv;
            if (!seqInit) { expected = val; seqInit = true; }
            if (val != expected) outOfOrder = true;
            expected = (uint16_t)(expected + 1);
        }
        consumed += n;
        if (n == 0) {
            if (producerDone.load(std::memory_order_acquire) && Occupancy(buf) == 0)
                break;
            std::this_thread::yield();
        }
    }
    producer.join();

    CHECK(!torn, "no torn frames (left==right always)");
    CHECK(!outOfOrder, "frames delivered in FIFO order, none lost or duplicated");
    CHECK(consumed == TOTAL, "every produced frame consumed exactly once");
    CHECK(buf.GetFramesConsumed() == TOTAL, "framesConsumed matches total throughput");
}

int main() {
    printf("=== CircleBuffer tests ===\n");
    test_wraparound();
    test_underrun();
    test_concurrent_spsc();

    if (g_failures == 0) {
        printf("OK: all CircleBuffer tests passed\n");
        return 0;
    }
    printf("FAILED: %d check(s)\n", g_failures);
    return 1;
}
