# Metal Quake

### A port of Quake to native Apple technologies.

> *A technical proof of concept exploring the rebuilding of a classic rendering and input engine entirely on Apple-native frameworks.*

https://github.com/user-attachments/assets/a1a26eeb-9a0e-45be-9e3e-616848d55ff9

---

## What This Is

**Metal Quake** maps id Software's original 1996 Quake engine onto native Apple technologies. No SDL. No OpenGL. No third-party dependencies.

This is an **active work-in-progress** that acts as a testbed for Apple platform APIs inside of an existing C codebase.

### Current State & Observations

- **Rendering**: Implements a hybrid architecture. When `vid_rtx 1` is active, BSP geometry and dynamic lights are path-traced in Metal. The original software renderer is maintained in parallel to establish precise Z-buffer depth, allowing software-rendered particles and sprites to correctly occlude against the ray-traced world before being composited onto the Metal view. A hardware Mesh Shader (`MTL::MeshRenderPipelineDescriptor`) fallback exists for ultra-fast traditional rasterization.
- **Parallel Encoding**: The main render loop utilizes `dispatch_apply` to split the encoding of heavy GPU compute tasks (Raytracing, Denoising) and Render tasks (Compositing, UI) across multiple Apple Silicon P-cores concurrently. Thread-safe GPU synchronization is handled via `MTLSharedEvent`.
- **Input Robustness**: Mouse look exclusively relies on raw `CGEvent` deltas and programmatic cursor warping, forcefully establishing window focus to survive system-level event hijacking (such as `Cmd+Tab` or macOS screenshot overlays).
- **Post-Processing**: 12-stage GPU fragment shader pipeline with CRT scanlines, Liquid Glass HUD, SSAO, EDR/HDR, ACES tonemapping, depth of field, bloom, and underwater warp — all hot-toggleable from the in-game Video Options menu.
- **Machine Learning**: Native `MPSGraph` integration provides on-device Neural Denoising and Real-ESRGAN texture upscaling without the overhead of CoreML wrapper layers.

---

## Feature Status

Features are categorized honestly:

- **Shipped** — Compiled, linked, and actively running in the game loop every frame
- **In Motion** — Built but disabled for stability, or partially integrated
- **Planned** — Design intent only, not compiled into binary

| Layer | Apple Framework | Status | What It Does |
| --- | --- | --- | --- |
| **Rendering** | Metal | Shipped | Metal device, texture pipeline, unified compositor with software elements |
| **Ray Tracing** | Metal RT | Shipped | BLAS from BSP geometry, RT intersection, dynamic GI + emissive surfaces |
| **Post-Processing** | Metal Fragment | Shipped | CRT scanlines, Liquid Glass HUD, SSAO, EDR/HDR, ACES tonemapping, DoF, bloom |
| **Upscaling** | MetalFX | Shipped | Spatial (320→1280) + Temporal (640→1280) with Halton jitter |
| **Legacy Audio** | Core Audio | Shipped | Lock-free ring buffer, async pull model |
| **Spatial Audio** | PHASE | Shipped | Physically-modeled sound with BSP occlusion, raw PCM float32 conversion |
| **Mouse Input** | CGEvent | Shipped | Raw delta input, continuous cursor warping, robust focus survival |
| **Keyboard** | Carbon / NSEvent | Shipped | Full key mapping |
| **Controllers** | GameController | Shipped | DualSense + Xbox — sticks, triggers, D-pad, Weapon-Aware Adaptive Triggers |
| **Threading** | GCD | Shipped | `dispatch_apply` parallel command buffer encoding and BSP leaf marking |
| **Networking** | Network.framework | Shipped | UDP driver with NWConnection/NWListener + Multipath UDP for low latency |
| **UI** | SwiftUI | Shipped | NSPanel launcher overlay, full settings bridge to engine cvars |
| **Settings Sync** | UserDefaults | Shipped | Cross-syncs `@AppStorage` values to engine variables |
| **Machine Learning** | MPSGraph (Metal 4) | Shipped | Real-time Neural Denoising and Texture Upscaling via direct Tensor APIs |
| **Mesh Shaders** | Metal 3.1 | Shipped | High-poly BSP clustering (BSPMeshlets) with Object-Shader frustum culling |
| **Shader Caching** | MTLBinaryArchive | Shipped | Zero-stutter implicit caching and serialization to disk |
| **OS Integration** | Game Mode | Shipped | Bundled `.app` with Game Mode opt-in for doubled Bluetooth polling rates |

---

## Performance

Benchmarked on M4 Max, 640×480 internal RT resolution -> 1280x960 MetalFX display resolution:

| Demo | FPS | Description |
| --- | --- | --- |
| demo1 (e1m1) | **~180-220** | The Slipgate Complex — tight corridors |
| demo2 (e1m4) | **~250+** | The Grisly Grotto — large open caverns |
| demo3 (loop) | **~180-260** | Mixed indoor/outdoor geometry |

> [!NOTE]
> These benchmarks reflect the engine running at full tilt: Path-Traced GI, Neural Denoising, MetalFX Temporal Upscaling, ACES Tonemapping, CRT Scanlines, and Parallel Command Encoding all active.

---

## Architecture

```mermaid
graph TB
    subgraph "SwiftUI Shell"
        Launcher["Launcher / Settings"]
    end

    subgraph "Engine Core (C11, 1996)"
        GameLoop["Host_Frame"]
        Physics["SV_Physics"]
        BSP["BSP Traversal"]
        SoftRender["Software Renderer"]
    end

    subgraph "Metal Pipeline"
        Composite["Metal Texture Composite"]
        RT["RT Shader (active)"]
        PostFX["PostFX Pipeline (12-stage)"]
        MeshShader["Mesh Shaders (active fallback)"]
        MetalFX["MetalFX Spatial+Temporal"]
        MPS["MPSGraph (Denoiser/Upscaler)"]
    end

    subgraph "Audio"
        CoreAudio["Core Audio (active)"]
        PHASE["PHASE Spatial (active)"]
        Haptics["Core Haptics (active)"]
    end

    subgraph "Input"
        Mouse["CGEvent Mouse (active)"]
        Controller["GameController (active)"]
        Keys["Carbon Keyboard (active)"]
    end

    Launcher --> GameLoop
    GameLoop --> Physics & BSP
    BSP --> SoftRender --> Composite
    RT -.-> MPS -.-> PostFX -.-> MetalFX
    GameLoop --> CoreAudio & PHASE & Haptics
    Mouse & Controller & Keys --> GameLoop
```

---

## Build

```bash
./build.sh
open build/Quake.app
```

**Requirements:**
- Apple Silicon Mac (M1+)
- macOS 14.0+ (Sonoma/Sequoia/Tahoe)
- Xcode Command Line Tools
- `id1/pak0.pak` (user-provided — no game assets included)

> [!CAUTION]
> This repository contains **no proprietary game assets**. You must provide your own `id1/pak0.pak`.

---

## Project Structure

```text
Metal_Quake/
├── Quake/                        # id Tech 1 engine core (67 .c + 55 .h)
│   └── sys_macos.m               # macOS system layer + event loop
├── src/macos/                    # Apple platform layer (20 files)
│   ├── vid_metal.cpp             # Metal rendering, PostFX pipeline, 12-item menu, GCD parallel dispatch
│   ├── rt_shader.metal           # RT intersection + GI compute kernel
│   ├── Metal_Renderer_Main.cpp   # Settings init/save/load lifecycle
│   ├── Metal_Settings.h          # MetalQuakeSettings struct definition
│   ├── MQ_MeshShaders.metal      # Object/mesh/fragment pipeline (M3+)
│   ├── MQ_LiquidGlass.metal      # Refractive glass compositor
│   ├── MQ_PHASE_Audio.m          # PHASE spatial audio with dynamic float32 buffers
│   ├── MQ_CoreML.m               # MPSGraph denoiser + upscaler
│   ├── MQ_Ecosystem.m            # Game Center + SharePlay + Accessibility
│   ├── MetalQuakeLauncher.swift  # SwiftUI launcher
│   ├── net_apple.cpp             # Network.framework UDP driver (Multipath)
│   ├── snd_coreaudio.cpp         # Core Audio ring buffer
│   ├── in_gamecontroller.mm      # GameController + DualSense Adaptive Triggers + Core Haptics
│   ├── GCD_Tasks.m               # Parallel dispatch utilities
│   └── Sys_Tahoe_Input.mm        # Unified input architecture
├── metal-cpp/                    # Vendored Apple metal-cpp headers
├── build.sh                      # Single-command build (clang, arm64) → build/Quake.app
└── id1/                          # Game data (user-provided)
```

## Controller Mapping

Full gamepad support for DualSense, Xbox, and MFi controllers:

| Button | Action |
| --- | --- |
| Right Trigger | Fire (Adaptive Resistance on DualSense) |
| Left Trigger / A | Jump |
| Y / Right Bumper | Next weapon |
| Left Bumper | Previous weapon |
| B | Swim down |
| X | Use / Interact |
| Menu | Pause (Escape) |
| Left Stick | Move |
| Right Stick | Look |
| D-pad | Move (alternate) |

---

## Core Haptics & DualSense Adaptive Triggers

Every weapon has a distinct haptic profile and adaptive trigger resistance tuned for its feel:

| Weapon | Trigger Pull (DualSense) | Haptic Rumble Feel |
| --- | --- | --- |
| Axe | None | Sharp thud |
| Shotgun | Heavy pull, sudden break | Medium punch |
| Super Shotgun | Heavy pull, sudden break | Heavy double-tap |
| Nailgun | Continuous machine-gun vibration | Light rapid |
| Super Nailgun | Continuous machine-gun vibration | Medium rapid |
| Grenade Launcher | Max resistance | Deep thump |
| Rocket Launcher | Max resistance | Heavy kick |
| Lightning Gun | Smooth, constant resistance | Sustained buzz |

Damage feedback scales proportionally. Nearby explosions produce distance-attenuated low-frequency feedback.

---

## License

**GPLv2** — Fork of the Quake source code originally released by id Software.

*Quake is a registered trademark of id Software / ZeniMax Media / Microsoft.*