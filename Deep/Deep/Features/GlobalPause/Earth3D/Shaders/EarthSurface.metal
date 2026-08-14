#include <metal_stdlib>
using namespace metal;

#include "EarthTuningShared.h"

// ───────────────────────────────────────────────────────────────────────────
// Earth surface fragment shader — crystal-glass orb.
//
// Single fullscreen triangle, sphere SDF raymarch, two hits per ray (front
// surface + refracted back-side exit), so the orb reads as a *solid* piece
// of glass with continents suspended inside, not a hazy holographic shell.
//
// Glass ingredients (no per-frame uniforms beyond what already existed):
//   1. Crystal-clear body — ocean area is almost fully transparent.
//   2. Sharp specular highlight from sun direction (Phong, soft falloff).
//   3. Bright thin Fresnel rim with a faint warm/cool dispersion split.
//   4. Refracted back-side bleed — front face transmits a faint ghost of
//      the far hemisphere's continents, the way a real glass marble does.
//   5. Continents on the front face still carry iridescence + country glow.
//   6. Breath shimmer (subtle FBM iridescent drift), kept low.
//
// All palette constants come from Deep/Theme/DeepTheme.swift — the DESIGN.md
// palette. Pastel only; no high-saturation values anywhere.
// ───────────────────────────────────────────────────────────────────────────

// Sorted into three disjoint style ranges — classic `[0, classicCount)`,
// orb `[classicCount, classicCount+orbCount)`, shell `[…, glowCount)` — so
// each accumulator loops only its own range and no per-source style branch
// runs. Channel meanings per range (mirrors EarthRendererTypes.swift):
//   classic: pos.w = intensity, x = angular radius (rad), y = whiteness 0..1
//            (join sparks push toward moon-cream), z = volumetric column
//            height multiplier, w = 0
//   orb:     pos.w = intensity, x = σ (world units), y = whiteness, w = 1
//   shell:   pos.w = shell intensity, x = shell radius R (world units),
//            y = whiteness, z = shell thickness (world units), w = 2
struct GlowSourceGPU {
  float4 positionAndIntensity;
  float4 radiusPacked;
};

struct EarthUniforms {
  float4x4 inverseViewProj;
  float4   cameraPosition;
  float4x4 sphereOrientation;
  float4   sunDirection;
  float4   params;          // x=time, y=breathPhase 0..1, z=classic glow count,
                            // w=total glow count
  float4   sphereData;      // xyz=center, w=radius
  float4   atmosphereData;  // x=atmoRadius, y=atmoStrength, z=orb glow count,
                            // w=world units per scene pixel (shell AA floor)
};

// ── Palette (Deep design system) ────────────────────────────────────────────
constant float3 LAVENDER_MIST = float3(0.722, 0.655, 0.910); // #B8A7E8
constant float3 SOFT_LILAC    = float3(0.831, 0.773, 0.941); // #D4C5F0
constant float3 BLUSH_POWDER  = float3(0.957, 0.788, 0.831); // #F4C9D4
constant float3 SKY_WASH      = float3(0.773, 0.847, 0.941); // #C5D8F0
constant float3 PEACH_CLOUD   = float3(0.961, 0.851, 0.769); // #F5D9C4
constant float3 MOON_CREAM    = float3(0.984, 0.969, 1.000); // #FBF7FF
constant float3 DEEP_PLUM     = float3(0.239, 0.212, 0.329); // #3D3654

// ── Vertex ──────────────────────────────────────────────────────────────────

struct FSIn {
  float4 position [[position]];
  float2 ndc;
};

vertex FSIn earthFullscreenVertex(uint vid [[vertex_id]]) {
  // Oversized triangle covering NDC [-1, 1]² with a single primitive.
  float2 positions[3] = {
    float2(-1.0, -3.0),
    float2(-1.0,  1.0),
    float2( 3.0,  1.0)
  };
  FSIn o;
  o.position = float4(positions[vid], 0, 1);
  o.ndc = positions[vid];
  return o;
}

// ── Hash + tiny FBM (for breath shimmer only) ───────────────────────────────

static float hash13(float3 p) {
  p = fract(p * 0.1031);
  p += dot(p, p.yzx + 33.33);
  return fract((p.x + p.y) * p.z);
}

static float valueNoise3(float3 p) {
  float3 i = floor(p);
  float3 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float n000 = hash13(i + float3(0,0,0));
  float n100 = hash13(i + float3(1,0,0));
  float n010 = hash13(i + float3(0,1,0));
  float n110 = hash13(i + float3(1,1,0));
  float n001 = hash13(i + float3(0,0,1));
  float n101 = hash13(i + float3(1,0,1));
  float n011 = hash13(i + float3(0,1,1));
  float n111 = hash13(i + float3(1,1,1));
  float nx00 = mix(n000, n100, f.x);
  float nx10 = mix(n010, n110, f.x);
  float nx01 = mix(n001, n101, f.x);
  float nx11 = mix(n011, n111, f.x);
  return mix(mix(nx00, nx10, f.y), mix(nx01, nx11, f.y), f.z);
}

static float fbm3(float3 p, int octaves) {
  float sum = 0.0;
  float amp = 0.5;
  float freq = 1.0;
  for (int i = 0; i < octaves; ++i) {
    sum += amp * valueNoise3(p * freq);
    freq *= 2.0;
    amp *= 0.5;
  }
  return sum;
}

// ── Sphere intersection ─────────────────────────────────────────────────────

struct Hit {
  bool hit;
  float t;
  float3 point;
  float3 normal;
};

static Hit raySphere(float3 ro, float3 rd, float3 center, float radius) {
  Hit h;
  h.hit = false;
  float3 oc = ro - center;
  float b = dot(rd, oc);
  float c = dot(oc, oc) - radius * radius;
  float disc = b * b - c;
  if (disc < 0) return h;
  float t = -b - sqrt(disc);
  if (t < 0) return h;
  h.hit = true;
  h.t = t;
  h.point = ro + rd * t;
  h.normal = normalize(h.point - center);
  return h;
}

// Both roots of the ray/sphere intersection — the volumetric shell march
// needs the full chord (`raySphere` discards the far root and misses on it).
struct RangeHit {
  bool hit;
  float t0;   // near root (may be < 0 if the origin sits inside)
  float t1;   // far root
};

static RangeHit raySphereRange(float3 ro, float3 rd, float3 center, float radius) {
  RangeHit h;
  h.hit = false;
  float3 oc = ro - center;
  float b = dot(rd, oc);
  float c = dot(oc, oc) - radius * radius;
  float disc = b * b - c;
  if (disc < 0.0) return h;
  float s = sqrt(disc);
  h.t0 = -b - s;
  h.t1 = -b + s;
  if (h.t1 < 0.0) return h;   // sphere entirely behind the ray
  h.hit = true;
  return h;
}

// ── Spherical UV ────────────────────────────────────────────────────────────
//
// Equirectangular convention: U=0 at left (lon -180°), U=0.5 at lon 0°
// (Greenwich at horizontal center), V=0 at top (north pole), V=1 at south.
// Texture origin is top-left, matching MTKTextureLoader's default.

static float2 sphericalUV(float3 p) {
  return float2(atan2(p.x, p.z) / (2.0 * M_PI_F) + 0.5,
                0.5 - asin(p.y) / M_PI_F);
}

// ── Iridescent palette walk ─────────────────────────────────────────────────
//
// One scalar t ∈ [0, 1] driven by viewing-angle Fresnel walks the five-color
// palette: SKY_WASH → LAVENDER → LILAC → BLUSH → PEACH. Stays inside the
// Deep design system, never crosses into cyan/magenta.

static float3 iridescent(float t) {
  float3 c;
  if (t < 0.25) {
    c = mix(SKY_WASH, LAVENDER_MIST, smoothstep(0.0, 0.25, t));
  } else if (t < 0.5) {
    c = mix(LAVENDER_MIST, SOFT_LILAC, smoothstep(0.25, 0.5, t));
  } else if (t < 0.75) {
    c = mix(SOFT_LILAC, BLUSH_POWDER, smoothstep(0.5, 0.75, t));
  } else {
    c = mix(BLUSH_POWDER, PEACH_CLOUD, smoothstep(0.75, 1.0, t));
  }
  return c;
}

// ── Glow palette walk ───────────────────────────────────────────────────────
//
// Shared by the surface glow and the volumetric shell: lilac → blush → peach
// with intensity, the whiteness channel warming toward moon-cream — capped at
// 0.55 so spark peaks read as candle-light, never raw white under bloom.

static float3 glowPalette(float v, float white) {
  float3 c = mix(SOFT_LILAC, BLUSH_POWDER, v);
  c = mix(c, PEACH_CLOUD, smoothstep(0.55, 0.95, v));
  return mix(c, MOON_CREAM, min(white, 0.55));
}

// ── Glow accumulator ────────────────────────────────────────────────────────
//
// Two-term profile per source: the original gaussian core plus a quarter-weight
// halo skirt at 3× the radius. Tight point sources (participant cities,
// ~0.03 rad) read as candle-points with a soft seat instead of hard dots;
// country blobs get gentler coastlines of light from the same math.
//
// `white` carries the join-spark whiteness channel (radiusPacked.y): each
// source's contribution weighted by its whiteness, clamped 0..1 — used to
// momentarily warm the glow color toward moon-cream at a fresh join.
//
// The loop runs the classic range plus the orb range: orb sources keep a
// dimmed surface gaussian (`seatWeight`) so the land under a floating light
// ball still catches its glow. For orbs, radiusPacked.x is a world-unit σ,
// which equals angular σ to first order on the unit sphere — close enough
// for a seat. Shell sources are excluded entirely by the caller's `count`
// (their radiusPacked.x is a shell radius, not an angular radius).

struct GlowAccum {
  float glow;
  float white;
};

static GlowAccum accumulateGlow(float3 surfaceNormalLocal,
                                constant GlowSourceGPU* sources,
                                int classicCount,
                                int count,
                                float seatWeight,
                                float haloWeight,
                                float exposure) {
  float total = 0.0;
  float whiteTotal = 0.0;
  for (int i = 0; i < count; ++i) {
    float3 p = sources[i].positionAndIntensity.xyz;
    float intensity = sources[i].positionAndIntensity.w;
    float angularRadius = max(sources[i].radiusPacked.x, 0.01);
    float whiteness = sources[i].radiusPacked.y;
    float cosAngle = clamp(dot(surfaceNormalLocal, p), -1.0, 1.0);
    float angle = acos(cosAngle);
    float x = angle / angularRadius;
    if (x > 7.5) continue;                        // halo term reaches ~3× radius
    float core = exp(-x * x * 0.5);
    float halo = haloWeight * exp(-x * x * 0.5 / 9.0);  // σ = 3r skirt
    float f = (core + halo) * intensity;
    if (i >= classicCount) f *= seatWeight;       // orb range: residual seat only
    total += f;
    whiteTotal += f * whiteness;
  }
  GlowAccum a;
  a.glow = 1.0 - exp(-total * exposure);
  a.white = clamp(whiteTotal, 0.0, 1.0);
  return a;
}

// ── Volumetric glow shell ───────────────────────────────────────────────────
//
// Fixed-count midpoint march through the shell between the sphere surface and
// the atmosphere radius. Each source contributes a column of light: the
// surface gaussian (core only — no halo skirt), widened with height so the
// column flares into a dome, decaying exponentially with height, and faded to
// zero at the shell top so the breathing radius never clips a hard edge.
// Loop order is source-major so a cheap cone test rejects far-away sources
// before any sampling happens.
//
// Six midpoint samples are enough: the density field is a smooth gaussian ×
// exponential with no texture detail, so banding cannot occur even on the
// longest limb-tangent chord.

#define VOL_SAMPLES 6

struct VolAccum {
  float glow;
  float white;
};

static VolAccum volumetricShell(float3 ro, float3 rd,
                                float t0, float t1,
                                float3 center, float radius, float atmoR,
                                float3x3 Rt,
                                constant GlowSourceGPU* sources, int count,
                                constant EarthTuningUniforms& T) {
  VolAccum a;
  a.glow = 0.0;
  a.white = 0.0;
  float volIntensity = T.lit.z;
  if (volIntensity <= 0.001 || count == 0 || t1 <= t0) return a;

  float gap = max(atmoR - radius, 1e-4);
  float dt = (t1 - t0) / float(VOL_SAMPLES);
  float w = dt / gap;                    // path-length normalization
  float scaleH = max(T.lit.w, 0.02);     // volHeight
  float3 midLocal = Rt * normalize(ro + rd * (0.5 * (t0 + t1)) - center);

  float total = 0.0;
  float whiteTotal = 0.0;
  for (int i = 0; i < count; ++i) {
    float3 p = sources[i].positionAndIntensity.xyz;
    float intensity = sources[i].positionAndIntensity.w;
    float srcRadius = max(sources[i].radiusPacked.x, 0.01);
    float whiteness = sources[i].radiusPacked.y;
    // Floored so a zero-packed buffer (stale caller) degrades to short
    // columns instead of dividing the height falloff toward nothing.
    float heightMul = max(sources[i].radiusPacked.z, 0.2);

    // Cone rejection: the widest σ is srcRadius·(1+volSoftness), and nothing
    // survives past ~4σ. The sampled segment sweeps at most about one
    // shell-gap of arc — folded into the margin so limb chords don't reject
    // a source they'd graze.
    float margin = srcRadius * (1.0 + T.volumetric.x) * 4.0 + gap * 1.2;
    if (acos(clamp(dot(midLocal, p), -1.0, 1.0)) > margin) continue;

    float srcTotal = 0.0;
    for (int s = 0; s < VOL_SAMPLES; ++s) {
      float t = t0 + (float(s) + 0.5) * dt;
      float3 q = ro + rd * t;
      float r = length(q - center);
      float h = clamp((r - radius) / gap, 0.0, 1.0);
      float3 dirLocal = Rt * ((q - center) / r);
      float angle = acos(clamp(dot(dirLocal, p), -1.0, 1.0));
      float sigma = srcRadius * (1.0 + T.volumetric.x * h);  // dome flare upward
      float x = angle / sigma;
      if (x > 4.0) continue;
      float column = exp(-x * x * 0.5);
      float heightFall = exp(-h / (scaleH * heightMul));
      float topFade = 1.0 - smoothstep(0.85, 1.0, h);        // soft shell top
      srcTotal += column * heightFall * topFade;
    }
    float f = srcTotal * w * intensity;
    total += f;
    whiteTotal += f * whiteness;
  }
  a.glow = 1.0 - exp(-total * volIntensity);   // same compression family as the surface glow
  a.white = clamp(whiteTotal, 0.0, 1.0);
  return a;
}

// ── Volumetric light orbs + expanding shells (3D glow styles) ───────────────
//
// Both effects are closed-form line integrals — no marching. They run in the
// sphere's local frame with the ray origin REBASED to its closest approach to
// the globe center: unrebased, b² = |u|² − tc² cancels two values near 72
// (camera distance²) and the ~3e-5 absolute error is a visible fraction of a
// shell's thickness. After rebasing |u|² ≲ 7 and the error is harmless.
// Nothing straddles the camera (distance 8.5, light volumes ≤ ~1.55), so the
// t > 0 restriction is dropped entirely — after rebasing, tc < 0 is
// legitimate for near-hemisphere sources and a step(0, t) guard would delete
// them. tMax is a finite sentinel (1e6) on miss rays, never INFINITY.

// Peak-normalised line integral of exp(−|p−c|²/2σ²) along ro + t·rd over
// t ∈ (−∞, tMax]. Returns x = core (σ), y = halo (3σ), each already
// occlusion-clipped — a centred, unoccluded ray returns (1, 1) for every σ,
// so intensity means peak brightness and σ means size (orthogonal dials).
// MSL has no erf; Φ ≈ smoothstep(−2, 2, ·), max abs error 0.029 — invisible
// through the bloom chain, and exactly 0/1 beyond ±2σ so early-outs stay
// exact. The halo clips with its own σ or the 3σ skirt would be cut with a
// 1σ terminator and read as a hard edge over the limb.
static float2 orbCoreHalo(float3 ro, float3 rd, float3 c, float sigma, float tMax) {
  float3 u  = c - ro;
  float  tc = dot(u, rd);
  float  b2 = max(dot(u, u) - tc * tc, 0.0);      // max() guards float cancellation
  float  s2 = sigma * sigma;
  if (b2 > 56.25 * s2) return float2(0.0);        // 7.5σ, matches accumulateGlow reach
  float  g = 0.5 * b2 / s2;
  float  d = (tMax - tc) / sigma;
  return float2(exp(-g)             * smoothstep(-2.0, 2.0, d),
                exp(-g * (1.0/9.0)) * smoothstep(-6.0, 6.0, d));
}

// Peak-normalised line integral of exp(−|p−c|²/2σ²) restricted to the
// half-space dot(p − c, n) ≥ 0 (n = outward surface normal at the seat),
// over t ∈ (−∞, tMax] — a dome of light resting on the crust. The plane is
// linear along the ray (A + t·B), so the truncation stays closed-form:
// orbCoreHalo's single Φ occlusion factor becomes a Φ difference over
// [tLo, tHi] = half-space ∩ (−∞, tMax]. The ×2 restores "intensity = peak
// brightness seen top-down" (a centred above-plane ray integrates half the
// gaussian); seat-skimming full-chord rays legitimately reach 2 — dome limb
// brightening, compressed downstream by 1 − exp. The halo clips with the
// same plane at its own 3σ edges, matching orbCoreHalo's terminator softness.
static float2 domeCoreHalo(float3 ro, float3 rd, float3 c, float3 n,
                           float sigma, float tMax) {
  float3 u  = c - ro;
  float  tc = dot(u, rd);
  float  b2 = max(dot(u, u) - tc * tc, 0.0);      // max() guards float cancellation
  float  s2 = sigma * sigma;
  if (b2 > 56.25 * s2) return float2(0.0);        // 7.5σ, matches orbCoreHalo
  float  g = 0.5 * b2 / s2;
  float  A = -dot(u, n);                          // dot(ro − c, n)
  float  B = dot(rd, n);
  // Sign-preserved floor keeps tPlane finite; Φ saturation then resolves the
  // ray-parallel-to-plane case (all-above → full span, all-below → empty).
  float  Bs = (B >= 0.0) ? max(B, 1e-4) : min(B, -1e-4);
  float  tPlane = -A / Bs;
  float  tLo = (B >= 0.0) ? tPlane : -1e6;
  float  tHi = (B >= 0.0) ? tMax   : min(tPlane, tMax);
  float  dHi = (tHi - tc) / sigma;
  float  dLo = (tLo - tc) / sigma;
  float  core = max(smoothstep(-2.0, 2.0, dHi) - smoothstep(-2.0, 2.0, dLo), 0.0);
  float  halo = max(smoothstep(-6.0, 6.0, dHi) - smoothstep(-6.0, 6.0, dLo), 0.0);
  return 2.0 * float2(exp(-g)             * core,
                      exp(-g * (1.0/9.0)) * halo);
}

// Line integral of a thin spherical shell ρ(p) = exp(−(|p−c|−R)²/2w²),
// normalised so an unoccluded face-on ray (b = 0) returns 1.0. Two-crossing
// model: the ray crosses |p−c| = R at t = tc ± q with |cosθ| = q/R at both
// crossings; each contributes w√(2π)/cosθ — the 1/cosθ IS the thin-shell
// limb brightening, which on screen is the bright expanding ring with correct
// perspective. The graze clamp and exp outer skirt are numerically fitted
// against brute-force integration (L∞ ≈ 11% of ring peak, ring position
// exact); without the skirt the model is discontinuous at b = R and prints a
// hard outer edge. A crossing behind tMax is invisible — that single test
// covers both the far hemisphere hiding behind the planet and the buried
// half of a surface-seated shell, softened over the shell's longitudinal
// extent (w/cosθ) so the terminator isn't a hard line.
static float shellIntegral(float3 ro, float3 rd, float3 c,
                           float R, float w, float tMax) {
  float3 u  = c - ro;
  float  tc = dot(u, rd);
  float  b2 = max(dot(u, u) - tc * tc, 0.0);
  float  rOut = R + 3.0 * w;
  if (b2 > rOut * rOut) return 0.0;               // no crossing, no tail
  float  q = sqrt(max(R * R - b2, 0.0));          // = R·cosθ (0 outside the shell)
  if (tc - q > tMax) return 0.0;                  // whole shell behind the globe
  float  Rs     = max(R, 4.0 * w);                // ⇒ cosMin ≤ 0.75
  float  cosMin = 1.50 * sqrt(w / Rs);            // graze clamp ⇒ 1/cosC ≤ 4.8
  float  cosC   = max(q / max(R, 1e-4), cosMin);
  float  path   = 1.0 / cosC;
  float  sw = max(w * path, 1e-5);                // smoothstep(a, a, ·) is NaN
  float  v0 = smoothstep(-sw, sw, tMax - (tc - q));   // near crossing
  float  v1 = smoothstep(-sw, sw, tMax - (tc + q));   // far crossing
  float  dOut = max(sqrt(b2) - R, 0.0) / (0.7 * w);
  return 0.5 * path * (v0 + v1) * exp(-0.5 * dOut * dOut);
}

struct LightVolumeAccum {
  float orbDensity;    // Σ (core + haloWeight·halo)·I — compressed by caller
  float orbHot;        // Σ core²·I — uncompressed HDR spike, bloom driver
  float orbWhite;      // Σ f·whiteness (normalise by orbDensity for the mean)
  float shellDensity;  // Σ shellIntegral·I
  float shellWhite;
};

// Sweeps the orb and shell ranges of the source buffer. Expects the rebased
// local-frame ray (see the section comment above).
static LightVolumeAccum accumulateLightVolumes(float3 ro, float3 rd, float tMax,
                                               float radius,
                                               constant GlowSourceGPU* sources,
                                               int classicCount, int orbCount,
                                               int totalCount,
                                               float worldPerPixel,
                                               constant EarthTuningUniforms& T) {
  LightVolumeAccum a;
  a.orbDensity = 0.0;
  a.orbHot = 0.0;
  a.orbWhite = 0.0;
  a.shellDensity = 0.0;
  a.shellWhite = 0.0;

  int orbEnd = classicCount + orbCount;
  for (int i = classicCount; i < orbEnd; ++i) {
    float3 p = sources[i].positionAndIntensity.xyz;
    float intensity = sources[i].positionAndIntensity.w;
    float whiteness = sources[i].radiusPacked.y;
    float sigma = max(sources[i].radiusPacked.x * T.orbShape.x, 1e-3);
    // Per-source style mode rides radiusPacked.z (free in the orb range —
    // volumetricShell reads it only for classic sources): 0 = elevated full
    // orb (bit-identical legacy path), 1 = surface dome (half-space clipped),
    // 2 = buried sphere (the planet body clips it via tMax alone). Branching
    // on a source field is wavefront-uniform — every fragment loops the same
    // sources — so it costs nothing measurable.
    float mode = sources[i].radiusPacked.z;
    // Seat elevation rides σ (bigger ball sits prouder) but stays clamped so
    // tuning extremes can't sink the ball or float it visibly off the crust.
    // Dome and buried seat their gaussian centre exactly on the surface.
    float elev = (mode < 0.5) ? clamp(T.orbTint.w * sigma, 0.015, 0.05) : 0.0;
    float3 c = p * (radius + elev);
    float2 ch = (mode > 0.5 && mode < 1.5)
      ? domeCoreHalo(ro, rd, c, p, sigma, tMax)
      : orbCoreHalo(ro, rd, c, sigma, tMax);
    float f = (ch.x + T.orbTint.z * ch.y) * intensity;
    a.orbDensity += f;
    // core² is a gaussian of σ/√2 — a compact spike that exists only within
    // ~1σ, pushed over 1.0 by the hot gain so bloom ignites the center.
    a.orbHot += ch.x * ch.x * intensity;
    a.orbWhite += f * min(whiteness + T.orbTint.x * ch.x, 1.0);
  }

  for (int i = orbEnd; i < totalCount; ++i) {
    float3 p = sources[i].positionAndIntensity.xyz;
    float intensity = sources[i].positionAndIntensity.w;
    float whiteness = sources[i].radiusPacked.y;
    float R = sources[i].radiusPacked.x;
    // Thickness floors at ~1.5 scene pixels so the ring never aliases on
    // small drawables (the feed card renders the orb ~600 px tall).
    float w = max(sources[i].radiusPacked.z, 1.5 * worldPerPixel);
    float3 c = p * radius;
    float f = shellIntegral(ro, rd, c, R, w, tMax) * intensity;
    a.shellDensity += f;
    a.shellWhite += f * whiteness;
  }
  return a;
}

// ── Main fragment ───────────────────────────────────────────────────────────

fragment float4 earthSurfaceFragment(
  FSIn in [[stage_in]],
  constant EarthUniforms& U [[buffer(0)]],
  constant GlowSourceGPU* glowSources [[buffer(1)]],
  constant EarthTuningUniforms& T [[buffer(2)]],
  texture2d<float> continentTex [[texture(0)]]
) {
  // Longitude (S) wraps — 0° and 360° are the same meridian. Latitude (T)
  // clamps — the poles aren't connected. Without repeat on S, sampling at
  // the dateline edge clamps to the wrong neighbor and prints a seam.
  constexpr sampler texSampler(filter::linear,
                               mip_filter::linear,
                               s_address::repeat,
                               t_address::clamp_to_edge);

  // Reconstruct world-space ray from clip-space NDC.
  float4 nearH = U.inverseViewProj * float4(in.ndc, -1.0, 1.0);
  float4 farH  = U.inverseViewProj * float4(in.ndc,  1.0, 1.0);
  float3 near = nearH.xyz / nearH.w;
  float3 far  = farH.xyz  / farH.w;
  float3 rayOrigin = near;
  float3 rayDir = normalize(far - near);

  float3 sphereCenter = U.sphereData.xyz;
  float baseRadius = U.sphereData.w;
  float atmoRadius = U.atmosphereData.x;
  float atmoStrength = U.atmosphereData.y;
  float time = U.params.x;
  float breath = U.params.y;
  int glowCount = int(U.params.w);

  // Whole-orb breath.
  float breathScale = 1.0 + T.haze.z * breath;
  float radius = baseRadius * breathScale;

  // Local frame so continents stay anchored to the rotating sphere. Built
  // before the miss/hit split because the volumetric shell march needs it on
  // both branches, not just the surface shading.
  float3x3 R = float3x3(
    U.sphereOrientation[0].xyz,
    U.sphereOrientation[1].xyz,
    U.sphereOrientation[2].xyz
  );
  float3x3 Rt = transpose(R);

  RangeHit atmoRange = raySphereRange(rayOrigin, rayDir, sphereCenter,
                                      atmoRadius * breathScale);
  Hit hit = raySphere(rayOrigin, rayDir, sphereCenter, radius);

  // ── 3D light volumes (orbs + shells), computed before the miss/hit split ──
  // A shell expands to ~1.4× the sphere radius — far past the 1.06 atmosphere
  // — so these must not live behind the atmosphere early-out below. Local
  // frame, ray origin rebased to closest approach (see the section comment at
  // orbCoreHalo). Classic-only frames never enter the accumulator: both
  // ranges are empty, coverage stays exactly 0, and every addition below is
  // + 0.0 — bit-identical to the pre-3D output.
  int classicCount = int(U.params.z);
  int orbCount = int(U.atmosphereData.z);
  int surfaceCount = min(classicCount + orbCount, glowCount);

  LightVolumeAccum lv;
  lv.orbDensity = 0.0;
  lv.orbHot = 0.0;
  lv.orbWhite = 0.0;
  lv.shellDensity = 0.0;
  lv.shellWhite = 0.0;
  if (glowCount > classicCount) {
    float3 roL = Rt * (rayOrigin - sphereCenter);
    float3 rdL = Rt * rayDir;
    float tS = -dot(roL, rdL);
    roL += rdL * tS;
    float tMaxL = hit.hit ? (hit.t - tS) : 1e6;
    lv = accumulateLightVolumes(roL, rdL, tMaxL, radius, glowSources,
                                classicCount, orbCount, glowCount,
                                U.atmosphereData.w, T);
  }
  float orbCov = 1.0 - exp(-lv.orbDensity * T.orbShape.y);
  float shellCov = 1.0 - exp(-lv.shellDensity * T.burstShape.x);
  float3 lvEmissive = float3(0.0);
  float lvAlpha = 0.0;
  if (orbCov + shellCov > 5e-4) {
    // Whiteness as a density-weighted mean, not the raw clamped sum the
    // surface accumulators use — more correct when several sources overlap.
    float3 orbCol = glowPalette(orbCov,
                                clamp(lv.orbWhite / max(lv.orbDensity, 1e-4), 0.0, 1.0));
    float3 shellCol = glowPalette(shellCov,
                                  clamp(lv.shellWhite / max(lv.shellDensity, 1e-4), 0.0, 1.0));
    // Hot terms are uncompressed HDR by design (bloom drivers) and must not
    // feed alpha — bloom's own alpha lift handles their spill.
    lvEmissive = orbCol * orbCov * T.orbShape.z
               + mix(orbCol, MOON_CREAM, 0.6) * lv.orbHot * T.orbShape.w
               + shellCol * shellCov * T.burstShape.y
               + mix(shellCol, MOON_CREAM, 0.5) * lv.shellDensity * T.burstShape.z;
    lvAlpha = orbCov * T.orbTint.y + shellCov * T.burstShape.w;
  }

  if (!hit.hit) {
    // Atmosphere haze + volumetric glow domes beyond the orb silhouette.
    // Rays that miss even the atmosphere can still carry an orb skirt or an
    // expanding shell — they composite alone.
    if (!atmoRange.hit) {
      if (orbCov + shellCov <= 5e-4) return float4(0, 0, 0, 0);
      return float4(lvEmissive, saturate(lvAlpha));
    }
    float3 n = normalize(rayOrigin + rayDir * atmoRange.t0 - sphereCenter);
    float density = pow(1.0 - abs(dot(n, -rayDir)), T.haze.y);
    float lat = n.y;
    float3 tint = mix(SOFT_LILAC, BLUSH_POWDER, smoothstep(-0.6, 0.6, -lat));
    tint = mix(tint, LAVENDER_MIST, 0.4);
    float a = density * atmoStrength * T.haze.x;

    // Glow columns rising past the silhouette — the core 3D read of the
    // effect; without this the surface glow dies exactly at the limb.
    // Classic range only: orbs and shells replace the column, not stack on it.
    VolAccum vol = volumetricShell(rayOrigin, rayDir,
                                   max(atmoRange.t0, 0.0), atmoRange.t1,
                                   sphereCenter, radius, atmoRadius * breathScale,
                                   Rt, glowSources, classicCount, T);
    float3 volColor = mix(SOFT_LILAC, glowPalette(vol.glow, vol.white), T.volumetric.z);
    float outA = saturate(a + vol.glow * T.volumetric.y + lvAlpha);
    return float4(tint * a + volColor * vol.glow + lvEmissive, outA);
  }

  float3 worldNormal = hit.normal;
  float3 localNormal = Rt * worldNormal;

  // ── Continents from the bundled texture ───────────────────────────────────
  // Source polarity: black=land, white=ocean. Invert for our continent value.
  float2 uv = sphericalUV(localNormal);

  // Explicit UV gradients computed from the *smooth* localNormal (no atan2
  // discontinuity) so the dateline seam doesn't trigger huge derivatives →
  // wrong mip level → visible vertical line at longitude ±180°.
  float3 dNdx = dfdx(localNormal);
  float3 dNdy = dfdy(localNormal);
  float xz_sq = max(localNormal.x * localNormal.x + localNormal.z * localNormal.z, 1e-5);
  float3 du_dN = float3(localNormal.z, 0.0, -localNormal.x) / (2.0 * M_PI_F * xz_sq);
  float y_arg = max(1.0 - localNormal.y * localNormal.y, 1e-5);
  float3 dv_dN = float3(0.0, -1.0 / (M_PI_F * sqrt(y_arg)), 0.0);
  float2 dUVdx = float2(dot(du_dN, dNdx), dot(dv_dN, dNdx));
  float2 dUVdy = float2(dot(du_dN, dNdy), dot(dv_dN, dNdy));

  float specularSample = continentTex.sample(texSampler, uv,
                                              gradient2d(dUVdx, dUVdy)).r;
  float landRaw = 1.0 - specularSample;
  // Soft threshold cleans up JPG artifacts + ignores the fine river/inland
  // detail (which would look like noise on a holographic orb at this scale).
  float continent = smoothstep(T.continentBand.x, T.continentBand.y, landRaw);
  // A second, wider band keeps the soft "halo" around coasts so they don't
  // read as paper cutouts — gives a faint glow falloff at every coastline.
  float coastHalo = smoothstep(T.coastBand.x, T.coastBand.y, landRaw) - continent;

  // ── Iridescent palette walk ───────────────────────────────────────────────
  //
  // Continents use a *latitude-anchored* pastel gradient (matches the
  // reference): SKY/LAVENDER near the north pole → SOFT_LILAC mid-latitudes →
  // BLUSH → PEACH toward the south. Anchored to localNormal.y so the color
  // stays tied to geography as the orb rotates (Greenland is always cool,
  // Australia is always warm), rather than sweeping with the camera.
  //
  // Rim/specular/dispersion still use the viewing-angle Fresnel because
  // those are properties of the *glass*, not the map.
  float ndv = clamp(dot(worldNormal, -rayDir), 0.0, 1.0);
  // Slow rotation of the palette over time so the orb subtly breathes through
  // its color (very low-frequency — well under 10s per full cycle).
  float iridDrift = sin(time * T.iridescence.x) * T.iridescence.y;

  // Latitude → palette position. localNormal.y ∈ [-1, +1] (south→north).
  // Start at 0.25 — the LAVENDER end of the SKY→LAVENDER band — so the
  // gradient walks LAVENDER → LILAC → BLUSH → PEACH only. Including SKY_WASH
  // (G=0.847, an unusually high green channel for a pastel) put a cool/green
  // cast in the bloom halo around the silhouette.
  float latT = clamp(0.5 - localNormal.y * 0.5, 0.0, 1.0);
  latT = smoothstep(0.0, 1.0, latT);  // gentle ease at the poles
  float continentT = clamp(T.iridescence.z + latT * T.iridescence.w + iridDrift, 0.0, 1.0);
  float3 iridContinent = iridescent(continentT);

  // "Deep inland" mask — tighter threshold than the continent mask itself.
  // Where this is high, the pixel sits well inside a landmass (not at the
  // coast). We use it to add a subtle interior brightness boost, which
  // reads as the continent being *raised* over the body (3D-elevated)
  // instead of stamped flat. Crucially this avoids any glowing halo on
  // the *outside* of the coast, which is what was washing to white
  // against the cream background.
  float continentInner = smoothstep(T.continentBand.z, T.continentBand.w, landRaw);

  // ── Participant glow (city points, country blobs, join sparks) ───────────
  GlowAccum glowA = accumulateGlow(localNormal, glowSources,
                                   classicCount, surfaceCount, T.orbSeat.x,
                                   T.glowShape.x, T.glowShape.y);
  float glow = glowA.glow;
  float3 glowColor = glowPalette(glow, glowA.white);

  // ── Glass body — sharp rim, specular, dispersion ──────────────────────────
  //
  // Fresnel split into a soft outer "body" cue and a sharp narrow edge so the
  // silhouette has a clean glassy outline without losing the held softness
  // expected from the Deep palette.
  float fresnelBody = pow(1.0 - ndv, T.glass.x);  // gentle inner gleam near rim
  // Rim thickness is controlled by these exponents — higher = thinner. The
  // rim/edge/alpha exponents must stay proportional (10 : 18 : 28), so one
  // rimTightness scalar (T.glass.y) scales all three together.
  float fresnelRim  = pow(1.0 - ndv, 10.0 * T.glass.y);  // sharp bright outline
  float fresnelEdge = pow(1.0 - ndv, 18.0 * T.glass.y);  // ultra-thin dispersion sliver

  // Sun-driven specular highlight removed — it read as a stray reflection/shadow
  // blob hovering inside the body. The orb's "glass" cue now comes from the
  // sharp rim line + dispersion sliver only, no Phong hot-spot.
  // (Sun direction in uniforms is left in place in case we want to re-introduce
  // diffuse shading later — re-add `pow(max(dot(reflect(-L, N), -rayDir), 0), n)`
  // if you want the highlight back.)

  // Subtle warm/cool chromatic dispersion at the very edge. Stays inside the
  // Deep palette — lavender ↔ peach (no sky-wash, which has G=0.847 and would
  // tint the rim halo greenish against the warm backdrop).
  float dispAxis = clamp(worldNormal.x * 0.5 + 0.5, 0.0, 1.0);
  float3 dispersion = mix(LAVENDER_MIST, PEACH_CLOUD, dispAxis);
  float3 rimColor = mix(MOON_CREAM, dispersion, T.glass.w);

  // ── Refracted back-side bleed ─────────────────────────────────────────────
  //
  // Refract the view ray on entry, march through the sphere to the inner
  // back surface, and sample the continent map at the exit point. The result
  // is a faint ghost of the far hemisphere visible through the front face —
  // the visual cue that says "this is a solid glass ball, not a soap bubble."
  float ior = 1.0 / T.glass.z;
  float3 refr = refract(rayDir, worldNormal, ior);
  float backGlow = 0.0;
  float3 backTint = float3(0.0);
  float farGhost = 0.0;
  float3 farGhostColor = float3(0.0);
  if (dot(refr, refr) > 1e-4) {
    // Refracted ray starts on the front surface, points into the glass.
    float3 oc2 = hit.point - sphereCenter;
    float b2 = dot(refr, oc2);
    float c2 = dot(oc2, oc2) - radius * radius;
    float disc2 = b2 * b2 - c2;
    if (disc2 > 0.0) {
      float t2 = -b2 + sqrt(disc2);
      float3 exitPoint = hit.point + refr * t2;
      float3 exitNormalLocal = Rt * normalize(exitPoint - sphereCenter);
      float2 exitUV = sphericalUV(exitNormalLocal);
      float backSpec = continentTex.sample(texSampler, exitUV).r;
      float backLand = 1.0 - backSpec;
      float backContinent = smoothstep(T.coastBand.z, T.coastBand.w, backLand);
      // Fade the bleed near the rim so it doesn't fight the dispersion edge,
      // and dim it overall so it stays a whisper.
      backGlow = backContinent * (T.backBleed.x - fresnelRim * T.backBleed.y);
      backTint = iridescent(T.backBleed.z);

      // Far-side participant lights ghost through the glass body — core-only
      // gaussian at the refracted exit point, rim-faded like the continent
      // bleed so it never fights the dispersion edge.
      if (T.volumetric.w > 0.0) {
        GlowAccum ghostA = accumulateGlow(exitNormalLocal, glowSources,
                                          classicCount, surfaceCount, T.orbSeat.x,
                                          0.0, T.glowShape.y);
        farGhost = ghostA.glow * T.volumetric.w
                 * max(1.0 - fresnelRim * T.backBleed.y, 0.0);
        farGhostColor = mix(SOFT_LILAC, BLUSH_POWDER, ghostA.glow);
      }
    }
  }

  // ── Breath shimmer (very low amplitude, iridescent drift) ────────────────
  float shimmerN = fbm3(localNormal * 5.0 + float3(time * 0.04, 0, time * 0.025), 2);
  float shimmer = (shimmerN - 0.5) * T.haze.w;

  // ── Volumetric glow shell (hit path) ──────────────────────────────────────
  // March the wedge of shell in front of the orb body; ending the segment at
  // hit.t gives occlusion by the sphere for free. Reads as light standing up
  // off the lit surface rather than paint on it. Classic range only — orbs
  // and shells replace the column with their own 3D volumes.
  VolAccum vol = volumetricShell(rayOrigin, rayDir,
                                 max(atmoRange.t0, 0.0), hit.t,
                                 sphereCenter, radius, atmoRadius * breathScale,
                                 Rt, glowSources, classicCount, T);
  float3 volColor = mix(SOFT_LILAC, glowPalette(vol.glow, vol.white), T.volumetric.z);

  // ── Emissive composition (HDR linear) ─────────────────────────────────────
  //
  // Output is rgba16Float; the composite pass tonemaps luminance back into
  // display range while preserving chroma. So we can push continent emissive
  // well above 1.0 and the palette hue still survives.
  //
  // Continents are the *brightest* deliberate emitter (they're the subject of
  // the design) — louder than the rim/specular highlights so bloom keys off
  // their palette hue, not the moon-cream glass cues.
  //
  // Country glow blends *into* the continent color (mix, not add) so a hot
  // region warms toward blush/peach instead of overpowering the gradient.
  float3 landColor = mix(iridContinent, glowColor, glow * T.glowShape.z);
  // Brightness path: glow lifts the land's own emissive locally, and spark
  // whiteness can flash it further (T.bloomB.z) — the "land lights up" model,
  // which reads without the glowColor recolor when T.glowShape.z is zeroed.
  float landBrightness = 1.0 + glow * T.glowShape.w + glowA.white * T.bloomB.z;

  // Glow must also seat over water — an island or coastal city would vanish
  // where the land mask is zero. Gated with smoothstep so faint gaussian
  // skirts contribute nothing (grey-smudge guard against the pale backdrop);
  // only a genuinely lit point earns its ocean seat.
  float seaGlow = glow * (1.0 - continent) * smoothstep(0.15, 0.5, glow);

  // Tonemap math: at HDR intensities above ~1.5× palette, the luma-preserving
  // tonemap starts crushing chroma toward white (each channel approaches 1.0
  // and the ratios that carry hue flatten). Keep continent intensity in the
  // 1.0–1.3× range so palette colors survive the composite intact, then let
  // bloom provide the *halo* glow rather than pushing the body brighter.
  float3 emissive = float3(0.0);
  // Continent body — palette-natural intensity, no outward halo.
  emissive += landColor * continent * landBrightness * T.emissiveA.x;
  // Inland boost — adds the "raised over the body" feel. Operates *inside*
  // the continent mask only, so it never produces an outside-the-coast glow.
  emissive += landColor * continentInner * landBrightness * T.emissiveA.y;
  // Glass cues (rim, specular, dispersion) trimmed so they no longer outshout
  // the continent palette — otherwise their bloom halo washes the orb white.
  // Rim/edge are boosted (1.5 / 0.90 defaults) to compensate for the sharper
  // alpha curve below — keeps the bright silhouette line visible even though
  // the orb is now near-fully transparent a couple of pixels inside that line.
  // Ocean seat — lets city points on islands/coasts (and sparks mid-ocean
  // from imprecise geolocation) read where there is no land mask.
  emissive += glowColor * seaGlow * T.emissiveA.z;
  // Coastlines participate in a lit area (T.bloomB.w) — keeps island and
  // coastal cities readable when the sea-glow blob is zeroed in the
  // emissive-boost look. Neutral (0) by default.
  emissive += landColor * coastHalo * glow * T.bloomB.w;
  // Independent lit-land term — decoupled from the base land emissive, so the
  // unlit world can rest near-dark (low emissiveA.x) while lit regions burn
  // bright. Neutral (0) by default.
  float3 litColor = mix(iridContinent, glowColor, T.lit.y);
  emissive += litColor * continent * glow * T.lit.x;
  emissive += backTint * backGlow * T.emissiveA.w;
  emissive += rimColor * fresnelRim * T.emissiveB.x;
  emissive += dispersion * fresnelEdge * T.emissiveB.y;
  emissive += LAVENDER_MIST * fresnelBody * T.emissiveB.z;
  emissive += shimmer * MOON_CREAM * T.emissiveB.w;
  // Volumetric lift over the surface + far-side lights through the glass.
  emissive += volColor * vol.glow;
  emissive += farGhostColor * farGhost;
  // 3D light volumes in front of the body (orb balls, expanding shells) —
  // occluded by the surface via tMax inside the integrals.
  emissive += lvEmissive;

  // ── Alpha ─────────────────────────────────────────────────────────────────
  //
  // Crystal-clear body: ocean reads almost transparent. Continents remain
  // solid so the map stays legible. The sharp rim and specular gleam supply
  // the visual edge that says "glass," and the back-side bleed gives the
  // interior substance without fogging it out.
  // Coast halo kept here at small weight purely for soft alpha anti-aliasing
  // at the continent edge — it no longer contributes any color/emissive, so
  // it can't produce a visible halo. Just smooths the silhouette.
  //
  // Rim alpha uses a *sharp* fresnel — exponent 28 keeps the opaque band
  // confined to the visible bright rim line and lets alpha collapse to ~0
  // within a couple of pixels inside it. The three exponents stay proportional
  // (fresnelRim : fresnelEdge : rimAlpha ≈ 10 : 18 : 28) by construction —
  // all scale with the one rimTightness knob (T.glass.y) — so the alpha band
  // never extends past the visible rim or falls short of it.
  float rimAlpha = pow(1.0 - ndv, 28.0 * T.glass.y);
  // Volumetric and ghost terms must lift alpha themselves: blending is off
  // into the HDR target, so emissive without alpha never survives the
  // composite over clear ocean.
  float alpha = saturate(
      continent * T.alphaA.x
    + coastHalo * T.alphaA.y
    + rimAlpha * T.alphaA.z
    + backGlow * T.backBleed.w
    + seaGlow * T.alphaA.w
    + vol.glow * T.volumetric.y
    + farGhost * T.volumetric.y * 0.5
    + lvAlpha
  );

  return float4(emissive, alpha);
}
