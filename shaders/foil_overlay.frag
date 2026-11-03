#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec2 uLight;       // 0..1 UV of touch point
uniform float uActive;     // 0..1 — halo/streak/sparkles show only when > 0
uniform float uIntensity;  // 0..1 — overall strength
uniform float uTime;       // seconds since epoch — for sparkle animation
uniform vec3 uAccent;      // linear RGB accent color
uniform float uSeed;       // per-card seed for static bands

out vec4 fragColor;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 rainbow(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + t));
}

void main() {
    vec2 uv = FlutterFragCoord() / uSize;
    vec2 light = uLight;

    // ── Static rainbow bands ──
    float lean = (fract(uSeed * 13.7) - 0.5) * 1.4;
    float band = sin((uv.x + uv.y * 0.7 + lean) * 6.0 + uSeed * 0.3) * 0.5 + 0.5;
    vec3 bandColor = mix(uAccent, rainbow(band * 0.6 + uSeed * 0.11), 0.55);
    vec3 accum = bandColor * 0.045 * uIntensity;

    // ── Touch-following halo ──
    float haloDist = distance(uv, light);
    float halo = smoothstep(0.85, 0.0, haloDist) * uActive;
    vec3 haloColor = mix(uAccent, rainbow(haloDist), 0.65);
    accum += haloColor * halo * 0.55 * uIntensity;

    // ── Horizontal streak ──
    float streak = smoothstep(0.35, 0.0, abs(uv.y - light.y)) * uActive;
    accum += vec3(1.0) * streak * 0.22 * uIntensity;

    // ── Procedural sparkles (only when active) ──
    if (uActive > 0.01) {
        vec2 sparkleUV = uv * 14.0;
        float n1 = noise(sparkleUV + uTime * 0.3 + uSeed);
        float n2 = noise(sparkleUV * 2.3 - uTime * 0.4 + uSeed * 0.7);
        float sparkle = smoothstep(0.82, 1.0, n1) * smoothstep(0.75, 1.0, n2);
        sparkle *= uActive;
        vec3 sparkleColor = mix(uAccent, rainbow(uTime * 0.2 + n1), 0.7);
        accum += sparkleColor * sparkle * 1.2;
    }

    // ── Soft vignette ──
    vec2 c = uv - 0.5;
    float vignette = 1.0 - smoothstep(0.3, 0.75, length(c)) * 0.35;
    accum *= vignette;

    float alpha = clamp(length(accum) * 1.4, 0.0, 1.0);
    fragColor = vec4(accum, alpha);
}