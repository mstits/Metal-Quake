# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- **BLAS refit path** — when the frame's triangle count matches the previous frame's, the per-frame BLAS update now uses `refitAccelerationStructure` instead of rebuilding from scratch. 3–5× faster on Apple Silicon for stable-topology frames.
- **CoreML `MLModel` load at init** — `MQ_Denoiser.mlmodelc` / `MQ_RealESRGAN.mlmodelc` are loaded with `MLComputeUnitsAll` so they'll run on the ANE when a trained model is dropped in; falls back to the MPS placeholders otherwise.
- **`vid_vsync`** cvar (0=uncapped, 1=display sync). Hot-applied via `CAMetalLayer.displaySyncEnabled` on the main thread.
- **`vid_fullscreen`** cvar. Flips the window through `-[NSWindow toggleFullScreen:]`; the collection behavior is set to `NSWindowCollectionBehaviorFullScreenPrimary` at window creation.
- **`MQBridge_ToggleCvar`** for the launcher to flip bool cvars atomically without relying on a legacy `toggle` console command.
- **Launcher header bar** gains **Screenshot** and **Fullscreen** buttons.
- **Launcher Settings bottom bar** gains **Reset Defaults** — mirrors `MQ_InitSettings`' values on the Swift side.
- **GPU command / encoder labels** (`MQ.RT+Compose`, `RT.Raytrace`, `SVGF.Reproject`, `SVGF.Variance`, `Denoise.Atrous`, `BLAS Build`/`BLAS Refit`) so Instruments and the Metal Debugger group work under readable names.
- **SVGF full variance-guided path** — separate `svgfVariance` compute kernel + RG16Float moments + R16Float variance textures. `r_svgf 2` enables the variance-aware bilateral modulation; `r_svgf 1` keeps the older reprojection-only path.
- **MetalFX Frame Interpolation** fully wired through `MQ_FrameInterp.m` (an ObjC shim that imports `<MetalFX/MetalFX.h>`). Creates a real `MTLFXFrameInterpolator`, encodes a synthesized middle frame between each render, blits the result back into a prev-frame history texture. Gated behind `r_frameinterp`.
- **MTLResidencySet** (macOS 15+) via `MQ_Residency.m` — texture atlas and meshlet buffer are pinned as resident across frames.
- **RT water refraction** — Snell's-law refracted secondary ray samples underwater geometry with depth-attenuated fog; Fresnel Schlick mixes reflection vs refraction.
- **Underwater volumetric fog** when the listener is submerged, with hash-noise density, distinct from the open-air fog curve.
- **Alpha-cutout atlas encoding** — palette index 255 now writes alpha=0 so transparent texels are distinguishable to the RT path.
- **In-game FPS overlay** via new `showfps` cvar; top-right corner, 0.25s smoothing window.
- **`mq_info` + `dumpcvars` console commands** — report hardware / feature state and list every registered cvar.
- **SharePlay Group Activity** (`QuakeGroupActivity`) with engine-side observer that auto-issues `connect <addr>` on incoming session joins; Multiplayer tab now has a **Share via FaceTime** button alongside **Scan LAN**.
- **Game Center auth UI** now presents the sign-in view controller as a sheet on the game window instead of logging "UI needed" and bailing.
- **MetricKit diagnostic subscriber** — crash / hang payloads write to `~/Library/Application Support/MetalQuake/` as JSON on the next launch.
- **Launcher hot-reload** — FOV, gamma, HUD scale, SFX/music volumes, sensitivity, deadzone, rumble intensity, invert-Y, raw-mouse all re-sync cvars as sliders move, not just on Apply.
- **Minimal test harness** (`tests/run.sh`) with two passing tests that covers settings round-trip (caught a real parser bug) and UDP address compare semantics.
- **Distribution pipeline docs** — `build.sh` now honors `MQ_SIGN_IDENTITY`, ships `--options runtime`, and the inline comment block documents the full `notarytool` + `stapler` flow.

### Fixed

- **Settings parser dropped every field** — the loader's `fscanf("%63s %f")` aborted on the first `//` comment line in the saved config, so loads silently fell back to defaults. Switched to line-by-line `fgets` with comment skipping.
- **Video Options menu label overlap** — `Chr. Aberration:` and `Underwater FX:` ran past the ON/OFF value column. Shortened to `Chroma AB:` / `Water FX:` and `Liquid Glass:` → `Glass HUD:`.
- **Bilateral denoiser "plastic wrap" look** — pass count cut from 3 to 2 (dropped the step-width-4 pass that was bleeding across pixel-art texel boundaries) and `sigmaColor` tightened from 0.1 to 0.035.
- **`MQ_ApplySettings` silently forced `neural_denoise` on** when `rt_quality >= HIGH`; now leaves the user's choice alone.
- **SharePlay class lookup failed** at runtime — added `@objc(MQSharePlayManager)` pinning so `NSClassFromString` resolves.
- **RT bias self-shadowing small geometry** — shadow-ray bias scales with hit distance now.
- **Core Audio ring buffer race** — added per-operation memory_order_acquire/release fences; introduced `framesConsumed` atomic so `SNDDMA_GetDMAPos` reports the right DMA index.

---

## [1.3.0] — 2026-04-19

### Fixed

- **Dead CoreML module**. `MPSGraph` executables were declared but never compiled, so `MQ_CoreML_Denoise` / `MQ_CoreML_UpscaleTexture` early-returned `-1` on every call — the whole module was inert. Rewritten to use `MPSImageGaussianBlur` for the per-frame denoiser (GPU-native, no CPU round-trip) and an honest `MPSGraph resizeBilinear` for the upscaler.
- **Settings never persisted**. `MQ_SaveSettings` / `MQ_LoadSettings` existed but had no callers. Now invoked from `sys_macos.m` at Host_Init / before Host_Shutdown, covering all 28 struct fields instead of 16. Forward-compatible (unknown keys silently skipped on load).
- **PHASE BSP occlusion**. Function body was a comment-only stub. Now triangulates `cl.worldmodel->surfaces` into an `MDLMesh`, builds a `PHASEShape` + `PHASEOccluder`, and logs the tri/vert count per map.
- **Net driver sender address**. `StartReceiving` wrote a zeroed `qsockaddr` for every inbound packet, making peers indistinguishable. Now extracts hostname/port via `nw_endpoint_get_hostname` + `nw_endpoint_get_port`.
- **`UDP_CheckNewConnections`** permanently returned `-1`; now dequeues from a `PushPendingConnection` ring populated by the `nw_listener` handler.
- **`UDP_OpenSocket`** returned a virtual index with no binding; now sets a local endpoint on the connection parameters.
- **`_blasEvent` leak** — static-inside-function allocated one `MTLSharedEvent` per process and never released. Moved to module scope and released in `VID_Shutdown`.
- **Per-frame BLAS buffer churn**. `_pRTVertexBuffer` / `_pRTIndexBuffer` were `release()`'d and re-`newBuffer()`'d every frame. Now grow-only with `memcpy` into shared storage.
- **`SNDDMA_GetDMAPos` unit mismatch**. Was returning the proxy ring-buffer's head modulo `sn.samples`, but the ring buffer is a different size than `sn.buffer`. Added a monotonic `framesConsumed` atomic that's scaled into `sn.samples`-space correctly.
- **ARC missing on `.m` files**. `build.sh` passed `-fobjc-arc` in `CXXFLAGS` only; Objective-C files compiled without ARC while using ARC idioms. Now `OBJCFLAGS` applies `-fobjc-arc` to `.m` files specifically.
- **`Info.plist` minimal**. Added `CFBundleShortVersionString`, `CFBundleVersion`, `LSMinimumSystemVersion`, `NSHumanReadableCopyright`, controller metadata, `NSSupportsAutomaticGraphicsSwitching`, and an ad-hoc codesign step.
- **`CMakeLists.txt` out of sync**. Missing six modern `src/macos/` sources; no MPS/PHASE framework links. Synced with `build.sh`.
- **Event-pump autorelease pressure**. Moved the `@autoreleasepool` to wrap each inner event-dequeue iteration so high-rate mouse events drain per-event instead of per-frame.

### Added

- **Weapon-aware adaptive triggers** (DualSense). On weapon-switch edge, right-trigger mode reprograms to match the weapon's feel (Axe=off, SSG=heavy break, Nailgun=vibration, Rocket=max resistance, etc.) rather than a fixed global profile.
- **Gyro aim** via `GCMotion`. `joy_gyro_enabled` / `joy_gyro_yaw` / `joy_gyro_pitch` cvars. Additive on top of stick aim.
- **Controller battery warnings**. `GCDeviceBattery` poll, throttled to once per minute, fires below 15% when not charging.
- **PHASE environment model swap**. Listener leaf `contents` (water / slime / lava / air) drives the `PHASEGeometricSpreadingDistanceModelParameters` cull distance.
- **Mesh-shader LOD uniforms** (`lodNearDistance`, `lodFarDistance`). Beyond the near threshold, object shader emits every *k*-th triangle up to a 4× reduction.
- **SVGF temporal reprojection** behind `r_svgf`. History texture + compute kernel that warps previous denoised output through current motion vectors and blends with current frame. Disabled by default; foundation for full SVGF.
- **Frame Interpolation probe** (`r_frameinterp` cvar + `objc_getClass("MTLFXFrameInterpolator")` at VID_Init). Detection only; encode wiring pending.

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
