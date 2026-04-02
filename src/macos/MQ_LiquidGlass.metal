/**
 * @file MQ_LiquidGlass.metal
 * @brief Liquid Glass Compositor Shader for Metal Quake
 *
 * Implements Tahoe-era refractive glass effects for HUD elements:
 * - Refractive distortion sampling from the scene behind glass
 * - Frosted blur for glass material simulation
 * - Chromatic aberration at glass edges
 * - Specular highlights from environment
 *
 * Used for: HUD ammo counter, health, status bar, menu overlays
 * Requires: macOS 26 SDK final for .glassEffect() in SwiftUI
 */

#include <metal_stdlib>
using namespace metal;

// ---------------------------------------------------------------------------
// Glass Material Properties
// ---------------------------------------------------------------------------

struct GlassUniforms {
    float2 resolution;        // Output resolution
    float  refractionIndex;   // Index of refraction (1.0 = air, 1.5 = glass)
    float  blurRadius;        // Frosted glass blur amount (0 = clear)
    float  chromaticStrength; // Chromatic aberration strength
    float  opacity;           // Glass opacity (0 = invisible, 1 = opaque)
    float  time;              // Animation time
    float  tintStrength;      // How much to tint the glass
    float4 tintColor;         // Glass tint (RGBA)
};

// ---------------------------------------------------------------------------
// Liquid Glass Compositor Kernel
// ---------------------------------------------------------------------------

/**
 * Composites a glass overlay over the game scene.
 * Reads from the scene texture and applies refractive distortion
 * based on a normal map derived from the glass shape.
 */
kernel void liquidGlassComposite(
    uint2 tid [[thread_position_in_grid]],
    texture2d<float, access::read> sceneTexture [[texture(0)]],
    texture2d<float, access::read> glassNormalMap [[texture(1)]],
    texture2d<float, access::read> glassMask [[texture(2)]],
    texture2d<float, access::write> outTexture [[texture(3)]],
    constant GlassUniforms& uniforms [[buffer(0)]])
{
    if (tid.x >= outTexture.get_width() || tid.y >= outTexture.get_height()) return;
    
    float2 uv = float2(tid) / uniforms.resolution;
    
    // Read glass mask — 0 = no glass, 1 = full glass
    float glassFactor = glassMask.read(tid).r;
    
    if (glassFactor < 0.001) {
        // No glass — pass through scene
        outTexture.write(sceneTexture.read(tid), tid);
        return;
    }
    
    // Read glass normal for refraction direction
    float3 glassN = glassNormalMap.read(tid).xyz * 2.0 - 1.0;
    
    // === Refractive distortion ===
    float refractionAmount = (uniforms.refractionIndex - 1.0) * 0.15;
    float2 distortion = glassN.xy * refractionAmount * glassFactor;
    
    // Animate subtle fluid motion
    float warp = sin(uv.x * 20.0 + uniforms.time * 2.0) * cos(uv.y * 15.0 + uniforms.time * 1.5);
    distortion += float2(warp, -warp) * 0.002 * glassFactor;
    
    // === Chromatic aberration ===
    float2 uvR = uv + distortion * (1.0 + uniforms.chromaticStrength);
    float2 uvG = uv + distortion;
    float2 uvB = uv + distortion * (1.0 - uniforms.chromaticStrength);
    
    // Sample scene through distorted coordinates
    uint2 tidR = uint2(clamp(uvR * uniforms.resolution, float2(0), uniforms.resolution - 1.0));
    uint2 tidG = uint2(clamp(uvG * uniforms.resolution, float2(0), uniforms.resolution - 1.0));
    uint2 tidB = uint2(clamp(uvB * uniforms.resolution, float2(0), uniforms.resolution - 1.0));
    
    float4 refracted;
    refracted.r = sceneTexture.read(tidR).r;
    refracted.g = sceneTexture.read(tidG).g;
    refracted.b = sceneTexture.read(tidB).b;
    refracted.a = 1.0;
    
    // === Frosted blur (box blur approximation) ===
    if (uniforms.blurRadius > 0.1) {
        float3 blurred = float3(0);
        int radius = int(uniforms.blurRadius);
        float count = 0.0;
        for (int dy = -radius; dy <= radius; dy++) {
            for (int dx = -radius; dx <= radius; dx++) {
                uint2 samplePos = uint2(clamp(int2(tid) + int2(dx, dy), int2(0), int2(outTexture.get_width()-1, outTexture.get_height()-1)));
                blurred += sceneTexture.read(samplePos).rgb;
                count += 1.0;
            }
        }
        refracted.rgb = blurred / count;
    }
    
    // === Glass tinting ===
    float3 tinted = mix(refracted.rgb, uniforms.tintColor.rgb, uniforms.tintStrength * glassFactor);
    
    // === Specular highlight on glass surface ===
    float3 lightDir = normalize(float3(0.3, -0.5, 0.8));
    float spec = pow(max(dot(glassN, lightDir), 0.0), 64.0) * 0.4 * glassFactor;
    tinted += float3(spec);
    
    // === Edge glow (Fresnel-like) ===
    float edgeFactor = 1.0 - abs(glassN.z);
    float fresnel = pow(edgeFactor, 3.0) * 0.15 * glassFactor;
    tinted += float3(fresnel) * uniforms.tintColor.rgb;
    
    // Blend glass with original scene based on opacity
    float3 original = sceneTexture.read(tid).rgb;
    float3 finalColor = mix(original, tinted, uniforms.opacity * glassFactor);
    
    outTexture.write(float4(finalColor, 1.0), tid);
}

// ---------------------------------------------------------------------------
// HUD Glass Effect — Specialized for status bar elements
// ---------------------------------------------------------------------------

/**
 * Simplified glass pass specifically for the Quake HUD status bar.
 * Uses a rectangular region at the bottom of the screen.
 */
kernel void hudGlassEffect(
    uint2 tid [[thread_position_in_grid]],
    texture2d<float, access::read> sceneTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant GlassUniforms& uniforms [[buffer(0)]])
{
    if (tid.x >= outTexture.get_width() || tid.y >= outTexture.get_height()) return;
    
    float2 uv = float2(tid) / uniforms.resolution;
    float4 scene = sceneTexture.read(tid);
    
    // HUD region: bottom 15% of screen
    float hudMask = smoothstep(0.82, 0.85, uv.y);
    
    if (hudMask < 0.01) {
        outTexture.write(scene, tid);
        return;
    }
    
    // Frosted glass blur in HUD region
    float3 blurred = float3(0);
    int blurR = 3;
    float total = 0.0;
    for (int dy = -blurR; dy <= blurR; dy++) {
        for (int dx = -blurR; dx <= blurR; dx++) {
            float weight = 1.0 / (1.0 + float(dx*dx + dy*dy));
            uint2 sp = uint2(clamp(int2(tid) + int2(dx, dy), int2(0), 
                int2(outTexture.get_width()-1, outTexture.get_height()-1)));
            blurred += sceneTexture.read(sp).rgb * weight;
            total += weight;
        }
    }
    blurred /= total;
    
    // Tint with slight color
    float3 glassColor = blurred * float3(0.95, 0.97, 1.0) + float3(0.02);
    
    // Edge highlight
    float edgeHighlight = smoothstep(0.83, 0.85, uv.y) * (1.0 - smoothstep(0.98, 1.0, uv.y));
    glassColor += float3(0.1) * edgeHighlight * sin(uv.x * 50.0 + uniforms.time) * 0.1;
    
    float3 final = mix(scene.rgb, glassColor, hudMask * uniforms.opacity);
    outTexture.write(float4(final, 1.0), tid);
}
