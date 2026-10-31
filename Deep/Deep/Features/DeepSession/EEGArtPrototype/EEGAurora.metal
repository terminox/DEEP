#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// PROTOTYPE — throwaway, DEBUG only in practice (used by `VariantCAurora.swift`).
//
// The night sky of variant C, "Aurora": a starry indigo sky with layered
// aurora curtains whose shape, colour and tempo come from the sitter's EEG.
// Every input arrives already smoothed from Swift, and `phase` is integrated
// there (speed × dt) so a change of tempo never makes the folds lurch.
//
// Inputs, all 0…1 unless noted:
//   time       wall seconds since the view appeared (stars, sparkles, flicker)
//   phase      accumulated fold time (the curtains' own clock)
//   alpha      green curtain strength
//   theta      violet / magenta upper fringe
//   beta       warm pink lower edge, choppier and faster folds
//   gamma      small sparkles in the curtain
//   calm       our α/β index: taller, slower, smoother folds
//   stillness  clearer, steadier stars
//   breath     −1…1, a slow swell of overall brightness paced by heart rate
//   shimmerX   0…1, where a blink's shimmer has travelled across the curtain
//   shimmer    0…1, that shimmer's strength
//   horizon    0…1 of the height, where the mountains begin (curtains sit above)

namespace aurora {
  float hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
  }

  float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
  }

  /// Fractal noise, `octaves` ≤ 5, roughness `gain` (higher = choppier).
  float fbm(float2 p, int octaves, float gain) {
    float value = 0.0;
    float amplitude = 0.5;
    float norm = 0.0;
    for (int i = 0; i < 5; i++) {
      if (i >= octaves) break;
      value += amplitude * noise(p);
      norm += amplitude;
      p = float2(p.x * 1.97 + p.y * 0.23, p.y * 1.93 - p.x * 0.21) + 17.1;
      amplitude *= gain;
    }
    return value / norm;
  }

  /// One star layer: at most one star per grid cell.
  float stars(float2 position, float cell, float density, float time, float twinkle, float sharpness) {
    float2 grid = position / cell;
    float2 id = floor(grid);
    float pick = hash(id + 3.7);
    if (pick > density) return 0.0;
    float2 centre = (id + 0.2 + 0.6 * float2(hash(id + 11.3), hash(id + 27.9))) * cell;
    float d = length(position - centre);
    float size = mix(0.55, 1.5, hash(id + 5.1)) * sharpness;
    float core = exp(-d * d / (size * size));
    float brightness = pow(hash(id + 8.4), 2.6) * 1.3 + 0.08;
    float flicker = 1.0 - twinkle * (0.5 + 0.5 * sin(time * (1.3 + 3.0 * hash(id + 2.2)) + pick * 40.0));
    return core * brightness * flicker;
  }
}

[[ stitchable ]] half4 eegAurora(
  float2 position,
  half4 color,
  float2 size,
  float time,
  float phase,
  float alpha,
  float theta,
  float beta,
  float gamma,
  float calm,
  float stillness,
  float breath,
  float shimmerX,
  float shimmer,
  float horizon
) {
  using namespace aurora;

  // Height-normalised coordinates: y 0 at the top, 1 at the bottom.
  float2 uv = position / size.y;
  float width = size.x / size.y;
  float y = uv.y;

  // MARK: Sky

  float skyT = clamp(y / horizon, 0.0, 1.0);
  float3 zenith = float3(0.008, 0.012, 0.045);
  float3 middle = float3(0.020, 0.032, 0.105);
  float3 low = float3(0.050, 0.075, 0.170);
  float3 sky = mix(zenith, middle, smoothstep(0.0, 0.6, skyT));
  sky = mix(sky, low, smoothstep(0.55, 1.0, skyT));

  // A faint Milky Way drifting diagonally.
  float band = exp(-pow((uv.x * 0.9 + y * 0.55 - 0.42) / 0.12, 2.0));
  float dust = fbm(uv * float2(6.0, 9.0) + 2.0, 3, 0.55);
  sky += float3(0.030, 0.034, 0.060) * band * smoothstep(0.35, 0.8, dust) * (1.0 - skyT * 0.7);

  // Stars: steadier and crisper the stiller the sitter.
  float twinkle = mix(0.75, 0.12, stillness);
  float sharp = mix(1.6, 1.0, stillness);
  float starLight = stars(position, 9.0, 0.30, time, twinkle, sharp) * 0.55
    + stars(position + 31.0, 26.0, 0.45, time * 0.8, twinkle, sharp * 1.25);
  starLight *= mix(0.55, 1.0, stillness) * (1.0 - smoothstep(0.55, 1.0, skyT) * 0.75);

  // MARK: Aurora

  // A busy mind: low calm and high beta together.
  float restless = clamp(0.65 * (1.0 - calm) + 0.6 * beta, 0.0, 1.0);
  float tall = clamp(0.45 * calm + 0.35 * alpha + 0.25 * theta - 0.35 * beta, 0.0, 1.0);
  // Restless: low, short and choppy. Calm: tall curtains in long smooth folds.
  float height = mix(0.06, 0.30, tall);
  float edgeY = horizon - mix(0.065, 0.13, tall);
  float waveFreq = mix(2.2, 6.5, restless);
  float waveAmp = mix(0.028, 0.048, tall);
  float gain = mix(0.30, 0.55, restless);
  int octaves = restless > 0.45 ? 4 : 3;

  float3 green = float3(0.20, 1.00, 0.55);
  float3 teal = float3(0.15, 0.85, 0.80);
  float3 violet = float3(0.55, 0.28, 1.00);
  float3 magenta = float3(0.95, 0.30, 0.85);
  float3 pink = float3(1.00, 0.36, 0.52);

  float greenGain = mix(0.45, 1.45, alpha);
  float flick = restless * restless;

  float3 emission = float3(0.0);
  float3 haze = float3(0.0);

  for (int i = 0; i < 3; i++) {
    float layer = float(i);
    // Layer 0 is the main curtain, low over the hills; 1 and 2 are softer,
    // dimmer echoes higher up and further away.
    float depth = 1.0 - layer * 0.30;
    float lift = layer * mix(0.035, 0.07, tall);
    float2 seed = float2(layer * 7.31, layer * 3.17);
    float x = uv.x + layer * 0.37;
    float clock = phase * (0.30 + 0.07 * layer);

    // The curtain's lower edge, a slow wandering line, and its slope (folds
    // seen edge-on glow brighter).
    float e = 0.004;
    float w0 = fbm(float2(x * waveFreq, clock) + seed, octaves, gain);
    float w1 = fbm(float2((x + e) * waveFreq, clock) + seed, octaves, gain);
    // fbm sits around 0.5 ± 0.2, so ×5 spans roughly ±waveAmp.
    float slope = (w1 - w0) / e * 5.0 * waveAmp;
    // Kept above the hills with a smooth minimum, so the hem never flattens.
    float raw = edgeY - lift + (w0 - 0.5) * 5.0 * waveAmp;
    float floorY = horizon - 0.045;
    float base = -0.012 * log(exp(-raw / 0.012) + exp(-floorY / 0.012));

    float d = base - y; // > 0 above the lower edge

    // Vertical rays that bend with the folds and drift slowly.
    float xw = x + w0 * 0.25;
    float rayFreq = mix(45.0, 80.0, restless);
    float rays = noise(float2(xw * rayFreq, clock * 1.6 + layer * 5.0)) * 0.65
      + noise(float2(xw * rayFreq * 2.3, clock * 2.4 + 9.0)) * 0.35;
    float reach = height * depth * mix(0.45, 1.25, rays);

    // Ray tips break the hem so it never reads as a hard horizon.
    float hemD = d + (noise(float2(xw * 22.0, clock * 1.2 + layer)) - 0.5) * 0.014;
    float lower = smoothstep(-0.006 - 0.005 * beta - layer * 0.022, 0.002, hemD);
    // A bright hem just above the lower edge, fading up into the rays.
    float hem = 0.40 + 0.60 * exp(-max(d, 0.0) / 0.03) * (1.0 - 0.45 * layer);
    float upper = exp(-max(d, 0.0) / reach) * hem;
    float fold = 1.0 + 1.4 * smoothstep(0.25, 1.4, abs(slope));
    float strand = mix(0.55, 1.0, rays);

    // Restless minds flicker; the flicker only scales brightness, never tempo.
    float flicker = 1.0 - flick * 0.45 * noise(float2(x * 6.0 + layer, time * 7.0));

    float intensity = lower * upper * fold * strand * flicker * depth;

    // A blink: a soft shimmer pulse travelling along the curtain.
    float sx = mix(-0.15, width + 0.15, shimmerX);
    float pulse = shimmer * exp(-pow((uv.x - sx) / 0.07, 2.0));
    intensity *= 1.0 + 1.6 * pulse;

    // Colour by height above the edge: green body, violet / magenta tops,
    // a warm pink fringe right at the lower edge when beta is up.
    float t = clamp(max(d, 0.0) / (reach * 1.6), 0.0, 1.0);
    float3 body = mix(green, teal, 0.25 * layer) * greenGain;
    float3 top = mix(violet, magenta, 0.35 + 0.4 * beta);
    float topMix = clamp(smoothstep(0.04, 0.55, t) * (0.15 + 1.0 * theta), 0.0, 1.0);
    // Violet tops hold their light as the curtain fades upward.
    float3 col = mix(body, top * (0.6 + 1.6 * theta), topMix);
    // Beta: a warm pink lower border, like the rose hem of a restless aurora.
    float rose = beta * exp(-max(hemD, 0.0) / (0.02 + 0.02 * beta)) * (1.0 - 0.4 * layer);
    col = mix(col, pink * mix(0.8, 1.3, beta), clamp(rose * 0.9, 0.0, 0.85));
    col = mix(col, float3(0.85, 1.0, 0.95), pulse * 0.35);

    emission += col * intensity;
    // Light bleeding just below the hem.
    emission += col * 0.10 * depth * exp(min(hemD, 0.0) / 0.035) * (1.0 - lower);

    // Light the sky around the curtain.
    float glow = exp(-abs(d - reach * 0.4) / 0.16) * smoothstep(-0.05, 0.03, d);
    haze += mix(teal, violet, theta * 0.6) * glow * depth * (0.25 + 0.75 * alpha);
  }

  // Gamma: tiny sparkles caught in the curtain (jaw clenches flare them).
  float2 sparkCell = floor(position / 6.0);
  float sparkSeed = hash(sparkCell + floor(time * 5.0));
  float sparkGate = step(1.0 - 0.025 * gamma, sparkSeed);
  float2 sparkCentre = (sparkCell + 0.5) * 6.0;
  float sparkCore = exp(-dot(position - sparkCentre, position - sparkCentre) / 1.4);
  float curtainMask = clamp(dot(emission, float3(0.33)) * 1.6, 0.0, 1.0);
  emission += float3(1.0, 0.95, 0.80) * sparkGate * sparkCore * curtainMask * 2.0;

  // Heart rate: the whole aurora breathes, slowly.
  float swell = 1.0 + 0.09 * breath;
  emission *= 0.85 * swell;
  haze *= 0.05 * swell;

  // The aurora's light pooled low over the hills.
  float3 airglow = mix(float3(0.10, 0.55, 0.45), float3(0.35, 0.25, 0.70), theta * 0.5);
  haze += airglow * smoothstep(0.45, 1.0, skyT) * (0.4 + 1.0 * alpha) * 0.10 * swell;

  float3 light = 1.0 - exp(-(emission + haze) * 1.1);
  float3 result = sky + starLight * float3(0.85, 0.88, 1.0) * (1.0 - clamp(dot(light, float3(0.5)), 0.0, 0.7)) + light;

  // Dither against banding in the dark gradient.
  result += (hash(position + fract(time)) - 0.5) / 255.0;

  return half4(half3(clamp(result, 0.0, 1.0)), 1.0);
}
