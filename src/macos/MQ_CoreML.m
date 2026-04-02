/**
 * @file MQ_CoreML.m 
 * @brief CoreML / ANE Integration for Metal Quake
 *
 * Provides:
 * 1. Real-ESRGAN texture upscaling via CoreML on the ANE
 * 2. Neural denoiser for RT output (post-process)
 * 3. ANE inference pipeline for future model hot-loading
 *
 * All inference runs on the Apple Neural Engine when available,
 * falling back to GPU compute if ANE is unavailable.
 */

#import <Foundation/Foundation.h>
#import <CoreML/CoreML.h>
#import <Metal/Metal.h>

// Quake includes (minimal)
extern void Con_Printf(const char *fmt, ...);

// ---------------------------------------------------------------------------
// Model Cache
// ---------------------------------------------------------------------------

static MLModel *denoiserModel = nil;
static MLModel *upscalerModel = nil;
static id<MTLDevice> coremlDevice = nil;
static dispatch_queue_t coremlQueue = nil;

// ---------------------------------------------------------------------------
// Initialization
// ---------------------------------------------------------------------------

void MQ_CoreML_Init(id<MTLDevice> device) {
    @autoreleasepool {
        coremlDevice = device;
        coremlQueue = dispatch_queue_create("quake.coreml", DISPATCH_QUEUE_SERIAL);
        
        // Try to load denoiser model from bundle
        NSString *denoiserPath = [[NSBundle mainBundle]
            pathForResource:@"MQ_Denoiser" ofType:@"mlmodelc"];
        
        if (denoiserPath) {
            NSError *error = nil;
            NSURL *url = [NSURL fileURLWithPath:denoiserPath];
            
            MLModelConfiguration *config = [[MLModelConfiguration alloc] init];
            config.computeUnits = MLComputeUnitsAll; // Prefer ANE
            
            denoiserModel = [MLModel modelWithContentsOfURL:url
                                              configuration:config
                                                      error:&error];
            if (denoiserModel) {
                Con_Printf("CoreML: Denoiser model loaded (ANE)\n");
            } else {
                Con_Printf("CoreML: Denoiser load failed — %s\n",
                           [[error localizedDescription] UTF8String]);
            }
        } else {
            Con_Printf("CoreML: No denoiser model found (MQ_Denoiser.mlmodelc)\n");
        }
        
        // Try to load upscaler model
        NSString *upscalerPath = [[NSBundle mainBundle]
            pathForResource:@"MQ_RealESRGAN" ofType:@"mlmodelc"];
        
        if (upscalerPath) {
            NSError *error = nil;
            NSURL *url = [NSURL fileURLWithPath:upscalerPath];
            
            MLModelConfiguration *config = [[MLModelConfiguration alloc] init];
            config.computeUnits = MLComputeUnitsAll;
            
            upscalerModel = [MLModel modelWithContentsOfURL:url
                                              configuration:config
                                                      error:&error];
            if (upscalerModel) {
                Con_Printf("CoreML: Real-ESRGAN upscaler loaded (ANE)\n");
            } else {
                Con_Printf("CoreML: Upscaler load failed — %s\n",
                           [[error localizedDescription] UTF8String]);
            }
        } else {
            Con_Printf("CoreML: No upscaler model found (MQ_RealESRGAN.mlmodelc)\n");
        }
        
        Con_Printf("CoreML: ANE inference pipeline initialized\n");
    }
}

// ---------------------------------------------------------------------------
// Neural Denoiser
// ---------------------------------------------------------------------------

/**
 * @brief Denoise RT output texture using the ANE.
 * @param input  Noisy RT output (RGBA8Unorm, internal resolution)
 * @param output Denoised result (same format)
 * @param width  Texture width
 * @param height Texture height
 * @return 0 on success, -1 if no model available
 *
 * The denoiser expects a 1-bounce RT image with noise from low sample counts.
 * It outputs a temporally stable denoised image suitable for MetalFX upscaling.
 */
int MQ_CoreML_Denoise(id<MTLTexture> input, id<MTLTexture> output,
                       int width, int height) {
    if (!denoiserModel) return -1;
    
    @autoreleasepool {
        // Create MLMultiArray from Metal texture
        // In production: use MLFeatureValue with CVPixelBuffer backed by MTLTexture
        // For now, this shows the pipeline structure
        
        NSError *error = nil;
        MLMultiArray *inputArray = [[MLMultiArray alloc]
            initWithShape:@[@1, @3, @(height), @(width)]
            dataType:MLMultiArrayDataTypeFloat32
            error:&error];
        
        if (!inputArray) return -1;
        
        // Read pixels from Metal texture → MLMultiArray
        // (In production, use shared memory to avoid copy)
        NSUInteger bytesPerRow = width * 4;
        uint8_t *pixels = (uint8_t *)malloc(bytesPerRow * height);
        [(__bridge id<MTLTexture>)input getBytes:pixels
                                     bytesPerRow:bytesPerRow
                                      fromRegion:MTLRegionMake2D(0, 0, width, height)
                                     mipmapLevel:0];
        
        // Convert RGBA8 → float CHW format
        float *arrayPtr = (float *)inputArray.dataPointer;
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int pixIdx = y * width + x;
                int srcIdx = (y * width + x) * 4;
                arrayPtr[0 * width * height + pixIdx] = pixels[srcIdx + 0] / 255.0f; // R
                arrayPtr[1 * width * height + pixIdx] = pixels[srcIdx + 1] / 255.0f; // G
                arrayPtr[2 * width * height + pixIdx] = pixels[srcIdx + 2] / 255.0f; // B
            }
        }
        free(pixels);
        
        // Run inference
        NSDictionary *inputDict = @{@"input": [MLFeatureValue featureValueWithMultiArray:inputArray]};
        MLDictionaryFeatureProvider *provider =
            [[MLDictionaryFeatureProvider alloc] initWithDictionary:inputDict error:&error];
        
        id<MLFeatureProvider> result = [denoiserModel predictionFromFeatures:provider error:&error];
        if (!result) return -1;
        
        // Write denoised result back to output texture
        MLFeatureValue *outputFeature = [result featureValueForName:@"output"];
        if (outputFeature && outputFeature.multiArrayValue) {
            MLMultiArray *outputArray = outputFeature.multiArrayValue;
            float *outPtr = (float *)outputArray.dataPointer;
            
            uint8_t *outPixels = (uint8_t *)malloc(bytesPerRow * height);
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    int pixIdx = y * width + x;
                    int dstIdx = (y * width + x) * 4;
                    outPixels[dstIdx + 0] = (uint8_t)(fminf(outPtr[0 * width * height + pixIdx], 1.0f) * 255.0f);
                    outPixels[dstIdx + 1] = (uint8_t)(fminf(outPtr[1 * width * height + pixIdx], 1.0f) * 255.0f);
                    outPixels[dstIdx + 2] = (uint8_t)(fminf(outPtr[2 * width * height + pixIdx], 1.0f) * 255.0f);
                    outPixels[dstIdx + 3] = 255;
                }
            }
            
            [(__bridge id<MTLTexture>)output replaceRegion:MTLRegionMake2D(0, 0, width, height)
                                              mipmapLevel:0
                                                withBytes:outPixels
                                              bytesPerRow:bytesPerRow];
            free(outPixels);
        }
        
        return 0;
    }
}

// ---------------------------------------------------------------------------
// Texture Upscaler (Real-ESRGAN)
// ---------------------------------------------------------------------------

/**
 * @brief Upscale a Quake palette texture using Real-ESRGAN on the ANE.
 * @param inputPixels  RGBA8 pixel data (palette-resolved)
 * @param outputPixels Caller-allocated RGBA8 buffer (4x resolution)
 * @param inW Input width
 * @param inH Input height
 * @return 0 on success, -1 if no model
 */
int MQ_CoreML_UpscaleTexture(const uint8_t *inputPixels, uint8_t *outputPixels,
                              int inW, int inH) {
    if (!upscalerModel) return -1;
    
    @autoreleasepool {
        NSError *error = nil;
        MLMultiArray *inputArray = [[MLMultiArray alloc]
            initWithShape:@[@1, @3, @(inH), @(inW)]
            dataType:MLMultiArrayDataTypeFloat32
            error:&error];
        
        if (!inputArray) return -1;
        
        float *ptr = (float *)inputArray.dataPointer;
        for (int y = 0; y < inH; y++) {
            for (int x = 0; x < inW; x++) {
                int idx = (y * inW + x) * 4;
                int pixIdx = y * inW + x;
                ptr[0 * inW * inH + pixIdx] = inputPixels[idx + 0] / 255.0f;
                ptr[1 * inW * inH + pixIdx] = inputPixels[idx + 1] / 255.0f;
                ptr[2 * inW * inH + pixIdx] = inputPixels[idx + 2] / 255.0f;
            }
        }
        
        NSDictionary *inputDict = @{@"input": [MLFeatureValue featureValueWithMultiArray:inputArray]};
        MLDictionaryFeatureProvider *provider =
            [[MLDictionaryFeatureProvider alloc] initWithDictionary:inputDict error:&error];
        
        id<MLFeatureProvider> result = [upscalerModel predictionFromFeatures:provider error:&error];
        if (!result) return -1;
        
        MLFeatureValue *outputFeature = [result featureValueForName:@"output"];
        if (outputFeature && outputFeature.multiArrayValue) {
            MLMultiArray *outArray = outputFeature.multiArrayValue;
            float *outPtr = (float *)outArray.dataPointer;
            int outW = inW * 4, outH = inH * 4;
            
            for (int y = 0; y < outH; y++) {
                for (int x = 0; x < outW; x++) {
                    int pixIdx = y * outW + x;
                    int dstIdx = pixIdx * 4;
                    outputPixels[dstIdx + 0] = (uint8_t)(fminf(outPtr[0 * outW * outH + pixIdx], 1.0f) * 255.0f);
                    outputPixels[dstIdx + 1] = (uint8_t)(fminf(outPtr[1 * outW * outH + pixIdx], 1.0f) * 255.0f);
                    outputPixels[dstIdx + 2] = (uint8_t)(fminf(outPtr[2 * outW * outH + pixIdx], 1.0f) * 255.0f);
                    outputPixels[dstIdx + 3] = 255;
                }
            }
        }
        
        return 0;
    }
}

// ---------------------------------------------------------------------------
// Shutdown
// ---------------------------------------------------------------------------

void MQ_CoreML_Shutdown(void) {
    denoiserModel = nil;
    upscalerModel = nil;
    coremlDevice = nil;
    Con_Printf("CoreML: Pipeline shut down\n");
}
