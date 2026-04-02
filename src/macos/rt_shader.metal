#include <metal_stdlib>
using namespace metal;

struct RTVertex {
    float3 position;
};

// Simple raytracing compute shader
kernel void raytraceMain(
    uint2 tid [[thread_position_in_grid]],
    texture2d<float, access::write> outTexture [[texture(0)]],
    acceleration_structure<instancing> scene [[buffer(0)]],
    constant float3& camOrigin [[buffer(1)]],
    constant float3& camForward [[buffer(2)]],
    constant float3& camRight [[buffer(3)]],
    constant float3& camUp [[buffer(4)]])
{
    if (tid.x >= outTexture.get_width() || tid.y >= outTexture.get_height()) {
        return;
    }

    float width = outTexture.get_width();
    float height = outTexture.get_height();

    // Map to [-1, 1]
    float2 uv = float2(tid) / float2(width, height);
    uv = uv * 2.0 - 1.0;
    uv.y = -uv.y; // Flip Y

    // FOV adjustment
    float aspect = width / height;
    uv.x *= aspect;

    // Ray generation
    ray r;
    r.origin = camOrigin;
    r.direction = normalize(camForward + uv.x * camRight + uv.y * camUp);
    r.min_distance = 0.1;
    r.max_distance = 10000.0;

    intersector<instancing, triangle_data> intersector;
    auto intersection = intersector.intersect(r, scene);

    float4 color = float4(0.0, 0.0, 0.0, 1.0);

    if (intersection.type == intersection_type::triangle) {
        // Simple depth/distance visualization
        float d = intersection.distance;
        float intensity = 1.0 - saturate(d / 2000.0);
        color = float4(intensity, intensity, intensity, 1.0);
    }

    outTexture.write(color, tid);
}
