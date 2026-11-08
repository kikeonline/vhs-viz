#include <metal_stdlib>
using namespace metal;
struct Uniforms { float4 color; float time; uint seed; };
struct VertexOut { float4 position [[position]]; };
vertex VertexOut sceneVertex(uint id [[vertex_id]]) {
    const float2 positions[] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
    return { float4(positions[id], 0, 1) };
}
fragment float4 sceneFragment(VertexOut in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    return u.color;
}
