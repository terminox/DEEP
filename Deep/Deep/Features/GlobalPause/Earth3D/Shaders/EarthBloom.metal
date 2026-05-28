#include <metal_stdlib>
using namespace metal;

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
// Soft luminance threshold: contributes 0 below ~0.62, rises to full at ~0.95.
// We use a perceptually-weighted luminance so the lavender/blush palette's
// actual brightness drives bloom (not raw RGB sum).
fragment float4 earthBloomThresholdFragment(
  FSIn in [[stage_in]],
  texture2d<float> src [[texture(0)]]
) {
  constexpr sampler s(filter::linear, address::clamp_to_edge);
  float2 uv = in.ndc * 0.5 + 0.5;
  uv.y = 1.0 - uv.y;
  float4 c = src.sample(s, uv);
  float luma = dot(c.rgb, float3(0.2126, 0.7152, 0.0722));
  float weight = smoothstep(0.62, 0.95, luma);
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
  texture2d<float> src [[texture(0)]]
) {
  float2 uv = in.ndc * 0.5 + 0.5;
  uv.y = 1.0 - uv.y;
  // Wide blur radius for soft, atmospheric bloom — not punchy gamer bloom.
  float texelSize = 1.0 / float(src.get_width());
  return blurDir(src, uv, float2(texelSize * 3.0, 0));
}

fragment float4 earthBloomBlurVFragment(
  FSIn in [[stage_in]],
  texture2d<float> src [[texture(0)]]
) {
  float2 uv = in.ndc * 0.5 + 0.5;
  uv.y = 1.0 - uv.y;
  float texelSize = 1.0 / float(src.get_height());
  return blurDir(src, uv, float2(0, texelSize * 3.0));
}

// ── Final composite ─────────────────────────────────────────────────────────
//
// Combines: clamped scene + bloom additive + a 1-2px chromatic shift at the
// fresnel rim (driven by the scene's alpha gradient) + low-amplitude blue-noise
// dither to mask 8-bit banding.

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
  texture2d<float> scene [[texture(0)]],
  texture2d<float> bloom [[texture(1)]]
) {
  constexpr sampler s(filter::linear, address::clamp_to_edge);
  float2 uv = in.ndc * 0.5 + 0.5;
  uv.y = 1.0 - uv.y;

  // Chromatic aberration sampled along the radial direction from the screen center.
  float2 center = float2(0.5, 0.5);
  float2 toCenter = uv - center;
  float dist = length(toCenter);
  float2 dir = (dist > 0.0001) ? toCenter / dist : float2(0);
  float caStrength = smoothstep(0.30, 0.50, dist) * 0.0035;

  float4 sBase = scene.sample(s, uv);
  float4 sR = scene.sample(s, uv + dir * caStrength);
  float4 sB = scene.sample(s, uv - dir * caStrength);
  // Split toward lavender ↔ peach at the rim only. Subtle (per DESIGN.md).
  float3 sceneColor = float3(
    mix(sBase.r, sR.r * PEACH_DRIFT.r + sBase.r * (1.0 - PEACH_DRIFT.r), caStrength * 40.0),
    sBase.g,
    mix(sBase.b, sB.b * LAVENDER_DRIFT.b + sBase.b * (1.0 - LAVENDER_DRIFT.b), caStrength * 40.0)
  );
  // Keep alpha from the unshifted sample (preserves the orb silhouette).
  float alpha = sBase.a;

  // Additive bloom — generous radius, modest strength.
  float3 bloomColor = bloom.sample(s, uv).rgb * 0.70;
  // Alpha plumbing: bloom should still contribute outside the silhouette
  // (it's *light spilling into the atmosphere*), so we lift alpha by it.
  alpha = saturate(alpha + dot(bloomColor, float3(0.333)));

  float3 finalColor = sceneColor + bloomColor;

  // Dither to mask 8-bit banding in the lavender → cream gradient.
  float d = (dither13(in.position.xy) - 0.5) * (1.0 / 255.0);
  finalColor += d;

  return float4(finalColor, alpha);
}
