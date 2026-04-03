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
