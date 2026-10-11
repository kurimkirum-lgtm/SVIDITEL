#version 330 compatibility

/*
  GRIM HORROR — post-processing pass
  Target: Minecraft 1.21.1, Iris / OptiFine shaderpack pipeline.
  Self-contained autonomous effects; custom mod uniforms are not assumed.
*/

uniform sampler2D colortex0;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float nightVision;
uniform float blindness;
uniform int worldTime;
uniform int isEyeInWater;

in vec2 texcoord;

/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 fragColor;

const float HORROR_INTENSITY = 1.00;
const float DARKNESS = 0.22;
const float VIGNETTE_STRENGTH = 0.76;
const float GRAIN_STRENGTH = 0.075;
const float GLITCH_STRENGTH = 0.030;
const float CHROMATIC_STRENGTH = 0.0038;
const float RED_PULSE_STRENGTH = 0.22;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
    vec2 uv = texcoord;
    vec2 resolution = max(vec2(viewWidth, viewHeight), vec2(1.0));
    vec2 px = 1.0 / resolution;
    float t = frameTimeCounter;

    float glitchRoll = step(0.965, hash21(vec2(floor(t * 7.0), 19.7)));
    float band = step(0.76, hash21(vec2(floor(uv.y * 90.0), floor(t * 11.0))));
    float tear = glitchRoll * band * GLITCH_STRENGTH * HORROR_INTENSITY;
    float tearSign = step(0.5, hash21(vec2(floor(t * 13.0), 3.1))) * 2.0 - 1.0;
    uv.x += tear * tearSign;

    vec2 radial = uv - vec2(0.5);
    float aberration = CHROMATIC_STRENGTH * HORROR_INTENSITY;
    float r = texture(colortex0, clamp(uv + radial * aberration, px, 1.0 - px)).r;
    vec4 center = texture(colortex0, clamp(uv, px, 1.0 - px));
    float b = texture(colortex0, clamp(uv - radial * aberration, px, 1.0 - px)).b;
    vec3 color = vec3(r, center.g, b);

    float lum = luma(color);
    color = mix(color, vec3(lum * 0.76, lum * 0.83, lum * 0.91), 0.48 * HORROR_INTENSITY);
    color *= vec3(0.82, 0.88, 1.00);

    float nightFactor = smoothstep(12500.0, 15000.0, float(worldTime))
                      + (1.0 - smoothstep(22500.0, 24000.0, float(worldTime)));
    nightFactor = clamp(nightFactor, 0.0, 1.0);
    color *= 1.0 - DARKNESS * HORROR_INTENSITY * nightFactor;

    float dist = length((uv - 0.5) * vec2(resolution.x / resolution.y, 1.0));
    float breath = 0.035 * sin(t * 1.65) + 0.018 * sin(t * 3.7);
    float vignette = smoothstep(0.28, 0.92 + breath, dist);
    color *= 1.0 - vignette * VIGNETTE_STRENGTH * HORROR_INTENSITY;

    vec2 grainUV = floor(uv * resolution * 0.72) + vec2(floor(t * 24.0), floor(t * 17.0));
    color += (hash21(grainUV) - 0.5) * GRAIN_STRENGTH * HORROR_INTENSITY;

    float pulse = max(0.0, sin(t * 1.8 + noise2(uv * 4.0) * 2.2));
    float edgeWeight = smoothstep(0.18, 0.78, dist);
    color.r += pulse * edgeWeight * RED_PULSE_STRENGTH * HORROR_INTENSITY;
    color.g *= 1.0 - pulse * edgeWeight * 0.09 * HORROR_INTENSITY;

    color = mix(color, vec3(luma(color)) * vec3(0.84, 0.90, 1.0),
                clamp(rainStrength, 0.0, 1.0) * 0.22 * HORROR_INTENSITY);

    color = mix(color, center.rgb, clamp(nightVision, 0.0, 1.0) * 0.78);
    color *= 1.0 - clamp(blindness, 0.0, 1.0) * 0.12;

    if (isEyeInWater == 1) {
        color *= vec3(0.52, 0.72, 0.82);
        color = mix(color, vec3(luma(color) * 0.72), 0.16);
    }

    float scanline = 0.985 + 0.015 * sin(uv.y * resolution.y * 1.35);
    color *= mix(1.0, scanline, 0.40 * HORROR_INTENSITY);

    fragColor = vec4(max(color, vec3(0.0)), center.a);
}
