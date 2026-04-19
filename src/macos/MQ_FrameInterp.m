/**
 * @file MQ_FrameInterp.m
 * @brief MetalFX Frame Interpolation shim.
 *
 * The vendored metal-cpp on disk doesn't carry MTLFXFrameInterpolator
 * headers, so vid_metal.cpp (C++) can't directly construct one. This
 * shim imports the real MetalFX ObjC headers and exposes a small C
 * API that the renderer calls through.
 *
 * Usage pattern from vid_metal.cpp:
 *   void* fi = MQ_FI_Create(device, rtW, rtH, pixelFormat);
 *   ...
 *   MQ_FI_Encode(fi, cmdBuf, currentColor, prevColor, motion, depth,
 *                outputTexture, (currentTimestamp - prevTimestamp) * 0.5);
 *   MQ_FI_Release(fi);
 *
 * Frame Interpolation synthesizes a new frame between two rendered
 * frames; the output texture gets presented to the drawable alongside
 * the real frames, doubling perceived refresh. Requires macOS 15+
 * (which is always true on macOS 26 host).
 */

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#if __has_include(<MetalFX/MTLFXFrameInterpolator.h>)
#import <MetalFX/MetalFX.h>
#define MQ_FI_AVAILABLE 1
#else
#define MQ_FI_AVAILABLE 0
#endif

extern void Con_Printf(const char *fmt, ...);

void* MQ_FI_Create(void *devicePtr, int width, int height, unsigned long pixelFormat) {
#if MQ_FI_AVAILABLE
    if (@available(macOS 15.0, *)) {
        id<MTLDevice> device = (__bridge id<MTLDevice>)devicePtr;
        MTLFXFrameInterpolatorDescriptor *desc = [[MTLFXFrameInterpolatorDescriptor alloc] init];
        desc.inputWidth  = (NSUInteger)width;
        desc.inputHeight = (NSUInteger)height;
        desc.outputWidth  = (NSUInteger)width;
        desc.outputHeight = (NSUInteger)height;
        desc.colorTextureFormat  = (MTLPixelFormat)pixelFormat;
        desc.outputTextureFormat = (MTLPixelFormat)pixelFormat;
        desc.depthTextureFormat  = MTLPixelFormatR32Float;
        desc.motionTextureFormat = MTLPixelFormatRG16Float;
        id<MTLFXFrameInterpolator> interp = [desc newFrameInterpolatorWithDevice:device];
        if (!interp) {
            Con_Printf("MetalFX: newFrameInterpolator returned nil\n");
            return NULL;
        }
        Con_Printf("MetalFX: Frame Interpolator created (%dx%d)\n", width, height);
        return (__bridge_retained void *)interp;
    }
#endif
    (void)devicePtr; (void)width; (void)height; (void)pixelFormat;
    return NULL;
}

void MQ_FI_Release(void *interpPtr) {
#if MQ_FI_AVAILABLE
    if (!interpPtr) return;
    if (@available(macOS 15.0, *)) {
        // Transfer ownership back to ARC for release.
        id<MTLFXFrameInterpolator> interp = (__bridge_transfer id<MTLFXFrameInterpolator>)interpPtr;
        interp = nil;
        (void)interp;
    }
#else
    (void)interpPtr;
#endif
}

int MQ_FI_Encode(void *interpPtr, void *cmdBufPtr,
                 void *currentColorPtr, void *prevColorPtr,
                 void *motionPtr, void *depthPtr,
                 void *outputPtr, float timeStepInSeconds) {
#if MQ_FI_AVAILABLE
    if (!interpPtr || !cmdBufPtr) return -1;
    if (@available(macOS 15.0, *)) {
        id<MTLFXFrameInterpolator> interp = (__bridge id<MTLFXFrameInterpolator>)interpPtr;
        id<MTLCommandBuffer>      cmdBuf = (__bridge id<MTLCommandBuffer>)cmdBufPtr;
        interp.colorTexture        = (__bridge id<MTLTexture>)currentColorPtr;
        interp.prevColorTexture    = (__bridge id<MTLTexture>)prevColorPtr;
        interp.motionTexture       = (__bridge id<MTLTexture>)motionPtr;
        interp.depthTexture        = (__bridge id<MTLTexture>)depthPtr;
        interp.outputTexture       = (__bridge id<MTLTexture>)outputPtr;
        interp.motionVectorScaleX  = 1.0f;
        interp.motionVectorScaleY  = 1.0f;
        // timeStep expresses how far between the two input frames the
        // interpolated frame should land. 0.5 = halfway (classic 60→120
        // synthesis); 0.33 / 0.66 pairs would give 60→180, etc.
        interp.deltaTime            = timeStepInSeconds;
        [interp encodeToCommandBuffer:cmdBuf];
        return 0;
    }
#endif
    (void)interpPtr; (void)cmdBufPtr;
    (void)currentColorPtr; (void)prevColorPtr;
    (void)motionPtr; (void)depthPtr;
    (void)outputPtr; (void)timeStepInSeconds;
    return -1;
}

int MQ_FI_IsAvailable(void) {
#if MQ_FI_AVAILABLE
    if (@available(macOS 15.0, *)) return 1;
#endif
    return 0;
}
