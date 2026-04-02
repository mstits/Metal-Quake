/**
 * @file rt_shader.metal
 * @brief Metal Quake — Ray Tracing Compute Shader with Shadow Rays
 *
 * Generates primary rays from camera, traces against BSP acceleration
 * structure, and casts shadow rays toward light sources for diffuse
 * lighting. Outputs to an RGBA texture for compositing.
 *
 * Requires: Apple GPU Family 6+ (M1 minimum for hardware RT)
 */

#include <metal_stdlib>
using namespace metal;

// ---------------------------------------------------------------------------
// Shared Types
// ---------------------------------------------------------------------------

struct RTVertex {
    float3 position;
    float3 normal;
    float2 texCoord;
    float  lightLevel;
};

struct RTLight {
    float3 position;
    float3 color;
    float  intensity;
    float  radius;
};

struct RTUniforms {
    float3   camOrigin;
    float3   camForward;
    float3   camRight;
    float3   camUp;
    float    fov;
    uint     numLights;
    float    time;
    float    ambientIntensity;
};

// ---------------------------------------------------------------------------
// Primary + Shadow Ray Kernel
// ---------------------------------------------------------------------------

kernel void raytraceMain(
    uint2 tid [[thread_position_in_grid]],
    texture2d<float, access::write> outTexture [[texture(0)]],
    acceleration_structure<instancing> scene [[buffer(0)]],
    constant RTUniforms& uniforms [[buffer(1)]],
    constant RTLight* lights [[buffer(2)]],
    device const RTVertex* vertices [[buffer(3)]],
    device const uint* indices [[buffer(4)]])
{
    uint width = outTexture.get_width();
    uint height = outTexture.get_height();
    
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    // Map pixel to [-1, 1] NDC
    float2 uv = float2(tid) / float2(width, height);
    uv = uv * 2.0 - 1.0;
    uv.y = -uv.y; // Flip Y for Quake coordinate system
    
    // FOV adjustment
    float aspect = float(width) / float(height);
    float tanHalfFov = tan(uniforms.fov * 0.5 * M_PI_F / 180.0);
    uv.x *= aspect * tanHalfFov;
    uv.y *= tanHalfFov;

    // ---- Primary Ray ----
    ray primaryRay;
    primaryRay.origin = uniforms.camOrigin;
    primaryRay.direction = normalize(uniforms.camForward + uv.x * uniforms.camRight + uv.y * uniforms.camUp);
    primaryRay.min_distance = 0.1;
    primaryRay.max_distance = 8192.0; // Quake world extents

    intersector<instancing, triangle_data> isect;
    isect.assume_geometry_type(acceleration_structure_geometry_type::triangle);
    auto intersection = isect.intersect(primaryRay, scene);

    float4 color = float4(0.0, 0.0, 0.0, 0.0); // Transparent = no hit (software render shows through)

    if (intersection.type == intersection_type::triangle) {
        // Get hit point
        float hitDist = intersection.distance;
        float3 hitPoint = primaryRay.origin + primaryRay.direction * hitDist;
        
        // Reconstruct triangle normal from vertex data
        uint triIdx = intersection.primitive_id;
        uint i0 = indices[triIdx * 3 + 0];
        uint i1 = indices[triIdx * 3 + 1];
        uint i2 = indices[triIdx * 3 + 2];
        
        float3 n0 = vertices[i0].normal;
        float3 n1 = vertices[i1].normal;
        float3 n2 = vertices[i2].normal;
        
        // Barycentric interpolation of normal
        float2 bary = intersection.triangle_barycentric_coord;
        float3 hitNormal = normalize(
            n0 * (1.0 - bary.x - bary.y) +
            n1 * bary.x +
            n2 * bary.y
        );
        
        // Interpolate light level from BSP lightmaps
        float ll0 = vertices[i0].lightLevel;
        float ll1 = vertices[i1].lightLevel;
        float ll2 = vertices[i2].lightLevel;
        float bspLight = ll0 * (1.0 - bary.x - bary.y) + ll1 * bary.x + ll2 * bary.y;
        
        // ---- Ambient ----
        float3 ambient = float3(uniforms.ambientIntensity);
        
        // ---- Shadow Rays → Direct Lighting ----
        float3 directLight = float3(0.0);
        
        uint maxLights = min(uniforms.numLights, 8u); // Cap for perf
        for (uint li = 0; li < maxLights; li++) {
            RTLight light = lights[li];
            
            float3 toLight = light.position - hitPoint;
            float lightDist = length(toLight);
            
            // Skip lights beyond their radius
            if (lightDist > light.radius) continue;
            
            float3 lightDir = toLight / lightDist;
            float nDotL = max(dot(hitNormal, lightDir), 0.0);
            
            if (nDotL > 0.001) {
                // Generate noise for soft shadow jitter
                uint seed = tid.x + tid.y * 8192 + uint(uniforms.time * 60.0) * 10000;
                seed = (seed ^ 61) ^ (seed >> 16);
                seed = seed + (seed << 3);
                seed = seed ^ (seed >> 4);
                seed = seed * 0x27d4eb2d;
                seed = seed ^ (seed >> 15);
                float rx = fract(float(seed) / 4294967296.0) * 2.0 - 1.0;
                float ry = fract(float(seed * 13) / 4294967296.0) * 2.0 - 1.0;
                float rz = fract(float(seed * 17) / 4294967296.0) * 2.0 - 1.0;
                float3 jitter = float3(rx, ry, rz) * 0.08; // Area light size
                
                // Cast shadow ray with jitter
                ray shadowRay;
                shadowRay.origin = hitPoint + hitNormal * 0.05; // Bias to avoid self-intersection
                shadowRay.direction = normalize(lightDir + jitter);
                shadowRay.min_distance = 0.01;
                shadowRay.max_distance = lightDist - 0.1;
                
                auto shadowHit = isect.intersect(shadowRay, scene);
                
                if (shadowHit.type == intersection_type::none) {
                    // Not occluded — add light contribution
                    float attenuation = 1.0 - saturate(lightDist / light.radius);
                    attenuation *= attenuation; // Quadratic falloff
                    
                    directLight += light.color * light.intensity * nDotL * attenuation;
                }
            }
        }
        
        // ---- Combine ----
        // Base color from BSP lightmap intensity (grayscale for now)
        float3 baseColor = float3(bspLight);
        
        // Final: ambient + direct lighting applied to base color
        float3 finalColor = baseColor * (ambient + directLight);
        
        // Tone map (simple Reinhard)
        finalColor = finalColor / (finalColor + 1.0);
        
        // Distance fog (atmospheric)
        float fogFactor = 1.0 - saturate(hitDist / 4096.0);
        finalColor *= fogFactor;
        
        color = float4(finalColor, 0.85); // Semi-transparent for blend with software render
    }

    outTexture.write(color, tid);
}

// ---------------------------------------------------------------------------
// Fullscreen Triangle for Compositing
// ---------------------------------------------------------------------------

struct CompVertex {
    float4 position [[position]];
    float2 texCoord;
};

vertex CompVertex compositeVertex(uint vid [[vertex_id]]) {
    CompVertex out;
    // Fullscreen triangle
    out.texCoord = float2((vid << 1) & 2, vid & 2);
    out.position = float4(out.texCoord * 2.0 - 1.0, 0.0, 1.0);
    out.texCoord.y = 1.0 - out.texCoord.y; // Flip for Metal
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
    
    // Alpha blend: RT over software (RT alpha controls mix)
    float3 blended = mix(swColor.rgb, rtColor.rgb, rtColor.a);
    return float4(blended, 1.0);
}
