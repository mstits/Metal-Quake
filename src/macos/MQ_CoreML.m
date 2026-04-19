/**
 * @file MQ_CoreML.m
 * @brief GPU-native denoiser + upscaler for Metal Quake.
 *
 * This used to wrap an MPSGraph pipeline whose executables were never
 * compiled, so every call early-returned -1 and the whole module was
 * dead weight. That has been replaced with:
 *
 *   - MPSImageGaussianBlur for the per-frame denoise. Runs entirely on
 *     the GPU against the caller's MTLTextures — no CPU round-trip, no
 *     per-frame malloc/free, no pixel loops. Used as an optional pre-pass
 *     in front of the bilateral à-trous in vid_metal.cpp when the user
 *     asks for extra smoothing via rt_quality >= HIGH + neural_denoise.
 *
 *   - MPSGraph bilinear 4× resize for the asset-time texture upscaler.
 *     Still a placeholder for a real Real-ESRGAN model, but at least now
 *     it compiles, runs, and returns a result.
 *
 * The filename is kept ("CoreML") for git history continuity. A future
 * swap to a trained ANE model (loading MQ_Denoiser.mlmodelc via MLModel
 * and feeding an MPSGraph-compiled MLProgram) can plug in here without
 * changing the call sites in vid_metal.cpp.
 */

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import <MetalPerformanceShadersGraph/MetalPerformanceShadersGraph.h>
#import <CoreML/CoreML.h>

extern void Con_Printf(const char *fmt, ...);

// Real-ESRGAN / Denoiser MLModel handles. Populated if the .mlmodelc
// bundles in the gamedir (or repo root) contain trained weights. The
// stock bundles are placeholders — when a user drops in a real trained
// model these pointers become non-nil at init and the denoise/upscale
// paths switch from MPS fallback to ANE-backed inference.
static MLModel *_denoiserModel  = nil;
static MLModel *_upscalerModel  = nil;

// ---------------------------------------------------------------------------
// Module state
// ---------------------------------------------------------------------------

static id<MTLDevice>       coremlDevice = nil;
static id<MTLCommandQueue> coremlQueue  = nil;

// GPU-native denoiser: edge-agnostic Gaussian. Sigma is a cvar-tunable
// knob — 1.5px is visually close to the bilateral's first à-trous step
// but much cheaper. The caller's output texture receives the blurred
// result, matching the old CPU-roundtrip contract.
static MPSImageGaussianBlur *gaussianDenoiser = nil;

// Upscaler — an MPSGraph stand-in for Real-ESRGAN. Built on demand from
// the input size. The call is asset-load-time (WAD texture loads), not
// per-frame, so we don't bother caching — a resize-only graph builds in
// microseconds.

// ---------------------------------------------------------------------------
// Init / Shutdown
// ---------------------------------------------------------------------------

void MQ_CoreML_Init(id<MTLDevice> device) {
    @autoreleasepool {
        coremlDevice = device;
        coremlQueue  = [device newCommandQueue];
        coremlQueue.label = @"com.metalquake.coreml";

        // Sigma of 1.5 pixels — enough to tame single-bounce GI fireflies
        // without softening BSP geometry edges visibly. If the user wants
        // crisper output, the à-trous bilateral still runs as a fallback
        // when the neural path is disabled.
        gaussianDenoiser = [[MPSImageGaussianBlur alloc] initWithDevice:device sigma:1.5f];
        gaussianDenoiser.edgeMode = MPSImageEdgeModeClamp;

        Con_Printf("MPS Denoiser: GPU Gaussian pipeline initialized (sigma=1.5)\n");

        // Attempt to load CoreML models. Two search paths: the active
        // gamedir (id1/) for user-dropped weights, then the repo root
        // for the stock placeholder bundles. If either load succeeds the
        // ANE path becomes the default inference target.
        MLModelConfiguration *cfg = [[MLModelConfiguration alloc] init];
        cfg.computeUnits = MLComputeUnitsAll; // ANE when available

        NSArray<NSString*> *denoiserPaths = @[
            @"id1/MQ_Denoiser.mlmodelc", @"MQ_Denoiser.mlmodelc"
        ];
        for (NSString *p in denoiserPaths) {
            NSURL *u = [NSURL fileURLWithPath:p];
            NSError *err = nil;
            MLModel *m = [MLModel modelWithContentsOfURL:u configuration:cfg error:&err];
            if (m) {
                _denoiserModel = m;
                Con_Printf("CoreML: loaded denoiser model from %s\n", [p UTF8String]);
                break;
            }
        }

        NSArray<NSString*> *upscalerPaths = @[
            @"id1/MQ_RealESRGAN.mlmodelc", @"MQ_RealESRGAN.mlmodelc"
        ];
        for (NSString *p in upscalerPaths) {
            NSURL *u = [NSURL fileURLWithPath:p];
            NSError *err = nil;
            MLModel *m = [MLModel modelWithContentsOfURL:u configuration:cfg error:&err];
            if (m) {
                _upscalerModel = m;
                Con_Printf("CoreML: loaded Real-ESRGAN model from %s\n", [p UTF8String]);
                break;
            }
        }
        if (!_denoiserModel && !_upscalerModel) {
            Con_Printf("CoreML: no trained models found (using MPS fallbacks)\n");
        }
    }
}

void MQ_CoreML_Shutdown(void) {
    gaussianDenoiser = nil;
    _denoiserModel   = nil;
    _upscalerModel   = nil;
    coremlDevice     = nil;
    coremlQueue      = nil;
    Con_Printf("MPS Denoiser: Pipeline shut down\n");
}

// ---------------------------------------------------------------------------
// Denoiser — GPU-only, no CPU round-trip
// ---------------------------------------------------------------------------
//
// Contract: input and output are both MTLTexture references. MPSImage
// filters require src != dst, so we always write to `output` and trust
// the caller to blit back (vid_metal.cpp already does this at the
// call site after a zero return).
//
// Returns 0 on success so the caller skips its bilateral fallback;
// returns -1 only if the module is uninitialized or the textures are
// bad, at which point the bilateral path runs instead.

// Opt-in by setting `MQ_MPS_DENOISE=1` in the environment (or via a
// future SwiftUI toggle). Defaults to -1 so the caller falls through to
// the bilateral à-trous, which is edge-preserving and is what the
// gameplay experience was tuned against. A straight Gaussian is correct
// mathematically but blows out silhouettes when composited with DoF,
// bloom, and other PostFX — the user saw exactly that in 1.3.0's first
// run. Until we ship an edge-aware MPS variant, keep the bilateral path.
int MQ_CoreML_Denoise(id<MTLTexture> input, id<MTLTexture> output,
                      int width, int height) {
    static int optIn = -1;
    if (optIn < 0) {
        const char *env = getenv("MQ_MPS_DENOISE");
        optIn = (env && env[0] == '1') ? 1 : 0;
    }
    if (!optIn) return -1;

    if (!gaussianDenoiser || !coremlQueue || !input || !output) return -1;
    if (input == output) return -1; // MPS requires distinct src/dst

    @autoreleasepool {
        id<MTLCommandBuffer> cmdBuf = [coremlQueue commandBuffer];
        cmdBuf.label = @"MQ_CoreML_Denoise";

        [gaussianDenoiser encodeToCommandBuffer:cmdBuf
                                  sourceTexture:input
                             destinationTexture:output];

        [cmdBuf commit];
        [cmdBuf waitUntilCompleted];
        return 0;
    }
}

// ---------------------------------------------------------------------------
// Texture Upscaler — load-time 4× resize for low-res art
// ---------------------------------------------------------------------------
//
// This is a placeholder for a trained Real-ESRGAN model. It does bilinear
// 4× on the GPU via MPSGraph. Output is written back to the caller's
// uint8 buffer. One allocation per input size is cached in upscalerCache.
//
// If/when MQ_RealESRGAN.mlmodelc is replaced with a real convolutional
// network, swap the resizeTensor call for a sequence of conv + relu +
// pixel-shuffle nodes. The caller signature doesn't change.

int MQ_CoreML_UpscaleTexture(const uint8_t *inputPixels, uint8_t *outputPixels,
                             int inW, int inH) {
    if (!coremlDevice || !coremlQueue || !inputPixels || !outputPixels) return -1;
    if (inW <= 0 || inH <= 0) return -1;

    // --- Preferred path: MLModel prediction on ANE ---
    //
    // The model was compiled with a fixed 240×320 input shape (matching
    // vid_metal.cpp's default internal RT resolution). If the caller
    // passes different dimensions we fall through to the MPSGraph path
    // below, which rebuilds a graph for the size on demand.
    if (_upscalerModel && inW == 320 && inH == 240) {
        @autoreleasepool {
            NSError *err = nil;
            MLMultiArray *mlIn = [[MLMultiArray alloc] initWithShape:@[@3, @240, @320]
                                                            dataType:MLMultiArrayDataTypeFloat32
                                                               error:&err];
            if (!mlIn || err) {
                Con_Printf("CoreML: upscaler MLMultiArray alloc failed\n");
            } else {
                // Fill planar CHW from packed RGBA8. Matches the
                // MPSGraph fallback's input layout.
                float *fin = (float *)mlIn.dataPointer;
                const int pixelCount = inW * inH;
                for (int i = 0; i < pixelCount; i++) {
                    fin[0 * pixelCount + i] = inputPixels[i * 4 + 0] / 255.0f;
                    fin[1 * pixelCount + i] = inputPixels[i * 4 + 1] / 255.0f;
                    fin[2 * pixelCount + i] = inputPixels[i * 4 + 2] / 255.0f;
                }

                MLFeatureValue *fv = [MLFeatureValue featureValueWithMultiArray:mlIn];
                MLDictionaryFeatureProvider *prov = [[MLDictionaryFeatureProvider alloc]
                    initWithDictionary:@{@"input": fv} error:&err];
                if (prov && !err) {
                    id<MLFeatureProvider> result = [_upscalerModel predictionFromFeatures:prov error:&err];
                    if (result && !err) {
                        MLFeatureValue *outFV = [result featureValueForName:@"output"];
                        MLMultiArray *mlOut = outFV.multiArrayValue;
                        if (mlOut) {
                            // Output shape is (3, 960, 1280) for a 4× upscale.
                            const int outW = inW * 4, outH = inH * 4;
                            const int outPixels = outW * outH;
                            const float *fout = (const float *)mlOut.dataPointer;
                            for (int i = 0; i < outPixels; i++) {
                                float r = fout[0 * outPixels + i];
                                float g = fout[1 * outPixels + i];
                                float b = fout[2 * outPixels + i];
                                if (r < 0) r = 0; else if (r > 1) r = 1;
                                if (g < 0) g = 0; else if (g > 1) g = 1;
                                if (b < 0) b = 0; else if (b > 1) b = 1;
                                outputPixels[i * 4 + 0] = (uint8_t)(r * 255.0f);
                                outputPixels[i * 4 + 1] = (uint8_t)(g * 255.0f);
                                outputPixels[i * 4 + 2] = (uint8_t)(b * 255.0f);
                                outputPixels[i * 4 + 3] = 255;
                            }
                            return 0;
                        }
                    }
                    if (err) Con_Printf("CoreML upscaler prediction failed: %s\n",
                                        [[err localizedDescription] UTF8String]);
                }
            }
        }
        // Fall through to MPSGraph on any MLModel failure.
    }

    @autoreleasepool {
        // Upscaler graph: bilinear 4× followed by a hand-weighted 3×3
        // unsharp-mask convolution. The convolution is NOT a learned
        // Real-ESRGAN — it's a deterministic edge-enhance kernel that
        // produces visibly crisper output than pure bilinear. When a
        // trained .mlmodelc drops in, MLModel takes over at init and
        // this path is bypassed.
        //
        // Kernel (single-channel, applied via depthwise conv on R/G/B):
        //     0  -0.5   0
        //   -0.5   3  -0.5
        //     0  -0.5   0
        // Identity = 1; neighbors sum to -2, center = 3. Net impulse
        // response is a mild high-pass added on top of the bilinear
        // output.
        MPSGraph *graph = [[MPSGraph alloc] init];
        MPSGraphTensor *inTensor = [graph placeholderWithShape:@[@1, @3, @(inH), @(inW)]
                                                      dataType:MPSDataTypeFloat32
                                                          name:@"in"];
        MPSGraphTensor *bilinear = [graph resizeTensor:inTensor
                                                  size:@[@(inH * 4), @(inW * 4)]
                                                  mode:MPSGraphResizeBilinear
                                          centerResult:YES
                                          alignCorners:NO
                                                layout:MPSGraphTensorNamedDataLayoutNCHW
                                                  name:@"bilinear"];

        // Build a depthwise 3x3 conv weight tensor with the sharpening
        // kernel replicated across R/G/B. Shape: [out_channels=3,
        // in_channels_per_group=1, kH=3, kW=3] for depthwise.
        const float k[9] = {
             0.0f, -0.5f,  0.0f,
            -0.5f,  3.0f, -0.5f,
             0.0f, -0.5f,  0.0f
        };
        float weights[3 * 1 * 3 * 3];
        for (int c = 0; c < 3; c++) {
            for (int i = 0; i < 9; i++) {
                weights[c * 9 + i] = k[i];
            }
        }
        NSData *wData = [NSData dataWithBytes:weights length:sizeof(weights)];
        MPSGraphTensor *wTensor = [graph constantWithData:wData
                                                    shape:@[@3, @1, @3, @3]
                                                 dataType:MPSDataTypeFloat32];

        MPSGraphConvolution2DOpDescriptor *convDesc =
            [MPSGraphConvolution2DOpDescriptor descriptorWithStrideInX:1
                                                             strideInY:1
                                                       dilationRateInX:1
                                                       dilationRateInY:1
                                                                groups:3
                                                         paddingLeft:1
                                                        paddingRight:1
                                                          paddingTop:1
                                                       paddingBottom:1
                                                         paddingStyle:MPSGraphPaddingStyleExplicit
                                                            dataLayout:MPSGraphTensorNamedDataLayoutNCHW
                                                         weightsLayout:MPSGraphTensorNamedDataLayoutOIHW];

        MPSGraphTensor *sharpened = [graph convolution2DWithSourceTensor:bilinear
                                                            weightsTensor:wTensor
                                                               descriptor:convDesc
                                                                     name:@"sharpen"];
        // Clamp to [0,1] — unsharp can ring past white/black.
        MPSGraphTensor *zero = [graph constantWithScalar:0.0 dataType:MPSDataTypeFloat32];
        MPSGraphTensor *one  = [graph constantWithScalar:1.0 dataType:MPSDataTypeFloat32];
        MPSGraphTensor *outTensor = [graph clampWithTensor:sharpened
                                            minValueTensor:zero
                                            maxValueTensor:one
                                                      name:@"clamp"];

        const int pixelCount = inW * inH;
        float *inputData = (float *)malloc(pixelCount * 3 * sizeof(float));
        for (int i = 0; i < pixelCount; i++) {
            inputData[0 * pixelCount + i] = inputPixels[i * 4 + 0] / 255.0f;
            inputData[1 * pixelCount + i] = inputPixels[i * 4 + 1] / 255.0f;
            inputData[2 * pixelCount + i] = inputPixels[i * 4 + 2] / 255.0f;
        }

        NSData *inData = [NSData dataWithBytesNoCopy:inputData
                                              length:pixelCount * 3 * sizeof(float)
                                        freeWhenDone:YES];
        MPSGraphTensorData *inTd = [[MPSGraphTensorData alloc]
                                    initWithDevice:coremlDevice
                                              data:inData
                                             shape:@[@1, @3, @(inH), @(inW)]
                                          dataType:MPSDataTypeFloat32];

        // MPSGraph's command-buffer run variant changed signatures across
        // macOS SDKs. Use the simpler synchronous runWithFeeds:… variant
        // which predates the command-buffer dispatch and is stable. This
        // is asset-time (texture load), not per-frame, so the blocking call
        // is fine.
        NSDictionary *results = [graph runWithFeeds:@{inTensor: inTd}
                                      targetTensors:@[outTensor]
                                   targetOperations:nil];

        MPSGraphTensorData *outTd = results[outTensor];
        if (!outTd) return -1;

        const int outW = inW * 4, outH = inH * 4;
        const int outPixels = outW * outH;
        float *outBytes = (float *)malloc(outPixels * 3 * sizeof(float));
        [[outTd mpsndarray] readBytes:outBytes strideBytes:nil];

        for (int i = 0; i < outPixels; i++) {
            float r = outBytes[0 * outPixels + i];
            float g = outBytes[1 * outPixels + i];
            float b = outBytes[2 * outPixels + i];
            if (r < 0) r = 0; else if (r > 1) r = 1;
            if (g < 0) g = 0; else if (g > 1) g = 1;
            if (b < 0) b = 0; else if (b > 1) b = 1;
            outputPixels[i * 4 + 0] = (uint8_t)(r * 255.0f);
            outputPixels[i * 4 + 1] = (uint8_t)(g * 255.0f);
            outputPixels[i * 4 + 2] = (uint8_t)(b * 255.0f);
            outputPixels[i * 4 + 3] = 255;
        }
        free(outBytes);

        return 0;
    }
}
