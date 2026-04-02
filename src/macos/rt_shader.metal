/**
 * @file rt_shader.metal
 * @brief Metal Quake — Standalone RT Shader Reference
 *
 * NOTE: The *active* ray tracing shader is compiled inline within
 * vid_metal.cpp's BuildPipeline() function. This file serves as the
 * external reference implementation compiled into quake_rt.metallib
 * alongside MQ_MeshShaders.metal and MQ_LiquidGlass.metal.
 *
 * The inline shader in vid_metal.cpp is the authoritative version and
 * includes all current features:
 * - Texture atlas sampling with animated texture support
 * - Entity (alias model) rendering with skin UVs
 * - Brush entity rendering (doors, lifts)
 * - 1-bounce stochastic GI with cosine-weighted hemisphere sampling
 * - Dynamic point light shadow rays
 * - Liquid surface reflections (water, lava, slime, teleporter)
 * - PBR specularity from texture luminance
 * - Emissive material detection (fire, lava, light fixtures)
 * - MetalFX temporal: depth + motion vector output
 * - Quality gating: shadow rays and GI bounce skip on LOW quality
 *
 * Requires: Apple GPU Family 6+ (M1 minimum for hardware RT)
 */

#include <metal_stdlib>
using namespace metal;

// ---------------------------------------------------------------------------
// Shared Types (must match vid_metal.cpp)
// ---------------------------------------------------------------------------

struct RTVertex {
    float x, y, z;  // position
    float u, v;      // texture coordinates
};

struct TriTexInfo {
    float atlas_u, atlas_v;    // atlas offset (normalized)
    float atlas_w, atlas_h;    // atlas region size (normalized)
    float tex_w, tex_h;        // original texture size (pixels)
    float pad0;                // BSP lightmap average intensity
    float pad1;                // liquid type (0=solid, 1=water, 2=lava, 3=slime, 4=tele)
};

struct GPUDynLight {
    float x, y, z, radius;
};

// ---------------------------------------------------------------------------
// Compositing Shaders (compiled into metallib)
// ---------------------------------------------------------------------------

struct CompVertex {
    float4 position [[position]];
    float2 texCoord;
};

vertex CompVertex compositeVertex(uint vid [[vertex_id]]) {
    CompVertex out;
    out.texCoord = float2((vid << 1) & 2, vid & 2);
    out.position = float4(out.texCoord * 2.0 - 1.0, 0.0, 1.0);
    out.texCoord.y = 1.0 - out.texCoord.y;
    return out;
}

fragment float4 compositeFragment(
    CompVertex in [[stage_in]],
    texture2d<float> softwareRender [[texture(0)]],
    texture2d<float> rtRender [[texture(1)]])
{
    constexpr sampler s(filter::linear);
    float4 swColor = softwareRender.sample(s, in.texCoord);
    float4 rtColor = rtRender.sample(s, in.texCoord);
    float3 blended = mix(swColor.rgb, rtColor.rgb, rtColor.a);
    return float4(blended, 1.0);
}
