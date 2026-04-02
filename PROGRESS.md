# Engineering Progress Report: Quake Apple Silicon Modernization

## Session Status: Core Modernization Complete

**Date:** April 1, 2026
**Current State:** **Highly Stable & Modernized.** The engine features a unique hybrid rendering pipeline combining the classic 1996 software renderer with modern Metal Hardware Raytracing. Hardware RT Global Illumination (M3+) remains in progress.

## Major Architectural Updates

### 1. Hybrid Rendering Pipeline (Metal RT)

- **Hardware Raytracing**: Implemented a full Metal Raytracing pass for static world geometry.
  - **BSP Extraction**: Custom logic to triangulate Quake's edge-based BSP faces into GPU-ready vertex/index buffers.
  - **Acceleration Structures**: Dynamic construction of Bottom-Level (BLAS) and Instance (IAS) acceleration structures on map load.
  - **Compute Kernel**: A Metal compute shader (`raytraceMain`) that generates rays using Quake's native camera vectors and performs hardware-accelerated intersection tests.
- **Chromakey Compositing**: The software renderer now bypasses 3D world drawing when RT is enabled, clearing the world area to a "chromakey" index (255). The Metal presentation shader then composites the RT world behind the software-rendered HUD and menus.
- **Raytracing Toggle**: Added as a real-time toggle in the new Video Options menu.

### 2. Dynamic Resolution & Upscaling

- **Fixed Internal Resolution**: Forced the software renderer to a stable 320x240 internal buffer to maintain classic HUD proportions and alignment.
- **Metal Upscaling**: Used `MTLFXSpatialScaler` (or a high-quality linear fallback) to upscale the 320x240 buffer to any window resolution (up to 4K).
- **Resolution Menu**: Integrated a custom "Video Options (Metal)" menu into the Quake UI, allowing dynamic resizing of the game window and Metal textures without restarting.

### 3. High-Performance Platform Layer

- **Unlimited Framerate**: Unlocked the engine tick rate and disabled `CAMetalLayer` VSync (`displaySyncEnabled = NO`), allowing framerates well beyond 100 FPS on Apple Silicon.
- **ARM64 Alignment & Endianness**: Corrected all alignment traps by disabling `UNALIGNED_OK` and added missing `SwapPic` calls for cross-platform data integrity.
- **Robust Audio**: Thread-safe `CircleBuffer` using atomic memory orders bridges Quake's synchronous mixer with Core Audio's high-priority pull callback.
- **Integrated Input**: Full Carbon-to-Quake key mapping and raw mouse-look integration using `CGWarpMouseCursorPosition`.

## Current Performance

- **Resolution**: Dynamically selectable (640x480 to 1920x1080+).
- **Frame Rate**: Uncapped, hitting 100+ FPS on M-series chips.
- **Visuals**: Hybrid Raytraced World + Software HUD.
- **Stability**: Zero known crashes during map loads, menu navigation, or gameplay.

## Build & Run

```bash
./build.sh
./quake_metal -window -width 1280 -height 720 +map start
```

> **Note:** You must provide your own `id1/pak0.pak` (and `pak1.pak` for the full game) in the project root or specify `-basedir`.
