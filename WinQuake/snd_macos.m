#include "quakedef.h"
#import <AudioToolbox/AudioToolbox.h>

static AudioQueueRef queue;
static AudioQueueBufferRef buffers[3];
#define BUFFER_SIZE 4096 // Smaller buffers for lower latency
#define NUM_BUFFERS 3

// Track where we are reading from the DMA buffer
static volatile int snd_current_sample_pos = 0;

// Callback to feed audio from Quake's DMA buffer
static void HandleOutputBuffer(void *aqData, AudioQueueRef inAQ,
                               AudioQueueBufferRef inBuffer) {
  if (!shm || !shm->buffer) {
    memset(inBuffer->mAudioData, 0, inBuffer->mAudioDataBytesCapacity);
    inBuffer->mAudioDataByteSize = inBuffer->mAudioDataBytesCapacity;
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    return;
  }

  int bytes_needed = inBuffer->mAudioDataBytesCapacity;
  int frame_size = (shm->samplebits / 8) * shm->channels;
  int total_bytes = shm->samples * (shm->samplebits / 8);

  // Read from where we left off in the ring buffer
  int read_pos = (snd_current_sample_pos * (shm->samplebits / 8)) % total_bytes;

  byte *dest = (byte *)inBuffer->mAudioData;
  int bytes_copied = 0;

  while (bytes_copied < bytes_needed) {
    int chunk = bytes_needed - bytes_copied;
    int available = total_bytes - read_pos;
    if (chunk > available)
      chunk = available;

    memcpy(dest + bytes_copied, shm->buffer + read_pos, chunk);
    bytes_copied += chunk;
    read_pos = (read_pos + chunk) % total_bytes;
  }

  // Update sample position (in samples, not bytes)
  snd_current_sample_pos += bytes_needed / (shm->samplebits / 8);
  snd_current_sample_pos %= shm->samples;

  inBuffer->mAudioDataByteSize = bytes_needed;
  AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

qboolean SNDDMA_Init(void) {
  if (COM_CheckParm("-nosound"))
    return false;

  shm = &sn;

  shm->channels = 2;
  shm->samplebits = 16;
  shm->speed = 22050;
  shm->samples = 32768; // Samples in ring buffer (per channel combined)
  shm->submission_chunk = 1;

  // Allocate the DMA ring buffer
  int bufsize = shm->samples * (shm->samplebits / 8);
  shm->buffer = malloc(bufsize);
  memset(shm->buffer, 0, bufsize);

  snd_current_sample_pos = 0;

  // AudioQueue Setup
  AudioStreamBasicDescription format;
  memset(&format, 0, sizeof(format));
  format.mSampleRate = shm->speed;
  format.mFormatID = kAudioFormatLinearPCM;
  format.mFormatFlags =
      kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
  format.mBytesPerPacket = (shm->samplebits / 8) * shm->channels;
  format.mFramesPerPacket = 1;
  format.mBytesPerFrame = (shm->samplebits / 8) * shm->channels;
  format.mChannelsPerFrame = shm->channels;
  format.mBitsPerChannel = shm->samplebits;

  OSStatus status =
      AudioQueueNewOutput(&format, HandleOutputBuffer, NULL, CFRunLoopGetMain(),
                          kCFRunLoopCommonModes, 0, &queue);
  if (status != noErr) {
    printf("SNDDMA_Init: AudioQueueNewOutput failed (%d)\n", (int)status);
    return false;
  }

  // Prime buffers with silence and enqueue
  for (int i = 0; i < NUM_BUFFERS; ++i) {
    AudioQueueAllocateBuffer(queue, BUFFER_SIZE, &buffers[i]);
    buffers[i]->mAudioDataByteSize = BUFFER_SIZE;
    memset(buffers[i]->mAudioData, 0, BUFFER_SIZE);
    AudioQueueEnqueueBuffer(queue, buffers[i], 0, NULL);
  }

  AudioQueueStart(queue, NULL);
  printf("SNDDMA_Init: Audio Initialized (%d Hz, %d samples buffer)\n",
         shm->speed, shm->samples);

  return true;
}

int SNDDMA_GetDMAPos(void) { return snd_current_sample_pos; }

void SNDDMA_Submit(void) {
  // AudioQueue is callback-driven, no explicit submit needed
}

void SNDDMA_Shutdown(void) {
  if (queue) {
    AudioQueueStop(queue, true);
    AudioQueueDispose(queue, true);
    queue = NULL;
  }
  if (shm && shm->buffer) {
    free(shm->buffer);
    shm->buffer = NULL;
  }
}
