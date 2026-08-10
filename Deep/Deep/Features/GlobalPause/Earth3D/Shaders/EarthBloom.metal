#include <metal_stdlib>
using namespace metal;

#include "EarthTuningShared.h"

// Bloom post-process chain + final composite for the Earth orb.
//
// Pipeline (driven by EarthRenderer):
//   1. earthBloomThresholdFragment — extract pixels above a soft threshold
//   2. earthBloomBlurHFragment     — separable gaussian, horizontal
//   3. earthBloomBlurVFragment     — separable gaussian, vertical
//   4. earthCompositeFragment      — scene + blurred bloom + rim aberration + dither
//
// All four pipelines share the same fullscreen vertex shader from EarthSurface.metal.

struct FSIn {
  float4 position [[position]];
  float2 ndc;
};

// ── Threshold ──────────────────────────────────────────────────────────────
//
// Soft luminance threshold tuned for Deep's pastel palette. Lavender/blush
// at full saturation have luminance ≈ 0.65–0.75, so the band must catch
// them — otherwise continents render colored but with no glow halo.
fragment float4 earthBloomThresholdFragment(
  FSIn in [[stage_in]],
  constant EarthTuningUniforms& T [[buffer(0)]],
  texture2d<float> src [[texture(0)]]
) {
  constexpr sampler s(filter::linear, address::clamp_to_edge);
  float2 uv = in.ndc * 0.5 + 0.5;
  uv.y = 1.0 - uv.y;
  float4 c = src.sample(s, uv);
  float luma = dot(c.rgb, float3(0.2126, 0.7152, 0.0722));
  float weight = smoothstep(T.bloomA.x, T.bloomA.y, luma);
  return float4(c.rgb * weight, c.a);
}

// ── Separable gaussian blur (9-tap, σ ≈ 4px in source space) ────────────────

constant float BLUR_WEIGHTS[5] = {
  0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216
};

static float4 blurDir(texture2d<float> src, float2 uv, float2 step) {
  constexpr sampler s(filter::linear, address::clamp_to_edge);
  float4 acc = src.sample(s, uv) * BLUR_WEIGHTS[0];
  for (int i = 1; i < 5; ++i) {
    float2 off = step * float(i);
    acc += src.sample(s, uv + off) * BLUR_WEIGHTS[i];
    acc += src.sample(s, uv - off) * BLUR_WEIGHTS[i];
  }
  return acc;
}

fragment float4 earthBloomBlurHFragment(
  FSIn in [[stage_in]],
  constant EarthTuningUniforms& T [[buffer(0)]],
  texture2d<float> src [[texture(0)]]
) {
  float2 uv = in.ndc * 0.5 + 0.5;
  uv.y = 1.0 - uv.y;
  // Wide blur radius for soft, atmospheric bloom — not punchy gamer bloom.
  float texelSize = 1.0 / float(src.get_width());
  return blurDir(src, uv, float2(texelSize * T.bloomA.z, 0));
}

fragment float4 earthBloomBlurVFragment(
  FSIn in [[stage_in]],
  constant EarthTuningUniforms& T [[buffer(0)]],
  texture2d<float> src [[texture(0)]]
) {
  float2 uv = in.ndc * 0.5 + 0.5;
  uv.y = 1.0 - uv.y;
  float texelSize = 1.0 / float(src.get_height());
  return blurDir(src, uv, float2(0, texelSize * T.bloomA.z));
}

// ── Final composite ─────────────────────────────────────────────────────────
//
// Reads HDR scene + HDR bloom (both rgba16Float), accumulates, applies a
// luminance-preserving tonemap to keep palette hue intact, then dithers
// and outputs to the 8-bit drawable.

// Luminance-preserving tonemap: compress only the brightness component, leave
// chroma alone. Without this, channels clip independently and palette colors
// flatten to white at high intensity. After luma compression we soft-desaturate
// any channel that's still over 1.0 — a small palette-color rescue so a
// fully-saturated lavender doesn't lose its blue dominance at the 8-bit
// drawable boundary.
static float3 tonemapPalette(float3 x, float k) {
  float luma = dot(x, float3(0.2126, 0.7152, 0.0722));
  if (luma < 1e-5) return x;
  // k = 1.5 default — keeps mid-range values close to linear; only compresses
  // the really hot HDR pixels (rim + specular + bloom-piled continents).
  float compressed = 1.0 - exp(-luma * k);
  float3 result = x * (compressed / luma);

  // Per-channel safety pull toward white for any over-1 channel.
  float maxC = max(max(result.r, result.g), result.b);
  if (maxC > 1.0) {
    float t = clamp((maxC - 1.0) * 0.8, 0.0, 1.0);
    result = mix(result, float3(1.0), t * 0.35);
    result = min(result, float3(1.0));
  }
  return result;
}

constant float3 LAVENDER_DRIFT = float3(0.722, 0.655, 0.910);
constant float3 PEACH_DRIFT    = float3(0.961, 0.851, 0.769);

static float dither13(float2 p) {
  // Tiny hash, in [0, 1).
  float3 q = fract(float3(p.x * 0.1031, p.y * 0.103, (p.x + p.y) * 0.0973));
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

fragment float4 earthCompositeFragment(
  FSIn in [[stage_in]],
  constant EarthTuningUniforms& T [[buffer(0)]],
  texture2d<float> scene [[texture(0)]],
  texture2d<float> bloom [[texture(1)]]
) {
  constexpr sampler s(filter::linear, address::clamp_to_edge);
  float2 uv = in.ndc * 0.5 + 0.5;
  uv.y = 1.0 - uv.y;

  // Direct sample — no chromatic aberration. The previous CA pass was
  // asymmetric: it dimmed R (sampled outward, often into transparent),
  // left G untouched, and barely shifted B. Net result at the rim was
  // G dominating → visible green tint. Cleaner without it; the bloom
  // halo already provides the soft "glass edge" cue.
  float4 sBase = scene.sample(s, uv);
  float3 sceneColor = sBase.rgb;
  float alpha = sBase.a;

  // Additive HDR bloom — generous radius, modest strength.
  // Tuned so the bloom *halo* around continents is clearly visible while the
  // bloom *core* (where it overlaps the lit continent itself) doesn't push
  // chroma toward white through the tonemap.
  float3 bloomColor = bloom.sample(s, uv).rgb * T.bloomA.w;
  // Alpha plumbing: bloom should still contribute outside the silhouette
  // (it's *light spilling into the atmosphere*), so we lift alpha by it.
  // Use the tonemapped bloom luminance so alpha tracks what's actually visible.
  float bloomLuma = dot(bloomColor, float3(0.2126, 0.7152, 0.0722));
  alpha = saturate(alpha + (1.0 - exp(-bloomLuma)) * T.bloomB.y);

  float3 hdrSum = sceneColor + bloomColor;
  float3 finalColor = tonemapPalette(hdrSum, T.bloomB.x);

  // Dither to mask 8-bit banding in the lavender → cream gradient.
  float d = (dither13(in.position.xy) - 0.5) * (1.0 / 255.0);
  finalColor += d;

  return float4(finalColor, alpha);
}
