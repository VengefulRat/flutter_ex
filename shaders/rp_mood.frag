#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform vec3 uMoodColor; // Passed from Dart based on the story's mood
uniform float uIntensity; // How strong the effect is

out vec4 fragColor;

// Simple noise function
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = fract(sin(dot(i, vec2(12.9898, 78.233))) * 43758.5453);
    float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(12.9898, 78.233))) * 43758.5453);
    float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(12.9898, 78.233))) * 43758.5453);
    float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(12.9898, 78.233))) * 43758.5453);
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void main() {
    vec2 uv = FlutterFragCoord() / uSize;
    
    // Slow, drifting noise
    float t = uTime * 0.05;
    float n1 = noise(uv * 2.5 + vec2(t, t * 0.5));
    float n2 = noise(uv * 3.0 - vec2(t * 0.8, t * 1.2));
    
    // Combine noises for a smoky, swirling effect
    float mist = (n1 + n2) * 0.5;
    
    // Vignette so the edges are darker
    vec2 c = uv - 0.5;
    float vignette = 1.0 - smoothstep(0.3, 0.8, length(c));
    
    // Base dark background + mood color tinted by the mist
    vec3 baseDark = vec3(0.03, 0.03, 0.03);
    vec3 finalColor = mix(baseDark, uMoodColor, mist * uIntensity * vignette);
    
    fragColor = vec4(finalColor, 1.0);
}