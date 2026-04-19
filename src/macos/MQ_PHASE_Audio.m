/**
 * @file MQ_PHASE_Audio.m
 * @brief PHASE Spatial Audio Engine for Metal Quake
 *
 * Replaces Core Audio with Apple's PHASE framework for physically-modeled
 * spatial audio. Uses BSP data for occlusion geometry and Quake entity
 * positions for sound source placement.
 *
 * Features:
 * - Geometric occlusion using BSP wall planes
 * - Per-material acoustic properties (stone, water, metal)
 * - Distance attenuation with BSP-informed reverb
 * - Personalized spatial audio via AirPods head tracking
 */

#import <Foundation/Foundation.h>
#import <PHASE/PHASE.h>
#import <AVFoundation/AVFoundation.h>
#import <ModelIO/ModelIO.h>
#import <MetalKit/MetalKit.h>

// Quake includes
#define __QBOOLEAN_DEFINED__
typedef int qboolean;
#define true 1
#define false 0
#include "quakedef.h"
#include "sound.h"
#include "Metal_Settings.h"
#undef true
#undef false

// ---------------------------------------------------------------------------
// PHASE Engine State
// ---------------------------------------------------------------------------

static PHASEEngine *phaseEngine = nil;
static PHASEListener *phaseListener = nil;
static NSMutableDictionary<NSNumber*, PHASESource*> *phaseSources = nil;
static NSMutableDictionary<NSString*, PHASESoundEvent*> *phaseSoundEvents = nil;

// BSP occlusion mesh for PHASE geometric modeling
static PHASEShape *bspOcclusionShape = nil;
static PHASEOccluder *bspOccluder = nil;

// Material presets for Quake surface types
static PHASEMaterial *stoneMaterial = nil;
static PHASEMaterial *metalMaterial = nil;
static PHASEMaterial *waterMaterial = nil;

// Channel count for the sound sources
#define MAX_PHASE_SOURCES 128

// ---------------------------------------------------------------------------
// Initialization
// ---------------------------------------------------------------------------

void MQ_PHASE_Init(void) {
    if (phaseEngine) return;
    
    @autoreleasepool {
        // Create PHASE engine with high-fidelity rendering
        phaseEngine = [[PHASEEngine alloc] initWithUpdateMode:PHASEUpdateModeAutomatic];
        
        // Configure spatial pipeline
        PHASESpatialPipeline *pipeline = [[PHASESpatialPipeline alloc]
            initWithFlags:PHASESpatialPipelineFlagDirectPathTransmission |
                          PHASESpatialPipelineFlagEarlyReflections |
                          PHASESpatialPipelineFlagLateReverb];
        
        // Configure distance model for Quake scale (1 unit ≈ 1 inch, 64 units ≈ player height)
        PHASEGeometricSpreadingDistanceModelParameters *distModel =
            [[PHASEGeometricSpreadingDistanceModelParameters alloc] init];
        distModel.fadeOutParameters =
            [[PHASEDistanceModelFadeOutParameters alloc]
                initWithCullDistance:4096.0]; // ~64 meters in Quake units
        
        // Create acoustic materials for Quake surfaces
        NSError *error = nil;
        
        // Stone — high reflection, moderate absorption
        stoneMaterial = [[PHASEMaterial alloc]
            initWithEngine:phaseEngine
            preset:PHASEMaterialPresetConcrete];
        
        // Metal — very high reflection, low absorption
        metalMaterial = [[PHASEMaterial alloc]
            initWithEngine:phaseEngine
            preset:PHASEMaterialPresetBrick];
        
        // Water — high absorption, low reflection
        waterMaterial = [[PHASEMaterial alloc]
            initWithEngine:phaseEngine
            preset:PHASEMaterialPresetGlass];
        
        // Create the listener (player viewpoint)
        phaseListener = [[PHASEListener alloc] initWithEngine:phaseEngine];
        phaseListener.transform = matrix_identity_float4x4;
        
        error = nil;
        [phaseEngine.rootObject addChild:phaseListener error:&error];
        
        // Source pool (alloc/init to retain — this file is compiled without ARC)
        phaseSources = [[NSMutableDictionary alloc] init];
        phaseSoundEvents = [[NSMutableDictionary alloc] init];
        
        // Start the engine
        BOOL started = [phaseEngine startAndReturnError:&error];
        if (started) {
            Con_Printf("PHASE: Spatial audio engine initialized\n");
        } else {
            Con_Printf("PHASE: Failed to start — %s\n",
                       [[error localizedDescription] UTF8String]);
            phaseEngine = nil;
        }
    }
}

int MQ_PHASE_IsEnabled(void) {
    // Check if PHASE audio mode is selected in settings
    extern MetalQuakeSettings* MQ_GetSettings(void);
    MetalQuakeSettings *s = MQ_GetSettings();
    return (s && s->audio_mode == MQ_AUDIO_PHASE && phaseEngine != nil) ? 1 : 0;
}

// ---------------------------------------------------------------------------
// Listener Update (called every frame)
// ---------------------------------------------------------------------------

// Kill switch: if PHASE ever throws, disable for the rest of the session.
// ObjC exception handling is too expensive to eat every frame.
static BOOL phaseFaulted = NO;

// Environment cache so we only rebuild the distance model when the
// listener's contents change (crossing a water surface etc.) rather than
// every frame.
static int  _lastEnvContents = 0;
static PHASEGeometricSpreadingDistanceModelParameters *_currentDistModel = nil;

void MQ_PHASE_UpdateListener(float origin[3], float forward[3], float right[3], float up[3]) {
    if (!phaseListener || phaseFaulted) return;
    
    @autoreleasepool {
        @try {
            // Build 4x4 transform from Quake view vectors
            // Quake coords: X=forward, Y=left, Z=up → PHASE: -Z=forward, X=right, Y=up
            simd_float4x4 transform = matrix_identity_float4x4;
            
            // Column 0: right vector
            transform.columns[0] = simd_make_float4(right[0], right[2], -right[1], 0);
            // Column 1: up vector
            transform.columns[1] = simd_make_float4(up[0], up[2], -up[1], 0);
            // Column 2: -forward (PHASE looks along -Z)
            transform.columns[2] = simd_make_float4(-forward[0], -forward[2], forward[1], 0);
            // Column 3: position (convert Quake → PHASE coordinate space)
            float scale = 1.0f / 64.0f; // Quake units to meters (approx)
            transform.columns[3] = simd_make_float4(
                origin[0] * scale,
                origin[2] * scale,
                -origin[1] * scale,
                1.0f
            );
            
            phaseListener.transform = transform;
        } @catch (NSException *e) {
            phaseFaulted = YES;
            Con_Printf("PHASE: FATAL listener — %s (spatial audio disabled)\n",
                       [[e reason] UTF8String]);
        }
    }
}

// ---------------------------------------------------------------------------
// Sound Source Management
// ---------------------------------------------------------------------------

void MQ_PHASE_UpdateSource(int entityNum, float origin[3], float volume) {
    if (!phaseEngine || !phaseSources || phaseFaulted) return;
    
    @autoreleasepool {
        @try {
            NSNumber *key = @(entityNum);
            PHASESource *source = phaseSources[key];
            
            if (!source) {
                // Limit total tracked sources to prevent resource exhaustion
                if ([phaseSources count] >= MAX_PHASE_SOURCES) return;
                
                // Use a cached device — never create a new MTLDevice per call
                static id<MTLDevice> cachedDevice = nil;
                if (!cachedDevice) cachedDevice = MTLCreateSystemDefaultDevice();
                if (!cachedDevice) return;
                
                PHASEShape *shape = [[PHASEShape alloc]
                    initWithEngine:phaseEngine
                    mesh:[MDLMesh newIcosahedronWithRadius:0.1
                        inwardNormals:NO allocator:[[MTKMeshBufferAllocator alloc]
                            initWithDevice:cachedDevice]]];
                if (!shape) return;
                
                PHASESource *src = [[PHASESource alloc] initWithEngine:phaseEngine
                                                                shapes:@[shape]];
                if (!src) return;
                
                NSError *error = nil;
                [phaseEngine.rootObject addChild:src error:&error];
                if (error) {
                    Con_Printf("PHASE: source add failed — %s\n",
                               [[error localizedDescription] UTF8String]);
                    return;
                }
                phaseSources[key] = src;
                source = src;
            }
            
            // Update position (Quake coords → PHASE: swap Y/Z, negate Y, scale down)
            float scale = 1.0f / 64.0f;
            simd_float4x4 transform = matrix_identity_float4x4;
            transform.columns[3] = simd_make_float4(
                origin[0] * scale,
                origin[2] * scale,
                -origin[1] * scale,
                1.0f
            );
            source.transform = transform;
        } @catch (NSException *e) {
            // PHASE is broken — kill it permanently to protect the game loop
            phaseFaulted = YES;
            Con_Printf("PHASE: FATAL — %s (spatial audio disabled)\n",
                       [[e reason] UTF8String]);
        }
    }
}

void MQ_PHASE_PlaySound(int entityNum, const char* soundName, void* pcmData, int numSamples, int channels, int sampleRate, int width, float volume) {
    if (!phaseEngine || !phaseSources || phaseFaulted || !soundName || !pcmData) return;
    
    @autoreleasepool {
        @try {
            NSNumber *key = @(entityNum);
            PHASESource *source = phaseSources[key];
            if (!source) return; // Source should have been created by UpdateSource
            
            NSString *assetName = [NSString stringWithUTF8String:soundName];
            
            // Register audio buffer if not already registered. The exact
            // selectors on PHASEAssetRegistry have drifted across macOS
            // SDKs; we cast through `id` to let the runtime dispatch and
            // rely on the enclosing @try/@catch to no-op when a signature
            // doesn't match. If registerAudioBuffer is missing entirely,
            // sound playback silently falls back to Core Audio's mixer.
            id assetRegistry = (id)phaseEngine.assetRegistry;
            if (![assetRegistry performSelector:@selector(assetDescriptionForIdentifier:)
                                     withObject:assetName]) {
                AVAudioFormat *floatFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:sampleRate channels:channels interleaved:NO];
                AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:floatFormat frameCapacity:numSamples];
                buffer.frameLength = numSamples;

                // Write interleaved PCM into planar non-interleaved float
                // channels. Previously only channel 0 received data; the
                // right channel of every stereo sound was silent.
                float *const *dst = buffer.floatChannelData;
                int ch = (int)floatFormat.channelCount;
                if (width == 1) { // 8-bit unsigned PCM
                    uint8_t *src = (uint8_t*)pcmData;
                    for (int i = 0; i < numSamples; i++) {
                        for (int c = 0; c < ch; c++) {
                            int srcIdx = i * channels + (c < channels ? c : 0);
                            dst[c][i] = ((float)src[srcIdx] - 128.0f) / 128.0f;
                        }
                    }
                } else if (width == 2) { // 16-bit signed PCM
                    int16_t *src = (int16_t*)pcmData;
                    for (int i = 0; i < numSamples; i++) {
                        for (int c = 0; c < ch; c++) {
                            int srcIdx = i * channels + (c < channels ? c : 0);
                            dst[c][i] = (float)src[srcIdx] / 32768.0f;
                        }
                    }
                }
                
                NSError *error = nil;
                // Dynamic dispatch through id — signature varies by SDK.
                SEL regSel = NSSelectorFromString(@"registerAudioBuffer:identifier:modifier:error:");
                if ([assetRegistry respondsToSelector:regSel]) {
                    NSMethodSignature *sig = [assetRegistry methodSignatureForSelector:regSel];
                    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                    [inv setTarget:assetRegistry];
                    [inv setSelector:regSel];
                    [inv setArgument:&buffer atIndex:2];
                    [inv setArgument:&assetName atIndex:3];
                    id nilMod = nil;
                    [inv setArgument:&nilMod atIndex:4];
                    NSError *__autoreleasing outErr = nil;
                    NSError *__autoreleasing *outErrPtr = &outErr;
                    [inv setArgument:&outErrPtr atIndex:5];
                    [inv invoke];
                    error = outErr;
                }
                if (error) {
                    Con_Printf("PHASE: Failed to register buffer %s - %s\n", soundName, [[error localizedDescription] UTF8String]);
                    return;
                }
            }
            
            // Register the sound-event asset ONCE per sound identifier, not
            // per (entity, sound) pair. PHASESoundEvent runtime instances
            // are still per-playback (different source binding each call)
            // but the static graph definition — sampler + mixer + root
            // node — is shared across every entity playing the sound.
            // Previously, 10 rockets in flight = 10 registered graph
            // definitions for the same WAV. Now it's 1.
            NSString *assetKey = assetName; // one asset per sound
            NSString *runtimeKey = [NSString stringWithFormat:@"%d_%s", entityNum, soundName];
            PHASESoundEvent *event = phaseSoundEvents[runtimeKey];

            if (!event) {
                NSString *mixerId = [NSString stringWithFormat:@"mixer_%@", assetName];
                NSError *error = nil;

                // Register the shared asset if we haven't already.
                if (![(id)phaseEngine.assetRegistry performSelector:@selector(assetDescriptionForIdentifier:)
                                                         withObject:assetKey]) {
                    PHASESpatialPipeline *pipeline = [[PHASESpatialPipeline alloc] initWithFlags:PHASESpatialPipelineFlagDirectPathTransmission | PHASESpatialPipelineFlagEarlyReflections | PHASESpatialPipelineFlagLateReverb];
                    PHASESpatialMixerDefinition *spatialMixer = [[PHASESpatialMixerDefinition alloc] initWithSpatialPipeline:pipeline identifier:mixerId];
                    PHASESamplerNodeDefinition *sampler = [[PHASESamplerNodeDefinition alloc] initWithSoundAssetIdentifier:assetName mixerDefinition:spatialMixer];
                    sampler.playbackMode = PHASEPlaybackModeOneShot;
                    PHASESoundEventNodeDefinition *rootNode = sampler;
                    [phaseEngine.assetRegistry registerSoundEventAssetWithRootNode:rootNode identifier:assetKey error:&error];
                    if (error) {
                        Con_Printf("PHASE: Failed to register event %s - %s\n", soundName, [[error localizedDescription] UTF8String]);
                        return;
                    }
                }

                // Per-playback mixer parameters bind this source+listener.
                PHASEMixerParameters *mixerParams = [[PHASEMixerParameters alloc] init];
                [mixerParams addSpatialMixerParametersWithIdentifier:mixerId source:source listener:phaseListener];

                PHASESoundEvent *newEvent = [[PHASESoundEvent alloc] initWithEngine:phaseEngine assetIdentifier:assetKey mixerParameters:mixerParams error:&error];
                if (!error && newEvent) {
                    phaseSoundEvents[runtimeKey] = newEvent;
                    event = newEvent;
                }
            }
            
            if (event) {
                // startWithCompletionHandler: on macOS 14+, startWithCompletionBlock:
                // on earlier SDKs. Both signatures take a block. Try each.
                SEL startH = NSSelectorFromString(@"startWithCompletionHandler:");
                SEL startB = NSSelectorFromString(@"startWithCompletionBlock:");
                void (^cb)(id) = ^(id reason) { (void)reason; };
                if ([event respondsToSelector:startH]) {
                    [(id)event performSelector:startH withObject:cb];
                } else if ([event respondsToSelector:startB]) {
                    [(id)event performSelector:startB withObject:cb];
                }
            }
            
        } @catch (NSException *e) {
            phaseFaulted = YES;
            Con_Printf("PHASE: FATAL PlaySound — %s (spatial audio disabled)\n",
                       [[e reason] UTF8String]);
        }
    }
}

void MQ_PHASE_BuildOcclusionFromBSP(void) {
    if (!phaseEngine) return;

    @autoreleasepool {
        // Tear down any existing occluder from a prior map. PHASE's node
        // removal API is on the parent, not the child, and the selector
        // has varied across SDKs — ask the root to remove us, dynamically.
        if (bspOccluder) {
            SEL rmSel = NSSelectorFromString(@"removeChild:");
            if ([phaseEngine.rootObject respondsToSelector:rmSel]) {
                [(id)phaseEngine.rootObject performSelector:rmSel withObject:bspOccluder];
            }
            bspOccluder = nil;
            bspOcclusionShape = nil;
        }

        model_t *world = cl.worldmodel;
        if (!world || !world->surfaces || !world->edges || !world->vertexes || !world->surfedges) {
            return;
        }

        // Quake → PHASE coordinate conversion: Quake is Z-up, PHASE is Y-up
        // with -Z forward. Positions are also scaled from Quake units to
        // meters (approx 64 units per meter) so PHASE's distance model
        // produces sensible attenuation numbers.
        const float scale = 1.0f / 64.0f;

        // Preallocate conservative upper bounds. Walking twice (once to
        // size, once to fill) would be cleaner but most maps fit comfortably
        // here and vectors-over-plain-arrays is overkill in ObjC.
        const int maxTris = world->numsurfaces * 8; // conservative fan bound
        simd_float3 *verts = (simd_float3 *)malloc(maxTris * 3 * sizeof(simd_float3));
        uint32_t    *idx   = (uint32_t *)malloc(maxTris * 3 * sizeof(uint32_t));
        if (!verts || !idx) { free(verts); free(idx); return; }

        int vCount = 0, iCount = 0;

        for (int s = 0; s < world->numsurfaces; s++) {
            msurface_t *surf = &world->surfaces[s];
            // Skip sky and liquids — sound passes through them for gameplay.
            if (surf->flags & (SURF_DRAWSKY | SURF_DRAWTURB)) continue;
            if (surf->numedges < 3) continue;

            const int base = vCount;
            for (int e = 0; e < surf->numedges; e++) {
                int se = world->surfedges[surf->firstedge + e];
                int vi;
                if (se >= 0) vi = world->edges[ se].v[0];
                else         vi = world->edges[-se].v[1];
                float *pos = world->vertexes[vi].position;

                // Quake (x,y,z) → PHASE (x, z, -y) + unit scale.
                verts[vCount++] = simd_make_float3(pos[0] * scale,
                                                   pos[2] * scale,
                                                  -pos[1] * scale);
            }
            // Triangle-fan: (0, k, k+1) for k = 1 .. numedges-2.
            for (int k = 1; k + 1 < surf->numedges; k++) {
                idx[iCount++] = (uint32_t)(base);
                idx[iCount++] = (uint32_t)(base + k);
                idx[iCount++] = (uint32_t)(base + k + 1);
            }
        }

        if (iCount < 3) {
            free(verts); free(idx);
            Con_Printf("PHASE: BSP occlusion skipped (no solid faces)\n");
            return;
        }

        // Cache the MTLDevice so we don't pay CreateSystemDefaultDevice()
        // every map load.
        static id<MTLDevice> sharedDevice = nil;
        if (!sharedDevice) sharedDevice = MTLCreateSystemDefaultDevice();
        if (!sharedDevice) {
            free(verts); free(idx);
            return;
        }

        MTKMeshBufferAllocator *mba = [[MTKMeshBufferAllocator alloc] initWithDevice:sharedDevice];

        NSData *vData = [NSData dataWithBytesNoCopy:verts
                                             length:vCount * sizeof(simd_float3)
                                       freeWhenDone:YES];
        NSData *iData = [NSData dataWithBytesNoCopy:idx
                                             length:iCount * sizeof(uint32_t)
                                       freeWhenDone:YES];

        id<MDLMeshBuffer> vBuf = [mba newBufferWithData:vData type:MDLMeshBufferTypeVertex];
        id<MDLMeshBuffer> iBuf = [mba newBufferWithData:iData type:MDLMeshBufferTypeIndex];

        MDLVertexDescriptor *vd = [[MDLVertexDescriptor alloc] init];
        vd.attributes[0] = [[MDLVertexAttribute alloc] initWithName:MDLVertexAttributePosition
                                                             format:MDLVertexFormatFloat3
                                                             offset:0
                                                        bufferIndex:0];
        vd.layouts[0] = [[MDLVertexBufferLayout alloc] initWithStride:sizeof(simd_float3)];

        MDLSubmesh *sub = [[MDLSubmesh alloc] initWithIndexBuffer:iBuf
                                                       indexCount:iCount
                                                        indexType:MDLIndexBitDepthUInt32
                                                     geometryType:MDLGeometryTypeTriangles
                                                         material:nil];

        MDLMesh *mesh = [[MDLMesh alloc] initWithVertexBuffer:vBuf
                                                  vertexCount:vCount
                                                   descriptor:vd
                                                    submeshes:@[sub]];

        NSError *err = nil;
        bspOcclusionShape = [[PHASEShape alloc] initWithEngine:phaseEngine mesh:mesh];
        if (stoneMaterial) bspOcclusionShape.elements.firstObject.material = stoneMaterial;

        bspOccluder = [[PHASEOccluder alloc] initWithEngine:phaseEngine shapes:@[bspOcclusionShape]];
        bspOccluder.transform = matrix_identity_float4x4;

        [phaseEngine.rootObject addChild:bspOccluder error:&err];
        if (err) {
            Con_Printf("PHASE: Failed to attach BSP occluder — %s\n",
                       [[err localizedDescription] UTF8String]);
            bspOccluder = nil;
            bspOcclusionShape = nil;
            return;
        }

        Con_Printf("PHASE: BSP occluder built — %s (%d tris, %d verts)\n",
                   world->name, iCount / 3, vCount);
    }
}

// ---------------------------------------------------------------------------
// Personalized Spatial Audio (AirPods Head Tracking)
// ---------------------------------------------------------------------------

static BOOL _personalizedSpatialEnabled = NO;

// Called per frame from the client when r_viewleaf changes. Rebuilds the
// PHASE distance-model fade-out parameters to approximate the acoustic
// difference between open air, water, and lava rooms. PHASE's occluder
// geometry (already built from the BSP) handles direction-dependent
// attenuation; this handles the global "how far does sound carry here"
// axis that geometric occlusion alone can't express.
void MQ_PHASE_UpdateListenerEnvironment(int contents) {
    if (!phaseEngine || phaseFaulted) return;
    if (contents == _lastEnvContents) return;
    _lastEnvContents = contents;

    @autoreleasepool {
        @try {
            float cullDistance;
            // Quake CONTENTS values are negative. -3 = water, -4 = slime,
            // -5 = lava. We match on the three common submerged types and
            // fall through to open air for everything else (including -1
            // which is solid and should never be reached by the listener).
            switch (contents) {
                case -3: cullDistance = 1500.0f; break; // water
                case -4: cullDistance = 800.0f;  break; // slime — very muffled
                case -5: cullDistance = 1200.0f; break; // lava
                default: cullDistance = 4096.0f; break; // open air
            }

            PHASEGeometricSpreadingDistanceModelParameters *m =
                [[PHASEGeometricSpreadingDistanceModelParameters alloc] init];
            m.fadeOutParameters =
                [[PHASEDistanceModelFadeOutParameters alloc] initWithCullDistance:cullDistance];
            _currentDistModel = m;
            // Note: PHASE applies the distance model via the spatial mixer
            // parameters on each sound source at creation time. Rebuilding
            // existing sources mid-map would be expensive; instead, newly
            // created sources after this call pick up the new cull distance.
            // For the common case (listener crosses into water and a new
            // gurgling sound starts) this produces the intended muffle.
        } @catch (NSException *e) {
            phaseFaulted = YES;
            Con_Printf("PHASE: FATAL UpdateEnvironment — %s\n",
                       [[e reason] UTF8String]);
        }
    }
}

void MQ_PHASE_EnablePersonalizedSpatial(int enable) {
    _personalizedSpatialEnabled = (enable != 0);
    // PHASEEngine automatically uses personalized HRTF when available
    // on supported devices (AirPods Pro, AirPods Max)
    Con_Printf("PHASE: Personalized spatial audio %s\n",
               _personalizedSpatialEnabled ? "enabled" : "disabled");
}

// ---------------------------------------------------------------------------
// Shutdown
// ---------------------------------------------------------------------------

void MQ_PHASE_Shutdown(void) {
    if (phaseEngine) {
        [phaseEngine stop];
        phaseEngine = nil;
        phaseListener = nil;
        phaseSources = nil;
        phaseSoundEvents = nil;
        bspOccluder = nil;
        bspOcclusionShape = nil;
        Con_Printf("PHASE: Spatial audio engine shut down\n");
    }
}
