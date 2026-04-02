# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### In Progress

- Mesh shader BSP pipeline activation (M3+ meshlet generation).
- `UDP_Read` async-to-sync bridge in `net_apple.cpp`.

---

## [1.2.0] — 2026-04-02

### Added

- **Metal Underwater Warp Shader**: GPU-accelerated sine-wave UV distortion replaces broken software `D_WarpScreen` path. Multi-octave warp with organic feel, gated by BSP leaf contents.
- **CRT Scanline Filter**: Retro monitor emulation with barrel distortion, per-row scanline darkening, phosphor RGB sub-pixel tinting, warm edge vignette, and bright-pixel bloom.
- **Liquid Glass HUD**: Frosted glass overlay on the status bar region with 5-tap weighted blur, blue-white glass tint, animated specular edge ribbon, and chromatic aberration.
- **MetalFX Temporal Scaler**: Halton(2,3) jittered temporal upscaling (640×480 → 1280×960) using RT depth and motion vectors.
- **SSAO**: 8-sample hemisphere kernel with hash-based per-pixel rotation on the RT depth buffer. Range-checked with smoothstep falloff, 60% max darkening.
- **EDR/HDR Output**: Extended Dynamic Range for XDR displays. Highlight expansion allows bright pixels to exceed 1.0 (up to 2.0 peak).
- **Video Options Menu**: 12-item in-game settings panel: Resolution, Raytracing, MetalFX (OFF/Spatial/Temporal), Denoise, SSAO, EDR/HDR, Sensitivity, Auto-aim, CRT Mode, Liquid Glass, Underwater FX, Apply.
- **PostFX Pipeline**: Extensible `PostFXUniforms` struct with 12 fields for hot-toggleable GPU shader effects.
- **CoreML ANE Models**: Placeholder denoiser and Real-ESRGAN upscaler loading on Apple Neural Engine.
- **Settings Persistence**: All rendering features saved/loaded from `id1/metal_quake.cfg`.

### Changed

- **arm64 Memory Modernization**: Complete engine limit overhaul for Apple Silicon:
  - Hunk memory: 32MB → 256MB
  - Zone memory: 48KB → 512KB
  - Edge/surface/span buffers: 65K/16K/65K (from 2.4K/800/3K)
  - MAX_EDICTS: 600 → 2,048 (L2 cache friendly)
  - MAX_PARTICLES: 2,048 → 16,384
  - MAX_VISEDICTS: 256 → 2,048
  - MAX_EFRAGS: 640 → 4,096
  - MAX_DLIGHTS: 32 → 64
  - MAX_OSPATH: 128 → 1,024
  - MAX_MSGLEN: 8,000 → 32,000
- **Static Edge Buffers**: `ledges[]`/`lsurfs[]` moved from stack to BSS — prevents 6MB stack overflow.
- **Edge Overflow Protection**: Bounds check in `R_EmitEdge` returns early instead of corrupting linked lists.

### Fixed

- **Water Area Freeze**: Disabled software `D_WarpScreen` path which generated edges with corrupt `u` values creating circular linked lists in `R_InsertNewEdges`.
- **CoreML Model Missing**: Both `.mlmodelc` assets now present and loading on ANE.

---

## [1.1.0] — 2026-04-02

### Added

- **RT Quality Gating**: `rtQuality` uniform controls shadow ray and GI bounce dispatch.
- **Settings Lifecycle**: `MQ_InitSettings()` → `MQ_LoadSettings()` at startup; `MQ_SaveSettings()` on quit.
- **Game Center Authentication**: `MQ_GameCenter_Init()` fires on engine startup.
- **CoreML Initialization**: `MQ_CoreML_Init()` called with Metal device reference in `VID_Init`.
- **Auto-Denoise**: Denoiser automatically enabled when RT quality is HIGH or above.

### Changed

- `MQ_ApplySettings()` now handles PHASE audio routing implicitly.
- `Host_Shutdown` now calls `MQ_CoreML_Shutdown()` for clean resource release.
- RT shader `raytraceMain` accepts quality parameter at `buffer(15)`.
- Compositor fragment shader accepts `postFX` uniform at `buffer(1)`.

---

## [1.0.0] — 2026-04-01

### Added

- **Metal Rendering Backend** via `metal-cpp` (`vid_metal.cpp`).
- **Hybrid Chromakey Compositing**: Software renderer bypasses 3D world when RT is enabled, clearing to palette index 255. Metal fragment shader composites RT world behind software HUD.
- **Hardware Raytracing**: BSP geometry extraction, BLAS/IAS acceleration structures, and Metal compute kernel for hardware-accelerated intersection.
- **MetalFX Spatial Upscaling**: `MTLFXSpatialScaler` upscales 320×240 internal buffer to window resolution.
- **Core Audio Driver**: Lock-free `CircleBuffer` bridging Quake's synchronous mixer with Core Audio's pull callback using atomic memory ordering.
- **Game Controller Support**: `GCExtendedGamepad` with hot-plug, dual thumbstick input, and `joy_sensitivity` cvar.
- **DualSense Adaptive Triggers**: Right trigger feedback on weapon fire.
- **Core Haptics Integration**: `CHHapticEngine` per-controller with transient haptic events.
- **Network.framework UDP Driver**: Replaces BSD sockets with Apple's modern networking stack.
- **Dynamic Resolution Menu**: Custom Video Options menu for live window resizing.
- **Unlimited Framerate**: VSync disabled, 100+ FPS on Apple Silicon.
- **ARM64 Alignment Fixes**: `UNALIGNED_OK` disabled, `SwapPic` endianness calls added.

### Changed

- Forced internal software renderer resolution to 320×240 for stable HUD proportions.
- Replaced legacy DMA audio with Core Audio `AudioUnit` pipeline.

### Fixed

- `EXC_ARM_DA_ALIGN` faults on Apple Silicon by disabling unaligned access.
- HUD alignment issues at non-standard resolutions.
