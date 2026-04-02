# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### In Progress
- Hardware Ray Tracing Global Illumination for M3+ chips.
- `UDP_Read` async-to-sync bridge in `net_apple.cpp`.

---

## [1.0.0] — 2026-04-01

### Added
- **Metal Rendering Backend** via `metal-cpp` (`vid_metal.cpp`).
- **Hybrid Chromakey Compositing**: Software renderer bypasses 3D world when RT is enabled, clearing to palette index 255. Metal fragment shader composites RT world behind software HUD.
- **Hardware Raytracing**: BSP geometry extraction, BLAS/IAS acceleration structures, and Metal compute kernel (`rt_shader.metal`) for hardware-accelerated intersection.
- **MetalFX Spatial Upscaling**: `MTLFXSpatialScaler` upscales 320×240 internal buffer to window resolution.
- **Core Audio Driver** (`snd_coreaudio.cpp`): Lock-free `CircleBuffer` bridging Quake's synchronous mixer with Core Audio's pull callback using atomic memory ordering.
- **Game Controller Support** (`in_gamecontroller.mm`): `GCExtendedGamepad` with hot-plug, dual thumbstick input, and `joy_sensitivity` cvar.
- **DualSense Adaptive Triggers**: Right trigger feedback (`resistiveStrength: 0.8`) on weapon fire.
- **Core Haptics Integration**: `CHHapticEngine` per-controller with transient haptic events on weapon fire.
- **Network.framework UDP Driver** (`net_apple.cpp`): Replaces BSD sockets with Apple's modern networking stack. Low-latency path via `nw_multipath_service_interactive`.
- **Dynamic Resolution Menu**: Custom Video Options menu for live window resizing.
- **Unlimited Framerate**: VSync disabled, 100+ FPS on Apple Silicon.
- **ARM64 Alignment Fixes**: `UNALIGNED_OK` disabled, `SwapPic` endianness calls added.
- **Full Carbon-to-Quake Key Mapping** and raw mouse-look via `CGWarpMouseCursorPosition`.

### Changed
- Forced internal software renderer resolution to 320×240 for stable HUD proportions.
- Replaced legacy DMA audio with Core Audio `AudioUnit` pipeline.

### Fixed
- `EXC_ARM_DA_ALIGN` faults on Apple Silicon by disabling unaligned access.
- HUD alignment issues at non-standard resolutions.
