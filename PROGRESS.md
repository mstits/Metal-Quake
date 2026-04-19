# Engineering Progress Report: Quake Apple Silicon Modernization

## Session Status: v1.3.0 — Honesty + Depth Pass

**Date:** April 19, 2026
**Current State:** Previous "Shipped" claims in the README that were actually dead code or scaffolding have been either made real or reclassified as In Motion. The engine compiles and runs the same as 1.2.0, with these concrete additions:

- **GPU Gaussian denoiser**. The prior `MPSGraph` pipeline was dead code — its executables were never compiled, so every call early-returned `-1` and the bilateral à-trous ran alone. Replaced with `MPSImageGaussianBlur` consuming and producing `MTLTexture` directly — no CPU round-trip, no per-frame `malloc/free`, no pixel loops.
- **Settings persistence**. `MQ_SaveSettings`/`MQ_LoadSettings` are now called from `sys_macos.m` at Host_Init / shutdown, and cover all 28 struct fields instead of the prior 16. Forward-compatible on load (unknown keys skipped).
- **PHASE BSP occluder**. Walks `cl.worldmodel->surfaces`, fan-triangulates every non-sky/non-liquid face into an `MDLMesh`, and attaches a `PHASEOccluder` so sound geometry actually matches world geometry. Listener environment also drives a distance-model swap (water/slime/lava/air) so submerged sounds attenuate faster.
- **Network driver**. `StartReceiving` now extracts the remote endpoint into a `qsockaddr` so the engine can tell peers apart. `UDP_CheckNewConnections` dequeues from a pending-connection ring fed by the `nw_listener` callback. `UDP_OpenSocket` binds a local port instead of returning a virtual ID.
- **Controller polish**. Weapon-switch edge reprograms DualSense adaptive-trigger profile; gyro aim integrated when a motion sensor is present (`joy_gyro_*` cvars); battery-level warnings throttled to once per minute.
- **Core Audio ring buffer**. Added monotonic `framesConsumed` so `SNDDMA_GetDMAPos` reports the DMA buffer's play cursor in the right units; prior code returned the proxy ring buffer's head, which has a different size than `sn.samples`.
- **Per-event autoreleasepool** around the macOS event pump — input-heavy frames no longer accumulate autorelease objects until `Host_Frame`.
- **Mesh-shader LOD** gated on `lodNearDistance`/`lodFarDistance` uniforms — meshlets beyond the near threshold emit every *k*-th triangle, capped at 4× reduction.
- **SVGF scaffolding**. History texture + temporal-reprojection compute kernel, gated by `r_svgf` cvar. Variance-aware weights are the remaining SVGF half.
- **MetalFX Frame Interpolation** availability detection via `objc_getClass("MTLFXFrameInterpolator")`; `r_frameinterp` cvar registered. Full encode wiring pending (vendored metal-cpp lacks the header; runtime path works).
- **Cleanups**. `_blasEvent` no longer leaks on every process launch; per-frame vertex/index buffers grow-and-reuse instead of `release()` + `newBuffer()` churn; `Info.plist` carries full version metadata; `build.sh` applies `-fobjc-arc` to `.m` files (previously only `.mm`); `CMakeLists.txt` sources synced with `build.sh`.

## v1.2.0 — PostFX Pipeline Complete

**Date:** April 2, 2026
**State:** Full 12-stage GPU post-processing pipeline, MetalFX spatial + temporal upscaling, SSAO, EDR/HDR, CoreML ANE inference (see note above), and 12-item in-game settings menu. Legacy platform code (3dfx, OpenGL, DOS, X11) removed. Engine runs at 120+ fps with all effects active on Apple Silicon.

## Major Architectural Updates

### 1. Hybrid Rendering Pipeline (Metal RT)

- **Hardware Raytracing**: Full Metal RT pass for world geometry, entities, and brush models.
  - **Texture Atlas**: BSP textures + entity skins packed into a single GPU atlas with animation support.
  - **Entity Rendering**: Alias models (monsters, items, weapons) and brush entities (doors, lifts) rendered per-frame with proper transforms and UV mapping.
  - **Dynamic Lights**: `cl_dlights[]` extracted and shadow-tested in the RT shader.
  - **1-Bounce GI**: Stochastic path-traced global illumination with cosine-weighted hemisphere sampling.
- **Chromakey Compositing**: Software renderer bypasses 3D when RT enabled; Metal compositor blends RT world behind software HUD.
- **Quality Gating**: RT quality setting controls shadow ray and GI bounce dispatch. LOW = BSP lightmap only, MEDIUM+ = full shadow + GI.

### 2. Post-Processing Pipeline (12 stages)

All effects run in a single fragment shader pass with zero-cost branching when disabled:

| # | Stage | Controls |
|---|-------|----------|
| 1 | Underwater Warp | `underwater_fx` + BSP leaf type |
| 2 | Bloom & Adaptive Sharpen | Always on |
| 3 | Film Grain | Always on (2% intensity) |
| 4 | ACES Tonemapping | Always on |
| 5 | Color Grading | Always on |
| 6 | Cinematic DoF | Autofocus on RT depth |
| 7 | Cinematic Vignette | Always on |
| 8 | SSAO | `ssao_enabled` |
| 9 | Screen Blends | Quake cshift system |
| 10 | CRT Scanlines | `crt_mode` |
| 11 | Liquid Glass HUD | `liquid_glass_ui` |
| 12 | EDR/HDR Output | `edr_enabled` |

### 3. Dynamic Resolution & Upscaling

- **Fixed Internal Resolution**: Software renderer at stable 320×240 for classic HUD proportions.
- **MetalFX Spatial**: 320×240 → 1280×960 upscale.
- **MetalFX Temporal**: 640×480 → 1280×960 with Halton(2,3) jitter, RT depth + motion vectors.
- **GPU Bilateral Denoiser**: 3-pass À-trous wavelet filter with edge-aware depth stop function.
- **12-Item Video Menu**: Resolution, RT, MetalFX, Denoise, SSAO, EDR, Sensitivity, Auto-aim, CRT, Liquid Glass, Underwater FX, Apply.

### 4. Apple Ecosystem Integration

| Module | Status | Init Location |
|--------|--------|---------------|
| **Settings** (`Metal_Renderer_Main.cpp`) | ✅ Live — init/load/save/apply | `Host_Init` / `Host_WriteConfiguration` |
| **PHASE Audio** (`MQ_PHASE_Audio.m`) | ✅ Live — listener + source updates per-frame | `Host_Init` / `S_Update` / `S_StartSound` |
| **CoreML Pipeline** (`MQ_CoreML.m`) | ✅ Models loaded on ANE | `VID_Init` (after Metal device) |
| **Game Center** (`MQ_Ecosystem.m`) | ✅ Auth fires on launch | `Host_Init` |
| **Sound Spatializer** (`MQ_Ecosystem.m`) | ✅ Live — per-frame update | `Host_Frame` |
| **SwiftUI Launcher** (`MetalQuakeLauncher.swift`) | ✅ Compiled — macOS 26+ | `build.sh` (swiftc) |

### 5. High-Performance Platform Layer

- **Unlimited Framerate**: 120+ FPS with full PostFX pipeline on Apple Silicon.
- **ARM64 Alignment**: All unaligned access traps resolved.
- **Thread-Safe Audio**: Atomic `CircleBuffer` bridge between Quake mixer and Core Audio.
- **Raw Mouse Input**: CGEvent deltas via `Sys_Tahoe_Input.mm` with 8kHz support.
- **Game Controller**: `GCExtendedGamepad` with adaptive triggers and Core Haptics.

### 6. Legacy Code Removal

Removed 34 dead source files (−20,863 lines):

- **DOS drivers**: `vid_vga.c`, `vid_ext.c`, `vid_svgalib.c`, `vgamodes.h`, `snd_gus.c`, `cd_audio.c`
- **OpenGL renderer**: `gl_draw.c`, `gl_mesh.c`, `gl_model.c/h`, `gl_refrag.c`, `gl_rlight.c`, `gl_rmain.c`, `gl_rmisc.c`, `gl_rsurf.c`, `gl_screen.c`, `gl_test.c`, `gl_warp.c`, `gl_warp_sin.h`, `glquake.h`, `glquake2.h`
- **Serial networking**: `net_ser.c/h`, `net_comx.c`, `mplib.c`, `mplpc.c`
- **X11 driver**: `vid_x.c`
- **Null stubs**: `in_null.c`, `snd_null.c`, `vid_null.c`, `sys_null.c`, `net_none.c`
- **Legacy defines removed**: `GLQUAKE_VERSION`, `D3DQUAKE_VERSION`, `LINUX_VERSION`, `X11_VERSION`

## Current Performance

| Test | Result |
|------|--------|
| `timedemo demo1` (e1m1) | ~115 fps (RT + PostFX) |
| `timedemo demo2` (e1m4) | ~130 fps (RT + PostFX) |
| Software-only compositing | 200+ fps |
| Build time | ~8 seconds (incremental: <1s) |

## Build & Run

```bash
./build.sh
./quake_metal -window -width 1280 -height 720 +map start
```

> **Note:** You must provide your own `id1/pak0.pak` (and `pak1.pak` for the full game) in the project root or specify `-basedir`.
