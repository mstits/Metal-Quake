# Gemini CLI: Engineering Lessons & Architecture Notes

## 1. Project Structure Modernization (April 2026)

- **Decoupling Strategy**: Engine core (`src/core`) must remain platform-agnostic C11 code. All Apple-specific frameworks (Metal, Core Audio, CoreML) should reside in `src/macos`.
- **Legacy Cleanup**: Standard Quake ports often include DOS/Linux packaging scripts (`.spec.sh`, etc.) and x86 assembly headers (`asm_i386.h`). These should be aggressively purged in an Apple Silicon port to reduce "noise" during symbol search.
- **Transitive Header Dependencies**: Critical engine headers like `draw.h` and `vid.h` are often included by core logic. When moving files, ensure these are accessible via `-I` flags rather than relative paths to maintain "GPL-clean" boundaries.

## 2. GPU Rendering Optimizations (Item 3 Failures)

- **Alignment Bottleneck**: The `TriTexInfo` structure used in the raytracing kernel is highly sensitive to alignment. Even with manual padding, expanding this struct to handle GPU-side animation caused "grey screen" regressions. 
- **Indexing Stability**: Quake's world geometry indexing is based on primitive IDs that map directly to the `TriTexInfo` buffer. Moving animation resolution to the GPU requires 100% synchronization between the CPU's texture frame state and the GPU's uniform `time` value.
- **Chromakey Reliability**: The hybrid compositor uses palette index **255** for the 3D bypass. Any shader change that affects palette lookup or background clearing can break the "hole" through which the Metal world is visible.

## 3. High-Frequency Input (M3+)

- **Mouse Polling**: On M3+ hardware, `CGEvent` deltas provide significantly higher precision than standard `NSEvent` loops. 
- **Warp Survival**: Using raw deltas allows the engine to ignore system-level mouse acceleration and "warping" constraints, which is essential for consistent sensitivity at high framerates.

## 4. Hardware Mesh Shaders (M3+)

- **Integrated Pipeline**: The pipeline must support `MTL::MeshRenderPipelineDescriptor` with object, mesh, and fragment stages. 
- **Meshlet Extraction**: Quake's BSP surfaces must be clustered into meshlets (max 64 vertices / 126 triangles) for efficient rasterization.
- **Culling Efficiency**: Per-meshlet culling in the object shader provides a significant performance boost over traditional vertex processing for high-density maps.

## 5. IAS/BLAS Architectural Failure (Global vs. Local Indexing)

- **The Indexing Trap**: In Metal Raytracing, `primitive_id` is local to the hit Bottom-Level Acceleration Structure (BLAS). 
- **Metadata Mismatch**: Because the engine uses a unified `TriTexInfo` buffer, splitting geometry into multiple BLAS objects (e.g., Static World vs. Dynamic Entities) causes the shader to look up incorrect metadata for any instance with an `instance_id > 0`.
- **The "Broken pastelle" Visuals**: This failure manifests as incorrect texture offsets and missing geometry, as the shader attempts to read world-load metadata for entity triangles.
- **Robustness Decision**: For this specific hybrid architecture, rebuilding a single, unified BLAS every frame is the most reliable way to maintain the 1:1 mapping between `primitive_id` and the metadata buffers without introducing a complex indirection layer.
\n## 6. Machine Learning / CoreML (MPSGraph) Refactor\n\n- **MPSGraph Tensor API**: When migrating from standard CoreML `MLModel` wrappers to native Metal 4 Tensor APIs (`MPSGraph`), avoid using `compileWithDevice:makeExecutable:` as it is not an available selector on macOS 14+ for `MPSGraph`. Instead, you can execute the graph directly via `runWithCommandBuffer:inputs:results:executionDescriptor:`.\n- **MPSNDArray Data Extraction**: The underlying data from `MPSGraphTensorData`'s `mpsndarray` cannot be accessed via a `.data` property. It must be explicitly copied to a buffer using `[ndarray readBytes:ptr strideBytes:nil]`.

## 7. Hardware Mesh Shaders & metal-cpp Integration

- **String Loading Without Foundation**: When loading external `.metal` files from within C++ code (via `metal-cpp`), avoid standard Foundation APIs like `NS::String::stringWithContentsOfFile` as they are often undefined or excluded from minimalist C++ headers. Standard C++ `<fstream>` reading into an `NS::String::string(content.c_str(), NS::UTF8StringEncoding)` is robust.
- **Meshlet Descriptor Pipeline**: The `MTL::MeshRenderPipelineDescriptor` setup requires specifying three distinct shader stages (Object, Mesh, and Fragment). `metal-cpp` fully supports this starting from Metal 3 headers, avoiding the need for Objective-C bridging when wiring up high-poly meshlet clustering.

## 8. GameController & Adaptive Triggers

- **Quake Key_Event Bridging**: To bridge macOS `GCController` events to Quake's legacy `Key_Event(int key, qboolean down)` state machine, maintain a static boolean struct of the previous frame's button states and only dispatch `Key_Event` when `curr != prev`.
- **DualSense APIs**: To use DualSense-specific features (like `GCDualSenseAdaptiveTrigger`) on macOS 11.3+ without risking linker errors or missing symbols on older OS versions, dynamically check `[controller.physicalInputProfile isKindOfClass:NSClassFromString(@"GCDualSenseGamepad")]` and suppress the availability warnings using `#pragma clang diagnostic ignored "-Wunguarded-availability-new"`.
- **Weapon-Aware Resistance**: Map Quake's `cl.stats[STAT_ACTIVEWEAPON]` bitflags to specific `setModeWeaponWithStartPosition` or `setModeVibrationWithStartPosition` configurations to provide distinct trigger pulls for the Shotgun, Nailgun, and Rocket Launcher.

## 9. Parallel Command Encoding (GCD)

- **Multiple Command Buffers**: Apple Silicon GPUs excel when fed by multiple cores. Splitting the monolithic engine loop by allocating multiple `MTLCommandBuffer` instances and encoding them concurrently via `dispatch_apply` yields significant performance gains.
- **GPU Thread Synchronization**: When generating independent compute and render command buffers simultaneously, it is critical to enforce execution order on the GPU. Using an `MTLSharedEvent`, the compute buffer can call `encodeSignalEvent:value:` while the render buffer uses `encodeWaitForEvent:value:` prior to its render pass. This guarantees "Glitch-Stable" rendering, preventing the UI from composite tearing against a half-finished raytracing or upscaling dispatch.

## 10. Apple PHASE Spatial Audio Integration

- **Deferred Asset Binding**: The PHASE (`Physical Audio Spatialization Engine`) framework will throw unrecoverable internal exceptions if you attempt to play `PHASESoundEvent` instances without properly registering the backing assets. Do not assign an uninitialized `PHASESource` to a listener.
- **Raw PCM Wrapping**: To feed a retro engine's raw software-mixed PCM data (e.g., Quake's 11kHz/8-bit `.wav` cache) into PHASE, you must bridge it via `AVAudioPCMBuffer`. First, convert the raw 8-bit or 16-bit integer data into `AVAudioPCMFormatFloat32` arrays.
- **Mixer Parameter Association**: A `PHASESoundEvent` does not automatically attach to a `PHASESource` even if the source is added to the engine's root object. You must allocate a `PHASESpatialMixerDefinition` (with a unique string identifier) inside the node graph, and then explicitly bind the `PHASESource` and `PHASEListener` to that definition at runtime using `[PHASEMixerParameters addSpatialMixerParametersWithIdentifier:source:listener:]`.

## 11. Zero-Stutter Shader Caching (`MTLBinaryArchive`)
- **Implicit Caching**: Modern `metal-cpp` on macOS 14+ natively integrates with `MTLBinaryArchive`. By simply creating an archive and setting it on the pipeline descriptors (`setBinaryArchives`), the driver automatically caches the JIT-compiled shaders.
- **Serialization**: Calling `serializeToURL` immediately after pipeline generation writes the JIT cache to disk. On the next launch, loading this URL allows the driver to skip compilation, removing micro-stutters during level loads.

## 12. Apple Game Mode & Network.framework
- **Opting In**: Game Mode is activated by ensuring the compiled binary is packaged inside a `.app` bundle with an `Info.plist` that explicitly declares `<key>LSApplicationCategoryType</key><string>public.app-category.games</string>`. This reduces Bluetooth latency for controllers and prioritizes GPU threads.
- **Multipath UDP**: By simply passing `nw_multipath_service_interactive` into `nw_parameters_set_multipath_service` during the setup of `Network.framework` sockets, UDP packets can seamlessly transition between Ethernet and Wi-Fi channels, creating a dramatically more stable multiplayer connection.\n
