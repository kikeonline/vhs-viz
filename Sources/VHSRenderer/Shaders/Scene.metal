#include <metal_stdlib>
using namespace metal;
struct SourceUniforms {
    float4 colorA, colorB, p0, p1, p2;
    uint kind, variant, seed, flags;
    float2 resolution;
    float time, padding;
};
struct VertexOut { float4 position [[position]]; };
vertex VertexOut sceneVertex(uint id [[vertex_id]]) {
    const float2 positions[] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
    return { float4(positions[id], 0, 1) };
}
// Integer-only lattice hash; no sine hash or device-dependent random state.
float lattice(int2 p, uint seed) {
    uint h = (uint(p.x) & 4095u) * 0x9e3779b9u ^ (uint(p.y) & 4095u) * 0x85ebca6bu ^ seed;
    h ^= h >> 16; h *= 0x7feb352du; h ^= h >> 15; h *= 0x846ca68bu; h ^= h >> 16;
    return float(h & 0x00ffffffu) / 16777215.0f;
}
float noiseValue(float2 p, uint seed, uint variant) {
    int2 cell = int2(floor(p));
    float a = lattice(cell, seed);
    if (variant == 1) return a;
    float2 f = fract(p); f = f * f * (3 - 2 * f);
    return mix(mix(a, lattice(cell + int2(1,0), seed), f.x),
               mix(lattice(cell + int2(0,1), seed), lattice(cell + int2(1,1), seed), f.x), f.y);
}
float triangleDistance(float2 p, float radius) {
    const float2 vertices[] = { float2(0,-1), float2(0.8660254,0.5), float2(-0.8660254,0.5) };
    float d = 1e6; bool inside = true;
    for (uint i=0; i<3; ++i) {
        float2 a = vertices[i] * radius, b = vertices[(i+1)%3] * radius;
        float2 edge = b-a, q = p-a;
        d = min(d, length(q - edge * clamp(dot(q,edge)/dot(edge,edge), 0.0f, 1.0f)));
        inside = inside && edge.x*q.y-edge.y*q.x >= 0;
    }
    return inside ? -d : d;
}
float4 sourceImage(float2 pixel, SourceUniforms u) {
    float2 uv = pixel / u.resolution;
    float shortSide = min(u.resolution.x, u.resolution.y);
    if (u.kind == 0) return u.colorA;
    if (u.kind == 1) {
        float2 p = uv-u.p0.yz;
        float2 axis = float2(cos(u.p0.x), sin(u.p0.x));
        float t = u.variant == 0 ? 0.5 + dot(p,axis)/(abs(axis.x)+abs(axis.y))
                                : length(p*u.resolution/shortSide)*2;
        t = clamp(t, 0.0f, 1.0f);
        if (u.p0.w > 0.5) t = 1-t;
        return float4(mix(u.colorA.rgb, u.colorB.rgb, t),1);
    }
    if (u.kind == 2) {
        float2 p = uv*u.resolution/shortSide*u.p0.x + float2(u.time, 0);
        float n = clamp((noiseValue(p,u.seed,u.variant)-0.5)*u.p0.y+0.5, 0.0f, 1.0f);
        return float4(mix(u.colorA.rgb,u.colorB.rgb,n),1);
    }
    if (u.kind == 3) {
        float2 axis = float2(cos(u.p0.z),sin(u.p0.z));
        float phase = dot(uv-0.5,axis)*u.p0.x + u.p0.w - u.time;
        float t = 0.5+0.5*sin(phase*2*M_PI_F);
        if (u.variant == 1) t = 1-abs(2*fract(phase)-1);
        if (u.variant == 2) t = step(0.5f,fract(phase));
        return float4(mix(u.colorB.rgb,u.colorA.rgb,t),1);
    }
    float2 p = (uv-u.p0.yz)*u.resolution/shortSide;
    float c=cos(u.p0.w), s=sin(u.p0.w);
    p = float2(c*p.x+s*p.y, -s*p.x+c*p.y);
    float radius = u.p0.x*0.5;
    float d = length(p)-radius;
    if (u.variant == 1) {
        float2 q = abs(p)-float2(radius*1.5,radius);
        d = length(max(q,float2(0)))+min(max(q.x,q.y),0.0f);
    }
    if (u.variant == 2) d = triangleDistance(p,radius);
    float feather = max(u.p1.x, max(fwidth(d)*0.5, 0.00001));
    float mask = u.p1.z > 0.5 ? 1-smoothstep(u.p1.y-feather,u.p1.y+feather,abs(d))
                             : 1-smoothstep(-feather,feather,d);
    return float4(mix(u.colorB.rgb,u.colorA.rgb,mask),1);
}

fragment float4 sceneFragment(VertexOut in [[stage_in]], constant SourceUniforms &u [[buffer(0)]]) {
    return sourceImage(in.position.xy,u);
}

struct EffectUniforms {
    float4 p0, colorA, colorB;
    float2 resolution;
    uint kind, padding;
};
float4 effectImage(float2 pixel, EffectUniforms u, texture2d<float> image) {
    constexpr sampler sampleImage(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = pixel / u.resolution;
    float3 original = image.sample(sampleImage, uv).rgb;
    if (u.kind == 0) {
        float shortSide = min(u.resolution.x, u.resolution.y);
        float2 p = (uv-0.5)*u.resolution/shortSide - u.p0.xy;
        float c = cos(u.p0.z), s = sin(u.p0.z);
        p = float2(c*p.x+s*p.y, -s*p.x+c*p.y) / u.p0.w;
        float2 source = p*shortSide/u.resolution + 0.5;
        if (any(source < 0) || any(source > 1)) return float4(0,0,0,1);
        return float4(image.sample(sampleImage, source).rgb,1);
    }
    if (u.kind == 1) {
        // Truncated Gaussian: 33 taps over +/- radius, sigma = radius/3.
        float3 sum = 0; float total = 0;
        for (int i=-16; i<=16; ++i) {
            float x = float(i)/16;
            float weight = exp(-4.5*x*x);
            sum += image.sample(sampleImage, uv+u.p0.yz*(x*u.p0.x)/u.resolution).rgb*weight;
            total += weight;
        }
        return float4(sum/total,1);
    }
    if (u.kind == 2) {
        float2 center = (floor(pixel/u.p0.x)+0.5)*u.p0.x;
        return float4(image.sample(sampleImage, center/u.resolution).rgb,1);
    }
    float luminance = dot(original,float3(0.2126,0.7152,0.0722));
    if (u.kind == 3) {
        float value = u.p0.y == 0 ? step(u.p0.x,luminance) : smoothstep(u.p0.x-u.p0.y,u.p0.x+u.p0.y,luminance);
        return float4(float3(value),1);
    }
    if (u.kind == 4) return float4(mix(original,mix(u.colorA.rgb,u.colorB.rgb,luminance),u.p0.x),1);
    float2 offset = u.p0.xy/u.resolution;
    return float4(image.sample(sampleImage,uv+offset).r, original.g, image.sample(sampleImage,uv-offset).b,1);
}

fragment float4 effectFragment(VertexOut in [[stage_in]], constant EffectUniforms &u [[buffer(0)]], texture2d<float> image [[texture(0)]]) {
    return effectImage(in.position.xy,u,image);
}
