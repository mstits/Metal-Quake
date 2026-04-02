# Quake Metal Port: Technical Architecture

This document provides a deep dive into the modernization of the Quake engine for Apple Silicon using Metal.

## 1. Hybrid Rendering Architecture

The engine uses a "Hybrid" approach to maintain the original 1996 aesthetics while leveraging modern GPU hardware.

### Chromakey Compositing

- **Software Layer**: The original software renderer is forced to a 320x240 internal resolution.
- **Bypass Logic**: When Raytracing is ON, `R_RenderView` (in `r_main.c`) skips the 3D world drawing and instead clears the depth-tested world area to a specific palette index (**255**).
- **Metal Layer**: A Metal Compute shader runs a raytracing pass for the 3D world.
- **Compositing Shader**: A fragment shader (`fragmentMain` in `vid_metal.cpp`) samples the software buffer. If a pixel index is 255, it returns the raytraced color; otherwise, it returns the software-rendered UI/HUD color.

### Metal Raytracing (RT)

- **Geometry Extraction**: Custom logic in `BuildRTXWorld` iterates through the `cl.worldmodel->surfaces`. It extracts vertices from the edge-list based BSP and triangulates them into a GPU-ready buffer.
- **Acceleration Structures**:
  - **BLAS**: A Bottom-Level Acceleration Structure is built for the static world geometry.
  - **IAS**: An Instance Acceleration Structure is used to position the world in the scene.
- **Ray Generation**: The compute kernel uses Quake's `vpn`, `vright`, and `vup` vectors to construct a pinhole camera ray for every pixel on the 1280x720 (upscaled) grid.

### Post-Processing Pipeline (PostFX)

The fragment shader implements a multi-stage post-processing pipeline via the extensible `PostFXUniforms` struct:

```
struct PostFXUniforms {
    float4 screenBlend;   // Damage/powerup color shifts
    float  time;          // realtime (for animation)
    float  underwater;    // BSP leaf contents flag
    float  crt_mode;      // CRT scanline filter
    float  liquid_glass;  // Frosted glass HUD
    float2 resolution;    // Output resolution (pixels)
    float  ssao_enabled;  // Screen-space ambient occlusion
    float  edr_enabled;   // Extended Dynamic Range
};
```

**Pipeline stages** (in order):

1. **Underwater Warp** — Multi-octave sine-wave UV distortion when `r_viewleaf->contents <= CONTENTS_WATER`. Gated by `underwater_fx` setting.
2. **Bloom & Adaptive Sharpen** — 5-tap weighted Gaussian with edge-aware Laplacian sharpening.
3. **Film Grain** — Hash-based temporal noise at 2% intensity.
4. **ACES Tonemapping** — Filmic tone curve with 1.15× exposure boost.
5. **Color Grading** — Gentle saturation boost (1.15×) and S-curve contrast.
6. **Cinematic DoF** — Center-point autofocus with 4-tap bokeh blur.
7. **Cinematic Vignette** — Quadratic edge darkening (0.65–1.0 range).
8. **SSAO** — 8-sample hemisphere kernel with hash-based per-pixel rotation on RT depth buffer. Range-checked with `smoothstep` falloff, 60% max darkening.
9. **Screen Blends** — Quake's `cshift` system (damage, powerups, underwater tint).
10. **CRT Scanline Filter** — Barrel distortion, per-row scanline darkening, phosphor RGB sub-pixel tinting, warm edge vignette, and bright-pixel bloom.
11. **Liquid Glass HUD** — 5-tap weighted blur on bottom 15% of screen, blue-white glass tint, animated specular ribbon, and chromatic aberration at glass boundaries.
12. **EDR Output** — Highlight expansion for XDR displays (pixels > 0.8 luminance scale to 2.0 peak).

### GPU Bilateral Denoiser

A 3-pass À-trous wavelet filter compiled as an inline Metal compute shader:
- **Edge-aware**: Cross-bilateral weights from depth + color similarity.
- **Multi-scale**: Step widths 1, 2, 4 for cascading spatial coverage.
- **Ping-pong**: Uses `_pDenoiseScratch` texture for efficient in-place iteration.

## 2. arm64 Memory Modernization

The engine's 1996-era memory limits have been overhauled for Apple Silicon's unified memory architecture:

| Constant | Original | arm64 | File | Rationale |
|----------|----------|-------|------|-----------|
| Hunk memory | 32 MB | 256 MB | `sys_macos.m` | Unified memory pool |
| Zone memory | 48 KB | 512 KB | `zone.c` | Dynamic allocation |
| Edge buffer | 2,400 | 65,536 | `r_shared.h` | Complex geometry |
| Surface buffer | 800 | 16,384 | `r_shared.h` | Surface tracking |
| Span buffer | 3,000 | 65,536 | `r_shared.h` | Scanline rasterizer |
| MAX_EDICTS | 600 | 2,048 | `quakedef.h` | L2 cache friendly |
| MAX_PARTICLES | 2,048 | 16,384 | `r_part.c` | Rich effects |
| MAX_VISEDICTS | 256 | 2,048 | `client.h` | Visible entities |
| MAX_EFRAGS | 640 | 4,096 | `client.h` | Entity fragments |
| MAX_DLIGHTS | 32 | 64 | `client.h` | Dynamic lights |
| MAX_OSPATH | 128 | 1,024 | `quakedef.h` | macOS paths |
| MAX_MSGLEN | 8,000 | 32,000 | `quakedef.h` | Network messages |
| MAX_DATAGRAM | 1,024 | 4,096 | `quakedef.h` | Unreliable packets |

### Stability Hardening

- **Static Buffers**: `ledges[]` / `lsurfs[]` moved from stack to BSS in `R_EdgeDrawing` — prevents 6MB stack overflow on complex maps.
- **Overflow Guard**: `R_EmitEdge` includes a bounds check that returns early instead of corrupting the edge linked list.
- **Warp Bypass**: `r_dowarp` forced `false` in `R_SetupFrame` — the legacy software `D_WarpScreen` path generated corrupt edge data causing infinite loops in `R_InsertNewEdges`.

## 3. Platform Layer & Integration

### Thread-Safe Audio Bridge

- **The Challenge**: Quake's mixer is synchronous and pushes data, while Core Audio is asynchronous and pulls data.
- **The Solution**: A custom `CircleBuffer` class using `std::atomic<uint32_t>` for head/tail pointers.
- **Memory Ordering**: Uses `memory_order_acquire/release` to ensure that data written by the engine thread is fully visible to the high-priority Core Audio callback thread without using heavy mutexes.

### PHASE Spatial Audio

- **Initialization**: `MQ_PHASE_Init()` at startup, deferred until needed.
- **Per-frame updates**: `MQ_PHASE_UpdateListener()` with camera origin/forward/right/up vectors.
- **Per-sound updates**: `MQ_PHASE_UpdateSource()` called from `S_StartSound` for spatial positioning.
- **BSP Occlusion**: `MQ_PHASE_BuildOcclusionFromBSP()` called on map load.

### Event Handling

- **NSEvent Pump**: The `main` loop in `sys_macos.m` uses `nextEventMatchingMask` to pump the macOS event queue every frame.
- **Raw Input**: Mouse delta is calculated using `CGEvent` deltas via `Sys_Tahoe_Input.mm` with 8kHz support.

### MetalFX Scaling

- **Spatial Scaler**: `MTLFXSpatialScaler` upscales the internal 320×240 software buffer to display resolution (1280×960).
- **Temporal Scaler**: `MTLFXTemporalScaler` upscales the RT output (640×480) to display resolution using depth + motion vectors. Dispatched after the bilateral denoiser with an 8-sample Halton(2,3) jitter sequence for temporal stability. Gated by `metalfx_mode == MQ_METALFX_TEMPORAL`.
- **Output Texture**: Dedicated 1280×960 BGRA8 private texture (`_pMFXOutputTexture`) for scaler writeback.

## 4. CoreML / Apple Neural Engine

### Architecture

```
MQ_CoreML_Init(device)
    ├── Load MQ_Denoiser.mlmodelc → MLModel (ANE)
    └── Load MQ_RealESRGAN.mlmodelc → MLModel (ANE)

MQ_CoreML_Denoise(input, output, w, h) → int
MQ_CoreML_UpscaleTexture(input, output, inW, inH) → int
```

- **Model Format**: CoreML `.mlmodelc` compiled bundles.
- **Current Models**: Placeholder identity/bilinear (ready for trained weights).
- **Expected Input**: `MQ_Denoiser` — 640×480×3 float32. `MQ_RealESRGAN` — 160×120×3 float32 → 640×480×3.
- **Shutdown**: `MQ_CoreML_Shutdown()` called from `Host_Shutdown`.

### Build Script

`scripts/create_coreml_models.py` generates placeholder models using `coremltools` NeuralNetworkBuilder API.

## 5. Build Configuration

- **Architecture**: Native `arm64` (Apple Silicon).
- **Alignment**: `UNALIGNED_OK` is disabled in `quakedef.h` to prevent `EXC_ARM_DA_ALIGN` faults on ARM hardware.
- **ARC**: Enabled for Objective-C++ files.
- **Metal Shaders**: Compiled to `quake_rt.metallib` via `xcrun metal` → `xcrun metallib`.

## 6. Game Controller & Haptics

### Controller Integration

- **Framework**: `GameController.framework` with `GCExtendedGamepad` for full dual-stick + trigger support.
- **Hot-Plug**: Connect/disconnect handled via `NSNotificationCenter` observers.
- **Input Mapping**: Left thumbstick → movement, right thumbstick → view angles. Deadzone of 0.1.
- **Sensitivity**: User cvar `joy_sensitivity` (default 1.0, archived).

### Adaptive Triggers (DualSense)

- **Detection**: Runtime `isKindOfClass:[GCDualSenseGamepad class]` check.
- **Weapon Feedback**: Right trigger `setModeFeedbackWithStartPosition:0.2 resistiveStrength:0.8`.

### Core Haptics

- **Engine Setup**: `CHHapticEngine` per-controller via `createEngineWithLocality:GCHapticsLocalityDefault`.
- **Per-Weapon Patterns**: `IN_PlayWeaponHaptic(weaponId)` — intensity/sharpness/duration tuned per weapon (Axe=sharp thud, Rocket=heavy kick, Lightning=sustained buzz).
- **Damage Feedback**: `IN_PlayDamageHaptic(count)` — intensity proportional to damage severity (10→light, 100+→full slam).
- **Explosion Feedback**: `IN_PlayExplosionHaptic(distance)` — strength inversely proportional to distance.
- **Integration Points**: Weapon haptics wired in `CL_ParseClientdata` (punchangle), damage in `V_ParseDamage`.

### Force Touch Trackpad

- **Fallback**: `IN_PlayTrackpadHaptic(pattern)` uses `NSHapticFeedbackManager` when no controller is connected.

## 7. Settings System

All features are controlled via `MetalQuakeSettings` (defined in `Metal_Settings.h`), a runtime-mutable struct with categories:

- **Rendering**: RT toggle, quality preset (OFF/LOW/MEDIUM/HIGH/ULTRA), MetalFX mode, neural denoise, mesh shaders, Liquid Glass UI.
- **Resolution**: Internal/display width and height.
- **Audio**: Core Audio vs PHASE, spatial audio, master volume.
- **Input**: Mouse sensitivity, auto-aim, invert-Y, raw mouse, controller deadzone.
- **Intelligence**: CoreML texture upscaling, neural bots.
- **Post-Processing**: CRT mode, SSAO, chromatic aberration, EDR, underwater FX.
- **Accessibility**: Sound spatializer, high-contrast HUD, subtitles.

Settings persist to `id1/metal_quake.cfg` and are loaded at startup via `MQ_LoadSettings()`.

## 8. Networking Architecture

### Network.framework Integration

- **Connection Management**: Fixed-size connection table (`MAX_CONNECTIONS = 16`) maps Quake socket IDs to `nw_connection_t` handles.
- **Low-Latency Path**: `nw_multipath_service_interactive` enables Apple Game Mode optimizations.
- **Async-to-Sync Bridge**: `UDP_Listen` uses async handlers; `UDP_Read` currently returns 0 (stub for full implementation).
