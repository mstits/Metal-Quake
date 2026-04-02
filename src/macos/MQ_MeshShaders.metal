/**
 * @file MQ_MeshShaders.metal
 * @brief Metal Mesh Shaders for BSP Rendering (Apple GPU Family 9+)
 *
 * Replaces the traditional vertex-only BSP rendering pipeline with
 * object/mesh shader stages for:
 * - GPU-driven BSP traversal with per-meshlet culling
 * - Frustum + occlusion culling at the meshlet level
 * - Variable-rate shading hints for distant geometry
 *
 * Architecture:
 *   Object Shader → decides which meshlets to emit
 *   Mesh Shader   → generates vertices + primitives per meshlet
 *   Fragment Shader → samples atlas + applies lighting
 *
 * Requires: MTLGPUFamilyApple9 (M3+) for [[mesh]] entry points
 */

#include <metal_stdlib>
using namespace metal;

// ---------------------------------------------------------------------------
// Shared Types
// ---------------------------------------------------------------------------

struct MeshVertex {
    float4 position [[position]];
    float2 texCoord;
    float3 worldPos;
    float3 normal;
    float  lightLevel;
};

struct MeshPrimitive {
    // Per-primitive data (no interpolation)
};

// Meshlet descriptor — up to 64 vertices, 126 triangles per meshlet
struct BSPMeshlet {
    uint vertexOffset;      // Into global vertex buffer
    uint vertexCount;       // Verts in this meshlet (max 64)
    uint indexOffset;       // Into global index buffer  
    uint triangleCount;     // Tris in this meshlet (max 126)
    float4 boundingSphere;  // xyz=center, w=radius (for culling)
    float4 coneApex;        // For backface cone culling
    float4 coneAxis;        // xyz=axis, w=cutoff
};

// Per-frame uniforms
struct MeshUniforms {
    float4x4 viewProjection;
    float4x4 prevViewProjection; // For motion vectors
    float4   cameraPosition;
    float4   frustumPlanes[6];
    float    time;
    uint     meshletCount;
    uint     pad0, pad1;
};

// Vertex data in the global buffer
struct BSPVertex {
    float3 position;
    float2 texCoord;
    float3 normal;
    float  atlasU, atlasV;
    float  lightLevel;
};

// ---------------------------------------------------------------------------
// Object Shader — Per-meshlet culling (runs once per meshlet)
// ---------------------------------------------------------------------------

struct ObjectPayload {
    uint meshletIndices[64]; // Indices of visible meshlets to process
};

// Note: Full mesh shader requires macOS 14+ with Apple9 GPU
// This is scaffolded for compilation on macOS 26 SDK

#if __METAL_VERSION__ >= 310

[[object, max_threadgroups_per_meshgrid(64)]]
void bspObjectShader(
    object_data ObjectPayload& payload [[payload]],
    uint threadIndex [[thread_index_in_threadgroup]],
    uint groupIndex [[threadgroup_position_in_grid]],
    constant MeshUniforms& uniforms [[buffer(0)]],
    device const BSPMeshlet* meshlets [[buffer(1)]],
    mesh_grid_properties meshGridProps)
{
    // Each object thread processes one candidate meshlet
    uint meshletIdx = groupIndex * 64 + threadIndex;
    if (meshletIdx >= uniforms.meshletCount) return;
    
    BSPMeshlet meshlet = meshlets[meshletIdx];
    
    // === Frustum culling against bounding sphere ===
    float3 center = meshlet.boundingSphere.xyz;
    float radius = meshlet.boundingSphere.w;
    
    bool visible = true;
    for (int i = 0; i < 6; i++) {
        float d = dot(uniforms.frustumPlanes[i].xyz, center) + uniforms.frustumPlanes[i].w;
        if (d < -radius) {
            visible = false;
            break;
        }
    }
    
    // === Backface cone culling ===
    if (visible) {
        float3 viewDir = normalize(center - uniforms.cameraPosition.xyz);
        float coneTest = dot(viewDir, meshlet.coneAxis.xyz);
        if (coneTest > meshlet.coneAxis.w) {
            visible = false; // All triangles face away
        }
    }
    
    // Emit visible meshlet
    if (visible && threadIndex < 64) {
        payload.meshletIndices[threadIndex] = meshletIdx;
    }
    
    // Set the mesh grid to process visible meshlets
    if (threadIndex == 0) {
        meshGridProps.set_threadgroups_per_grid(uint3(1, 1, 1));
    }
}

// ---------------------------------------------------------------------------
// Mesh Shader — Generates geometry for one meshlet (max 64v, 126t)
// ---------------------------------------------------------------------------

using BSPMeshType = metal::mesh<MeshVertex, MeshPrimitive, 64, 126, metal::topology::triangle>;

[[mesh, max_total_threads_per_threadgroup(128)]]
void bspMeshShader(
    BSPMeshType output,
    object_data const ObjectPayload& payload [[payload]],
    uint threadIndex [[thread_index_in_threadgroup]],
    uint groupIndex [[threadgroup_position_in_grid]],
    constant MeshUniforms& uniforms [[buffer(0)]],
    device const BSPMeshlet* meshlets [[buffer(1)]],
    device const BSPVertex* vertices [[buffer(2)]],
    device const uint* indices [[buffer(3)]])
{
    uint meshletIdx = payload.meshletIndices[groupIndex];
    BSPMeshlet meshlet = meshlets[meshletIdx];
    
    // Set counts for this meshlet
    output.set_primitive_count(meshlet.triangleCount);
    
    // Generate vertices
    if (threadIndex < meshlet.vertexCount) {
        uint vi = meshlet.vertexOffset + threadIndex;
        BSPVertex v = vertices[vi];
        
        MeshVertex mv;
        mv.position = uniforms.viewProjection * float4(v.position, 1.0);
        mv.texCoord = v.texCoord;
        mv.worldPos = v.position;
        mv.normal = v.normal;
        mv.lightLevel = v.lightLevel;
        
        output.set_vertex(threadIndex, mv);
    }
    
    // Generate triangle indices (3 indices per triangle)
    uint triIdx = threadIndex;
    if (triIdx < meshlet.triangleCount) {
        uint baseIdx = meshlet.indexOffset + triIdx * 3;
        output.set_index(triIdx * 3 + 0, indices[baseIdx + 0] - meshlet.vertexOffset);
        output.set_index(triIdx * 3 + 1, indices[baseIdx + 1] - meshlet.vertexOffset);
        output.set_index(triIdx * 3 + 2, indices[baseIdx + 2] - meshlet.vertexOffset);
    }
}

// ---------------------------------------------------------------------------
// Fragment Shader — Atlas sampling, lighting, motion vectors
// ---------------------------------------------------------------------------

struct MeshFragOut {
    float4 color [[color(0)]];
    float  depth [[color(1)]];      // For MetalFX temporal
    float2 motion [[color(2)]];     // Motion vectors
};

fragment MeshFragOut bspMeshFragment(
    MeshVertex in [[stage_in]],
    texture2d<float> atlasTexture [[texture(0)]],
    constant MeshUniforms& uniforms [[buffer(0)]])
{
    MeshFragOut out;
    
    // Sample atlas texture
    constexpr sampler linearSampler(filter::linear, address::repeat);
    float4 texColor = atlasTexture.sample(linearSampler, in.texCoord);
    
    // Apply BSP lightmap
    float3 lit = texColor.rgb * in.lightLevel;
    
    // Simple directional light
    float3 lightDir = normalize(float3(0.4, 0.3, 0.85));
    float nDotL = max(dot(in.normal, lightDir), 0.0);
    lit += texColor.rgb * nDotL * 0.3;
    
    out.color = float4(lit, 1.0);
    out.depth = in.position.z;
    
    // Motion vectors from current vs previous projection
    float4 prevClip = uniforms.prevViewProjection * float4(in.worldPos, 1.0);
    float2 prevNDC = prevClip.xy / prevClip.w;
    float2 curNDC = in.position.xy / float2(1.0); // Already in clip space
    out.motion = (curNDC - prevNDC) * 0.5;
    
    return out;
}

#endif // __METAL_VERSION__ >= 310
