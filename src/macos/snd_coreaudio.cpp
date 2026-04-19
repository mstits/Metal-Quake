extern "C" {
    #define __QBOOLEAN_DEFINED__
    typedef int qboolean;
    #define true 1
    #define false 0
    #include "quakedef.h"
    #include "sound.h"
    #undef true
    #undef false
}

#include <AudioUnit/AudioUnit.h>
#include <AudioToolbox/AudioToolbox.h>
#include <Accelerate/Accelerate.h>
#include <atomic>
#include <algorithm>
#include "snd_coreaudio.hpp"

static AudioUnit outputUnit;

// ---------------------------------------------------------------------------
// Thread-safe Circular Buffer Bridge
// ---------------------------------------------------------------------------
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

static CircleBuffer g_audioBuffer;

// ---------------------------------------------------------------------------
// Core Audio Pull Callback
// ---------------------------------------------------------------------------
static OSStatus CoreAudio_Callback(void *inRefCon,
                                   AudioUnitRenderActionFlags *ioActionFlags,
                                   const AudioTimeStamp *inTimeStamp,
                                   uint32_t inBusNumber,
                                   uint32_t inNumberFrames,
                                   AudioBufferList *ioData) {
    if (!snd_initialized) return noErr;

    float *left  = (float *)ioData->mBuffers[0].mData;
    float *right = (float *)ioData->mBuffers[1].mData;

    uint32_t read = g_audioBuffer.Read(left, right, inNumberFrames);
    
    if (read < inNumberFrames) {
        for (uint32_t i = read; i < inNumberFrames; i++) {
            left[i] = 0.0f;
            right[i] = 0.0f;
        }
    }

    return noErr;
}

// ---------------------------------------------------------------------------
// Quake Driver Implementation
// ---------------------------------------------------------------------------
extern "C" qboolean SNDDMA_Init(void) {
    Con_Printf("SNDDMA_Init: Initializing Core Audio (Fixed Frame Logic)...\n");

    shm = &sn;

    // Prefer the default output device's native sample rate so the
    // OS doesn't have to resample on every callback. Falls back to
    // 44100 if the query fails (unlikely on modern macOS but cheap).
    Float64 nativeRate = 44100.0;
    {
        AudioObjectPropertyAddress defOutAddr = {
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioObjectPropertyScopeGlobal,
            kAudioObjectPropertyElementMain
        };
        AudioDeviceID devId = 0;
        UInt32 size = sizeof(devId);
        if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &defOutAddr, 0, nullptr, &size, &devId) == noErr && devId != 0) {
            AudioObjectPropertyAddress rateAddr = {
                kAudioDevicePropertyNominalSampleRate,
                kAudioObjectPropertyScopeOutput,
                kAudioObjectPropertyElementMain
            };
            Float64 rate = 0.0;
            size = sizeof(rate);
            if (AudioObjectGetPropertyData(devId, &rateAddr, 0, nullptr, &size, &rate) == noErr && rate > 0.0) {
                nativeRate = rate;
            }
        }
    }
    sn.speed      = (int)nativeRate;
    sn.channels   = 2;
    sn.samplebits = 16;
    
    // DMA buffer size (mono samples)
    sn.samples    = 16384; 
    sn.submission_chunk = 1;
    sn.buffer     = (unsigned char *)malloc(sn.samples * (sn.samplebits / 8));
    memset(sn.buffer, 0, sn.samples * (sn.samplebits / 8));
    
    // Internal buffer size (frames)
    g_audioBuffer.Init(16384);

    AudioComponentDescription desc;
    desc.componentType         = kAudioUnitType_Output;
    desc.componentSubType      = kAudioUnitSubType_DefaultOutput;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags        = 0;
    desc.componentFlagsMask    = 0;

    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    if (AudioComponentInstanceNew(comp, &outputUnit) != noErr) {
        Con_Printf("SNDDMA_Init: Failed to create AudioUnit.\n");
        return 0;
    }

    AudioStreamBasicDescription format;
    memset(&format, 0, sizeof(format));
    format.mSampleRate       = (Float64)sn.speed;
    format.mFormatID         = kAudioFormatLinearPCM;
    format.mFormatFlags      = kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsPacked;
    format.mFramesPerPacket  = 1;
    format.mChannelsPerFrame = 2;
    format.mBitsPerChannel   = 32;
    format.mBytesPerPacket   = 4;
    format.mBytesPerFrame    = 4;

    AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input, 0, &format, sizeof(format));

    AURenderCallbackStruct callback;
    callback.inputProc       = CoreAudio_Callback;
    callback.inputProcRefCon = NULL;
    AudioUnitSetProperty(outputUnit, kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input, 0, &callback, sizeof(callback));

    if (AudioUnitInitialize(outputUnit) != noErr) {
        Con_Printf("SNDDMA_Init: Failed to initialize AudioUnit.\n");
        return 0;
    }

    if (AudioOutputUnitStart(outputUnit) != noErr) {
        Con_Printf("SNDDMA_Init: Failed to start AudioUnit.\n");
        return 0;
    }

    return 1;
}

extern "C" int SNDDMA_GetDMAPos(void) {
    // Quake's mixer expects GetDMAPos() to return the play cursor inside
    // *its own* DMA buffer (sn.buffer, sn.samples mono samples). The proxy
    // ring buffer we own is a separate allocation of a different size, so
    // head/tail inside that ring are not a valid position in sn.buffer.
    //
    // Instead, track monotonic frames consumed by Core Audio and project
    // back into sn.samples as mono samples: played_frames * channels mod
    // sn.samples. That matches what the original DMA driver reported.
    uint64_t consumed = g_audioBuffer.GetFramesConsumed();
    return (int)((consumed * 2) % (uint64_t)sn.samples);
}

extern "C" void SNDDMA_Shutdown(void) {
    if (outputUnit) {
        AudioOutputUnitStop(outputUnit);
        AudioUnitUninitialize(outputUnit);
        AudioComponentInstanceDispose(outputUnit);
        outputUnit = NULL;
    }
    if (sn.buffer) {
        free(sn.buffer);
        sn.buffer = NULL;
    }
}

extern "C" void SNDDMA_Submit(void) {
    static int last_paintedtime = 0;
    extern int paintedtime; // sample pairs
    
    int new_frames = paintedtime - last_paintedtime;
    if (new_frames <= 0) return;
    
    // sn.samples is mono samples, so sn.samples/2 is frames
    int dma_frames = sn.samples / 2;
    if (new_frames > dma_frames) new_frames = dma_frames;

    int16_t *dma_buffer = (int16_t *)sn.buffer;
    
    int start_frame = last_paintedtime % dma_frames;
    int end_frame = paintedtime % dma_frames;
    
    if (end_frame >= start_frame) {
        g_audioBuffer.Write(dma_buffer + start_frame * 2, end_frame - start_frame);
    } else {
        g_audioBuffer.Write(dma_buffer + start_frame * 2, dma_frames - start_frame);
        g_audioBuffer.Write(dma_buffer, end_frame);
    }
    
    last_paintedtime = paintedtime;
}
