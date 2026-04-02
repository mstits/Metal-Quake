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

## 2. Platform Layer & Integration

### Thread-Safe Audio Bridge

- **The Challenge**: Quake's mixer is synchronous and pushes data, while Core Audio is asynchronous and pulls data.
- **The Solution**: A custom `CircleBuffer` class using `std::atomic<uint32_t>` for head/tail pointers.
- **Memory Ordering**: Uses `memory_order_acquire/release` to ensure that data written by the engine thread is fully visible to the high-priority Core Audio callback thread without using heavy mutexes.

### Event Handling

- **NSEvent Pump**: The `main` loop in `sys_macos.m` uses `nextEventMatchingMask` to pump the macOS event queue every frame.
- **Raw Input**: Mouse delta is calculated by comparing current cursor position to the window center and then warping the cursor back using `CGWarpMouseCursorPosition`, ensuring infinite rotation without hitting screen edges.

### MetalFX Scaling

- **Upscaling**: The `MTLFXSpatialScaler` is used to upscale the internal 320x240 software buffer to high resolutions (e.g., 1080p). This ensures the HUD remains "classic" size and perfectly aligned, while the 3D world (or upscaled UI) looks crisp.

## 3. Build Configuration

- **Architecture**: Native `arm64` (Apple Silicon).
- **Alignment**: `UNALIGNED_OK` is disabled in `quakedef.h` to prevent `EXC_ARM_DA_ALIGN` faults on ARM hardware.
- **ARC**: Enabled for Objective-C++ files (`vid_metal.cpp`, `in_gamecontroller.mm`) to simplify memory management.

## 4. Networking Architecture

### Network.framework Integration

- **The Challenge**: Quake's original networking uses synchronous BSD sockets (`net_udp.c` / `net_bsd.c`), which don't benefit from Apple's Game Mode optimizations.
- **The Solution**: A `Network.framework`-based UDP driver (`net_apple.cpp`) that replaces the BSD socket layer.
- **Connection Management**: A fixed-size connection table (`MAX_CONNECTIONS = 16`) maps Quake's virtual socket IDs to `nw_connection_t` handles. Connections are dispatched on a dedicated serial queue (`quake.network`).
- **Low-Latency Path**: The listener is configured with `nw_multipath_service_interactive` to signal the system that this is a latency-sensitive game session, enabling Apple's Game Mode optimizations.
- **Async-to-Sync Bridge**: `UDP_Listen` uses `nw_listener_set_new_connection_handler` blocks to accept incoming connections asynchronously, while the engine interface exposes synchronous `UDP_Read`/`UDP_Write` semantics. `UDP_Read` currently returns 0 (stub) — a full implementation would use a synchronized queue populated by receive blocks.

## 5. Game Controller & Haptics

### Controller Integration

- **Framework**: `GameController.framework` with `GCExtendedGamepad` for full dual-stick + trigger support.
- **Hot-Plug**: Connect/disconnect handled via `NSNotificationCenter` observers on `GCControllerDidConnectNotification` / `GCControllerDidDisconnectNotification`.
- **Input Mapping**: Left thumbstick → movement (`forwardmove`/`sidemove`), right thumbstick → view angles. Triggers and face buttons mapped to Quake key events (`K_CTRL` for fire, `K_SPACE` for jump). Deadzone of 0.1 applied to thumbsticks.
- **Sensitivity**: Exposed as a user cvar (`joy_sensitivity`, default 1.0, archived).

### Adaptive Triggers (DualSense)

- **Detection**: Runtime `isKindOfClass:[GCDualSenseGamepad class]` check on connect.
- **Weapon Feedback**: Right trigger set to `setModeFeedbackWithStartPosition:0.2 resistiveStrength:0.8`, providing tactile resistance when pulling the fire trigger.

### Core Haptics

- **Engine Setup**: A `CHHapticEngine` is created per-controller via `createEngineWithLocality:GCHapticsLocalityDefault`.
- **Weapon Fire Pattern**: `IN_PlayHapticFeedback()` fires a `CHHapticEventTypeHapticTransient` event (intensity 1.0, sharpness 1.0, duration 100ms) — designed to be called from game code on weapon fire.
- **Lifecycle**: Engine starts on controller connect, stops on disconnect or `IN_Shutdown`.
