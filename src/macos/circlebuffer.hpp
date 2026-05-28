#ifndef __MQ_CIRCLEBUFFER_HPP__
#define __MQ_CIRCLEBUFFER_HPP__

// ---------------------------------------------------------------------------
// Lock-free single-producer / single-consumer audio ring buffer.
//
// Lives in its own header (rather than inline in snd_coreaudio.cpp) so the
// concurrency logic can be exercised directly by tests/test_ringbuffer.cpp
// without pulling in Core Audio or the rest of the engine. The class has no
// dependency beyond the C++ standard library.
//
// Producer:  Write()  — called from Quake's mixer thread (SNDDMA_Submit).
// Consumer:  Read()    — called from the Core Audio render callback.
// `tail` is written only by the producer; `head` only by the consumer. The
// single release/acquire edge on `tail` (and on `head`) is what makes the
// hand-off safe without a mutex. `framesConsumed` is a monotonic counter the
// engine projects back into Quake's DMA cursor via SNDDMA_GetDMAPos.
// ---------------------------------------------------------------------------

#include <atomic>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <algorithm>

class CircleBuffer {
public:
    CircleBuffer() : buffer(nullptr), sizeFrames(0), head(0), tail(0), framesConsumed(0) {}
    ~CircleBuffer() { if (buffer) free(buffer); }

    void Init(uint32_t totalFrames) {
        sizeFrames = totalFrames;
        // Stereo 16-bit
        buffer = (int16_t*)malloc(sizeFrames * 2 * sizeof(int16_t));
        memset(buffer, 0, sizeFrames * 2 * sizeof(int16_t));
        head.store(0);
        tail.store(0);
        framesConsumed.store(0);
    }

    // Called by Core Audio (pulls data). framesConsumed is a monotonic
    // counter of frames the speaker has played, used by Quake's paintedtime
    // scheduling via SNDDMA_GetDMAPos — not by any in-buffer math here.
    uint32_t Read(float* left, float* right, uint32_t frames) {
        uint32_t framesRead = 0;
        uint32_t currentHead = head.load(std::memory_order_relaxed);
        uint32_t currentTail = tail.load(std::memory_order_acquire);

        uint32_t available;
        if (currentTail >= currentHead)
            available = currentTail - currentHead;
        else
            available = sizeFrames - currentHead + currentTail;

        uint32_t toRead = std::min(frames, available);

        while (framesRead < toRead) {
            left[framesRead]  = (float)buffer[currentHead * 2]     / 32768.0f;
            right[framesRead] = (float)buffer[currentHead * 2 + 1] / 32768.0f;

            currentHead = (currentHead + 1) % sizeFrames;
            framesRead++;
        }
        head.store(currentHead, std::memory_order_release);
        framesConsumed.fetch_add(framesRead, std::memory_order_release);
        return framesRead;
    }

    // Called by Quake (pushes data). tail is only written here, and is the
    // single release edge the reader observes with memory_order_acquire.
    void Write(const int16_t* src, uint32_t frames) {
        uint32_t currentTail = tail.load(std::memory_order_relaxed);
        for (uint32_t i = 0; i < frames; i++) {
            buffer[currentTail * 2]     = src[i * 2];
            buffer[currentTail * 2 + 1] = src[i * 2 + 1];
            currentTail = (currentTail + 1) % sizeFrames;
        }
        tail.store(currentTail, std::memory_order_release);
    }

    uint32_t GetHead() const { return head.load(std::memory_order_relaxed); }
    uint32_t GetTail() const { return tail.load(std::memory_order_relaxed); }
    uint64_t GetFramesConsumed() const { return framesConsumed.load(std::memory_order_acquire); }
    uint32_t GetSizeFrames() const { return sizeFrames; }

private:
    int16_t* buffer;
    uint32_t sizeFrames;
    std::atomic<uint32_t> head;
    std::atomic<uint32_t> tail;
    std::atomic<uint64_t> framesConsumed; // monotonic frames played by Core Audio
};

#endif // __MQ_CIRCLEBUFFER_HPP__
