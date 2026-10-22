// ───────────────────────────────────────────────────────────────────────────
// Earth surface fragment shader — the crystal-glass orb.
//
// GLSL ES 3.00 port of iOS `Shaders/EarthSurface.metal`, line for line where
// the languages allow. EarthShaders.kt prepends the prelude (`#version 300
// es`, highp defaults, the palette as `const vec3`s generated from the DEEP
// colour tokens) and `earth_tuning.glsl`; with EARTH_DIRECT defined it also
// prepends `earth_tonemap.glsl` and this pass writes display colour straight
// to the window (the no-half-float fallback, EARTH3D_SPIKE.md §6 rung 5).
//
// Single fullscreen triangle, sphere raymarch, two hits per ray (the front
// surface plus the refracted back-side exit), so the orb reads as a solid
// piece of glass with continents suspended inside.
//
// What differs from the Metal source, and why:
//   - Glow sources live in a std140 UBO of flat vec4s (no SSBOs in ES 3.0);
//     source i is glowData[2i] / glowData[2i+1], the iOS byte layout.
//   - Sampler state is texture-object state (S repeat, T clamp, trilinear),
//     set by EarthRenderer — GLSL has no in-shader samplers.
//   - The UV derivatives the front-face sample needs are taken at the top of
//     main, on a normal defined for EVERY pixel, before anything returns:
//     dFdx/dFdy are undefined in non-uniform control flow on ES, and Metal's
//     tolerance for it is not something Mali or Adreno promise.
//   - The refracted back-face sample uses textureLod at a fixed coarse LOD
//     (it sits inside divergent control flow; the ghost is a blurred whisper
//     anyway).
//   - accumulateGlow rejects in the cosine domain before its acos (Fix B:
//     radiusPacked.w carries cos(7.5 r), computed on the CPU), and the light
//     volumes are skipped for rays that pass wider than every volume reaches
//     (Fix A: T.orbSeat.y). Both are exact — no pixel changes.
// ───────────────────────────────────────────────────────────────────────────

in vec2 vNdc;
layout(location = 0) out vec4 fragColor;

// Byte-identical to iOS `EarthUniforms` (13 vec4, 208 bytes). Binding 0.
layout(std140) uniform EarthUniforms {
  mat4 inverseViewProj;
  vec4 cameraPosition;
  mat4 sphereOrientation;
  vec4 sunDirection;
  vec4 params;          // x=time, y=breathPhase 0..1, z=classic glow count, w=total glow count
  vec4 sphereData;      // xyz=center, w=radius
  vec4 atmosphereData;  // x=atmoRadius, y=atmoStrength, z=orb glow count, w=world units per scene pixel
} U;

// Glow sources, sorted into three disjoint ranges — classic [0, classic),
// orb [classic, classic+orb), shell [classic+orb, total). Binding 1.
//   glowData[2i]   = positionAndIntensity (xyz = unit position, w = intensity)
//   glowData[2i+1] = radiusPacked
//     classic: x = angular radius (rad), y = whiteness, z = column height, w = cos(7.5 x)
//     orb:     x = sigma (world),        y = whiteness, z = style mode,    w = cos(7.5 x)
//     shell:   x = shell radius (world), y = whiteness, z = thickness,     w = 0
layout(std140) uniform GlowBlock {
  vec4 glowData[128];
};

uniform highp sampler2D continentTex;

#ifdef EARTH_DIRECT
// Dither amplitude in 8-bit steps: 1 / render scale, since the bilinear
// upscale to the window smooths it (EARTH3D_SPIKE.md §4.5).
uniform float uDither;
#endif

const float PI = 3.14159265358979;

// ── Hash + tiny FBM (breath shimmer only) ──────────────────────────────────

float hash13(vec3 p) {
  p = fract(p * 0.1031);
  p += dot(p, p.yzx + 33.33);
  return fract((p.x + p.y) * p.z);
}

float valueNoise3(vec3 p) {
  vec3 i = floor(p);
  vec3 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float n000 = hash13(i + vec3(0.0, 0.0, 0.0));
  float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
  float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
  float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
  float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
  float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
  float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
  float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
  float nx00 = mix(n000, n100, f.x);
  float nx10 = mix(n010, n110, f.x);
  float nx01 = mix(n001, n101, f.x);
  float nx11 = mix(n011, n111, f.x);
  return mix(mix(nx00, nx10, f.y), mix(nx01, nx11, f.y), f.z);
}

float fbm3(vec3 p, int octaves) {
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

// ── Sphere intersection ────────────────────────────────────────────────────

struct Hit {
  bool hit;
  float t;
  vec3 point;
  vec3 normal;
};

Hit raySphere(vec3 ro, vec3 rd, vec3 center, float radius) {
  Hit h;
  h.hit = false;
  h.t = 0.0;
  h.point = vec3(0.0);
  h.normal = vec3(0.0, 0.0, 1.0);
  vec3 oc = ro - center;
  float b = dot(rd, oc);
  float c = dot(oc, oc) - radius * radius;
  float disc = b * b - c;
  if (disc < 0.0) return h;
  float t = -b - sqrt(disc);
  if (t < 0.0) return h;
  h.hit = true;
  h.t = t;
  h.point = ro + rd * t;
  h.normal = normalize(h.point - center);
  return h;
}

// Both roots — the volumetric shell march needs the whole chord.
struct RangeHit {
  bool hit;
  float t0;   // near root (may be < 0 if the origin sits inside)
  float t1;   // far root
};

RangeHit raySphereRange(vec3 ro, vec3 rd, vec3 center, float radius) {
  RangeHit h;
  h.hit = false;
  h.t0 = 0.0;
  h.t1 = 0.0;
  vec3 oc = ro - center;
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

// ── Spherical UV ───────────────────────────────────────────────────────────
//
// Equirectangular: U = 0 at lon −180°, 0.5 at Greenwich; V = 0 at the north
// pole. The texture is uploaded image row 0 first, so V = 0 is the top row on
// GL exactly as MTKTextureLoader's top-left origin makes it on iOS — no flip.

vec2 sphericalUV(vec3 p) {
  // atan(0, 0) is undefined in GLSL (Metal's atan2 returns 0): at an exact
  // pole, take longitude 0 explicitly.
  float lon = (p.x == 0.0 && p.z == 0.0) ? 0.0 : atan(p.x, p.z);
  return vec2(lon / (2.0 * PI) + 0.5,
              0.5 - asin(clamp(p.y, -1.0, 1.0)) / PI);
}

// ── Iridescent palette walk ────────────────────────────────────────────────
// SKY_WASH → LAVENDER → LILAC → BLUSH → PEACH, never past the DEEP palette.

vec3 iridescent(float t) {
  vec3 c;
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

// ── Glow palette walk ──────────────────────────────────────────────────────
// lilac → blush → peach with intensity; whiteness warms toward moon-cream,
// capped at 0.55 so spark peaks read as candle-light, never raw white.

vec3 glowPalette(float v, float white) {
  vec3 c = mix(SOFT_LILAC, BLUSH_POWDER, v);
  c = mix(c, PEACH_CLOUD, smoothstep(0.55, 0.95, v));
  return mix(c, MOON_CREAM, min(white, 0.55));
}

// ── Glow accumulator ───────────────────────────────────────────────────────
//
// Gaussian core plus a quarter-weight halo skirt at 3x the radius, over the
// classic range and the orb range (orbs keep a dimmed seat, `seatWeight`).
// Shells are excluded by the caller's count.

struct GlowAccum {
  float glow;
  float white;
};

GlowAccum accumulateGlow(vec3 surfaceNormalLocal,
                         int classicCount,
                         int count,
                         float seatWeight,
                         float haloWeight,
                         float exposure) {
  float total = 0.0;
  float whiteTotal = 0.0;
  for (int i = 0; i < count; ++i) {
    vec4 positionAndIntensity = glowData[2 * i];
    vec4 radiusPacked = glowData[2 * i + 1];
    float cosAngle = clamp(dot(surfaceNormalLocal, positionAndIntensity.xyz), -1.0, 1.0);
    // Fix B: radiusPacked.w = cos(7.5 · max(r, 0.01) + a hair), or −1 past
    // the antipode — a reach just WIDER than the `x > 7.5` test below, so it
    // only skips sources that test would reject anyway, before their acos.
    // That test stays the one that decides, keeping float boundaries exact.
    if (cosAngle < radiusPacked.w) continue;
    float intensity = positionAndIntensity.w;
    float angularRadius = max(radiusPacked.x, 0.01);
    float whiteness = radiusPacked.y;
    float angle = acos(cosAngle);
    float x = angle / angularRadius;
    if (x > 7.5) continue;                              // halo reaches ~3x radius
    float core = exp(-x * x * 0.5);
    float halo = haloWeight * exp(-x * x * 0.5 / 9.0);  // sigma = 3r skirt
    float f = (core + halo) * intensity;
    if (i >= classicCount) f *= seatWeight;             // orb range: residual seat only
    total += f;
    whiteTotal += f * whiteness;
  }
  GlowAccum a;
  a.glow = 1.0 - exp(-total * exposure);
  a.white = clamp(whiteTotal, 0.0, 1.0);
  return a;
}

// ── Volumetric glow shell ──────────────────────────────────────────────────
//
// Fixed-count midpoint march through the shell between the surface and the
// atmosphere radius; each classic source contributes a column of light that
// flares into a dome and decays with height. Source-major so a cone test
// rejects far sources before any sampling.

#define VOL_SAMPLES 6

struct VolAccum {
  float glow;
  float white;
};

VolAccum volumetricShell(vec3 ro, vec3 rd,
                         float t0, float t1,
                         vec3 center, float radius, float atmoR,
                         mat3 Rt,
                         int count) {
  VolAccum a;
  a.glow = 0.0;
  a.white = 0.0;
  float volIntensity = T.lit.z;
  if (volIntensity <= 0.001 || count == 0 || t1 <= t0) return a;

  float gap = max(atmoR - radius, 1e-4);
  float dt = (t1 - t0) / float(VOL_SAMPLES);
  float w = dt / gap;                    // path-length normalisation
  float scaleH = max(T.lit.w, 0.02);     // volHeight
  vec3 midLocal = Rt * normalize(ro + rd * (0.5 * (t0 + t1)) - center);

  float total = 0.0;
  float whiteTotal = 0.0;
  for (int i = 0; i < count; ++i) {
    vec4 positionAndIntensity = glowData[2 * i];
    vec4 radiusPacked = glowData[2 * i + 1];
    vec3 p = positionAndIntensity.xyz;
    float intensity = positionAndIntensity.w;
    float srcRadius = max(radiusPacked.x, 0.01);
    float whiteness = radiusPacked.y;
    // Floored so a zero-packed source degrades to short columns.
    float heightMul = max(radiusPacked.z, 0.2);

    // Cone rejection: widest sigma is srcRadius·(1+volSoftness), nothing
    // survives past ~4 sigma, plus about one shell-gap of arc for limb chords.
    float margin = srcRadius * (1.0 + T.volumetric.x) * 4.0 + gap * 1.2;
    if (acos(clamp(dot(midLocal, p), -1.0, 1.0)) > margin) continue;

    float srcTotal = 0.0;
    for (int s = 0; s < VOL_SAMPLES; ++s) {
      float t = t0 + (float(s) + 0.5) * dt;
      vec3 q = ro + rd * t;
      float r = length(q - center);
      float h = clamp((r - radius) / gap, 0.0, 1.0);
      vec3 dirLocal = Rt * ((q - center) / r);
      float angle = acos(clamp(dot(dirLocal, p), -1.0, 1.0));
      float sigma = srcRadius * (1.0 + T.volumetric.x * h);   // dome flare upward
      float x = angle / sigma;
      if (x > 4.0) continue;
      float column = exp(-x * x * 0.5);
      float heightFall = exp(-h / (scaleH * heightMul));
      float topFade = 1.0 - smoothstep(0.85, 1.0, h);          // soft shell top
      srcTotal += column * heightFall * topFade;
    }
    float f = srcTotal * w * intensity;
    total += f;
    whiteTotal += f * whiteness;
  }
  a.glow = 1.0 - exp(-total * volIntensity);
  a.white = clamp(whiteTotal, 0.0, 1.0);
  return a;
}

// ── Volumetric light orbs + expanding shells (3D glow styles) ──────────────
//
// Closed-form line integrals in the sphere's local frame, with the ray
// origin REBASED to its closest approach to the centre (unrebased, the b²
// cancellation's error is a visible fraction of a shell's thickness). tMax
// is a finite sentinel (1e6) on miss rays.

// Peak-normalised line integral of a gaussian blob over t in (−inf, tMax].
// x = core (sigma), y = halo (3 sigma), each occlusion-clipped. Phi is
// approximated by smoothstep(−2, 2, ·) — exactly 0/1 past ±2 sigma.
vec2 orbCoreHalo(vec3 ro, vec3 rd, vec3 c, float sigma, float tMax) {
  vec3 u = c - ro;
  float tc = dot(u, rd);
  float b2 = max(dot(u, u) - tc * tc, 0.0);   // max() guards cancellation
  float s2 = sigma * sigma;
  if (b2 > 56.25 * s2) return vec2(0.0);      // 7.5 sigma, matches accumulateGlow
  float g = 0.5 * b2 / s2;
  float d = (tMax - tc) / sigma;
  return vec2(exp(-g) * smoothstep(-2.0, 2.0, d),
              exp(-g * (1.0 / 9.0)) * smoothstep(-6.0, 6.0, d));
}

// The same integral restricted to the half-space above the seat's tangent
// plane — a dome of light resting on the crust. x2 restores "intensity =
// peak brightness seen top-down".
vec2 domeCoreHalo(vec3 ro, vec3 rd, vec3 c, vec3 n, float sigma, float tMax) {
  vec3 u = c - ro;
  float tc = dot(u, rd);
  float b2 = max(dot(u, u) - tc * tc, 0.0);
  float s2 = sigma * sigma;
  if (b2 > 56.25 * s2) return vec2(0.0);
  float g = 0.5 * b2 / s2;
  float A = -dot(u, n);                       // dot(ro − c, n)
  float B = dot(rd, n);
  // Sign-preserved floor keeps tPlane finite.
  float Bs = (B >= 0.0) ? max(B, 1e-4) : min(B, -1e-4);
  float tPlane = -A / Bs;
  float tLo = (B >= 0.0) ? tPlane : -1e6;
  float tHi = (B >= 0.0) ? tMax : min(tPlane, tMax);
  float dHi = (tHi - tc) / sigma;
  float dLo = (tLo - tc) / sigma;
  float core = max(smoothstep(-2.0, 2.0, dHi) - smoothstep(-2.0, 2.0, dLo), 0.0);
  float halo = max(smoothstep(-6.0, 6.0, dHi) - smoothstep(-6.0, 6.0, dLo), 0.0);
  return 2.0 * vec2(exp(-g) * core,
                    exp(-g * (1.0 / 9.0)) * halo);
}

// Line integral of a thin spherical shell, normalised so a face-on ray
// returns 1.0. Two-crossing model with 1/cos limb brightening, a graze clamp
// and an exp outer skirt; a crossing behind tMax is invisible.
float shellIntegral(vec3 ro, vec3 rd, vec3 c, float R, float w, float tMax) {
  vec3 u = c - ro;
  float tc = dot(u, rd);
  float b2 = max(dot(u, u) - tc * tc, 0.0);
  float rOut = R + 3.0 * w;
  if (b2 > rOut * rOut) return 0.0;              // no crossing, no tail
  float q = sqrt(max(R * R - b2, 0.0));          // = R·cos(theta)
  if (tc - q > tMax) return 0.0;                 // whole shell behind the globe
  float Rs = max(R, 4.0 * w);                    // => cosMin <= 0.75
  float cosMin = 1.50 * sqrt(w / Rs);            // graze clamp => 1/cosC <= 4.8
  float cosC = max(q / max(R, 1e-4), cosMin);
  float path = 1.0 / cosC;
  float sw = max(w * path, 1e-5);                // smoothstep(a, a, ·) is undefined
  float v0 = smoothstep(-sw, sw, tMax - (tc - q));   // near crossing
  float v1 = smoothstep(-sw, sw, tMax - (tc + q));   // far crossing
  float dOut = max(sqrt(b2) - R, 0.0) / (0.7 * w);
  return 0.5 * path * (v0 + v1) * exp(-0.5 * dOut * dOut);
}

struct LightVolumeAccum {
  float orbDensity;    // sum (core + haloWeight·halo)·I — compressed by caller
  float orbHot;        // sum core²·I — uncompressed HDR spike, bloom driver
  float orbWhite;      // sum f·whiteness
  float shellDensity;  // sum shellIntegral·I
  float shellWhite;
};

// Sweeps the orb and shell ranges. Expects the rebased local-frame ray.
LightVolumeAccum accumulateLightVolumes(vec3 ro, vec3 rd, float tMax,
                                        float radius,
                                        int classicCount, int orbCount,
                                        int totalCount,
                                        float worldPerPixel) {
  LightVolumeAccum a;
  a.orbDensity = 0.0;
  a.orbHot = 0.0;
  a.orbWhite = 0.0;
  a.shellDensity = 0.0;
  a.shellWhite = 0.0;

  int orbEnd = classicCount + orbCount;
  for (int i = classicCount; i < orbEnd; ++i) {
    vec4 positionAndIntensity = glowData[2 * i];
    vec4 radiusPacked = glowData[2 * i + 1];
    vec3 p = positionAndIntensity.xyz;
    float intensity = positionAndIntensity.w;
    float whiteness = radiusPacked.y;
    float sigma = max(radiusPacked.x * T.orbShape.x, 1e-3);
    // Style mode rides radiusPacked.z: 0 = elevated full orb, 1 = surface
    // dome, 2 = buried sphere. Uniform across the wavefront — every fragment
    // loops the same sources.
    float mode = radiusPacked.z;
    float elev = (mode < 0.5) ? clamp(T.orbTint.w * sigma, 0.015, 0.05) : 0.0;
    vec3 c = p * (radius + elev);
    vec2 ch = (mode > 0.5 && mode < 1.5)
      ? domeCoreHalo(ro, rd, c, p, sigma, tMax)
      : orbCoreHalo(ro, rd, c, sigma, tMax);
    float f = (ch.x + T.orbTint.z * ch.y) * intensity;
    a.orbDensity += f;
    // core² is a gaussian of sigma/sqrt(2): a compact spike for the bloom.
    a.orbHot += ch.x * ch.x * intensity;
    a.orbWhite += f * min(whiteness + T.orbTint.x * ch.x, 1.0);
  }

  for (int i = orbEnd; i < totalCount; ++i) {
    vec4 positionAndIntensity = glowData[2 * i];
    vec4 radiusPacked = glowData[2 * i + 1];
    vec3 p = positionAndIntensity.xyz;
    float intensity = positionAndIntensity.w;
    float whiteness = radiusPacked.y;
    float R = radiusPacked.x;
    // Thickness floors at ~1.5 scene pixels so the ring never aliases.
    float w = max(radiusPacked.z, 1.5 * worldPerPixel);
    vec3 c = p * radius;
    float f = shellIntegral(ro, rd, c, R, w, tMax) * intensity;
    a.shellDensity += f;
    a.shellWhite += f * whiteness;
  }
  return a;
}

// ── The orb ────────────────────────────────────────────────────────────────
//
// Everything after the ray: returns HDR emissive + alpha. [dNdx]/[dNdy] are
// the screen derivatives of the sphere-local normal, taken in main.

vec4 shadeEarth(vec3 rayOrigin, vec3 rayDir, Hit hit, RangeHit atmoRange,
                float radius, float breathScale, mat3 Rt, vec3 dNdx, vec3 dNdy) {
  vec3 sphereCenter = U.sphereData.xyz;
  float atmoRadius = U.atmosphereData.x;
  float atmoStrength = U.atmosphereData.y;
  float time = U.params.x;
  int glowCount = int(U.params.w);

  // ── 3D light volumes, before the miss/hit split (shells reach ~1.4,
  //    far past the 1.06 atmosphere) ──
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
    vec3 roL = Rt * (rayOrigin - sphereCenter);
    vec3 rdL = Rt * rayDir;
    float tS = -dot(roL, rdL);
    roL += rdL * tS;
    // Fix A: after the rebase |roL| is the ray's closest approach to the
    // centre; past every volume's reach, both loops would return zero.
    float reach = T.orbSeat.y;
    if (reach <= 0.0 || dot(roL, roL) <= reach * reach) {
      float tMaxL = hit.hit ? (hit.t - tS) : 1e6;
      lv = accumulateLightVolumes(roL, rdL, tMaxL, radius,
                                  classicCount, orbCount, glowCount,
                                  U.atmosphereData.w);
    }
  }
  float orbCov = 1.0 - exp(-lv.orbDensity * T.orbShape.y);
  float shellCov = 1.0 - exp(-lv.shellDensity * T.burstShape.x);
  vec3 lvEmissive = vec3(0.0);
  float lvAlpha = 0.0;
  if (orbCov + shellCov > 5e-4) {
    // Whiteness as a density-weighted mean.
    vec3 orbCol = glowPalette(orbCov,
                              clamp(lv.orbWhite / max(lv.orbDensity, 1e-4), 0.0, 1.0));
    vec3 shellCol = glowPalette(shellCov,
                                clamp(lv.shellWhite / max(lv.shellDensity, 1e-4), 0.0, 1.0));
    // Hot terms are uncompressed HDR (bloom drivers) and never feed alpha.
    lvEmissive = orbCol * orbCov * T.orbShape.z
               + mix(orbCol, MOON_CREAM, 0.6) * lv.orbHot * T.orbShape.w
               + shellCol * shellCov * T.burstShape.y
               + mix(shellCol, MOON_CREAM, 0.5) * lv.shellDensity * T.burstShape.z;
    lvAlpha = orbCov * T.orbTint.y + shellCov * T.burstShape.w;
  }

  if (!hit.hit) {
    // Atmosphere haze and glow domes beyond the silhouette; rays that miss
    // even the atmosphere can still carry an orb skirt or a shell.
    if (!atmoRange.hit) {
      if (orbCov + shellCov <= 5e-4) return vec4(0.0);
      return vec4(lvEmissive, clamp(lvAlpha, 0.0, 1.0));
    }
    vec3 n = normalize(rayOrigin + rayDir * atmoRange.t0 - sphereCenter);
    float density = pow(1.0 - abs(dot(n, -rayDir)), T.haze.y);
    float lat = n.y;
    vec3 tint = mix(SOFT_LILAC, BLUSH_POWDER, smoothstep(-0.6, 0.6, -lat));
    tint = mix(tint, LAVENDER_MIST, 0.4);
    float a = density * atmoStrength * T.haze.x;

    // Glow columns rising past the silhouette. Classic range only.
    VolAccum vol = volumetricShell(rayOrigin, rayDir,
                                   max(atmoRange.t0, 0.0), atmoRange.t1,
                                   sphereCenter, radius, atmoRadius * breathScale,
                                   Rt, classicCount);
    vec3 volColor = mix(SOFT_LILAC, glowPalette(vol.glow, vol.white), T.volumetric.z);
    float outA = clamp(a + vol.glow * T.volumetric.y + lvAlpha, 0.0, 1.0);
    return vec4(tint * a + volColor * vol.glow + lvEmissive, outA);
  }

  vec3 worldNormal = hit.normal;
  vec3 localNormal = Rt * worldNormal;

  // ── Continents from the bundled texture (black = land, white = ocean) ──
  vec2 uv = sphericalUV(localNormal);

  // Explicit UV gradients from the SMOOTH local normal (no atan seam), so the
  // dateline doesn't pick a huge mip and print a vertical line.
  float xz_sq = max(localNormal.x * localNormal.x + localNormal.z * localNormal.z, 1e-5);
  vec3 du_dN = vec3(localNormal.z, 0.0, -localNormal.x) / (2.0 * PI * xz_sq);
  float y_arg = max(1.0 - localNormal.y * localNormal.y, 1e-5);
  vec3 dv_dN = vec3(0.0, -1.0 / (PI * sqrt(y_arg)), 0.0);
  vec2 dUVdx = vec2(dot(du_dN, dNdx), dot(dv_dN, dNdx));
  vec2 dUVdy = vec2(dot(du_dN, dNdy), dot(dv_dN, dNdy));

  float specularSample = textureGrad(continentTex, uv, dUVdx, dUVdy).r;
  float landRaw = 1.0 - specularSample;
  // Soft threshold: cleans JPEG artifacts and fine inland detail.
  float continent = smoothstep(T.continentBand.x, T.continentBand.y, landRaw);
  // A wider band keeps a soft halo around coasts.
  float coastHalo = smoothstep(T.coastBand.x, T.coastBand.y, landRaw) - continent;

  // ── Latitude-anchored pastel walk ──
  float ndv = clamp(dot(worldNormal, -rayDir), 0.0, 1.0);
  float iridDrift = sin(time * T.iridescence.x) * T.iridescence.y;
  float latT = clamp(0.5 - localNormal.y * 0.5, 0.0, 1.0);
  latT = smoothstep(0.0, 1.0, latT);
  float continentT = clamp(T.iridescence.z + latT * T.iridescence.w + iridDrift, 0.0, 1.0);
  vec3 iridContinent = iridescent(continentT);

  // "Deep inland" mask — the raised-continent brightness boost.
  float continentInner = smoothstep(T.continentBand.z, T.continentBand.w, landRaw);

  // ── Participant glow ──
  GlowAccum glowA = accumulateGlow(localNormal,
                                   classicCount, surfaceCount, T.orbSeat.x,
                                   T.glowShape.x, T.glowShape.y);
  float glow = glowA.glow;
  vec3 glowColor = glowPalette(glow, glowA.white);

  // ── Glass body: sharp rim, dispersion ──
  float fresnelBody = pow(1.0 - ndv, T.glass.x);
  // Rim / edge / alpha exponents stay proportional (10 : 18 : 28).
  float fresnelRim = pow(1.0 - ndv, 10.0 * T.glass.y);
  float fresnelEdge = pow(1.0 - ndv, 18.0 * T.glass.y);

  float dispAxis = clamp(worldNormal.x * 0.5 + 0.5, 0.0, 1.0);
  vec3 dispersion = mix(LAVENDER_MIST, PEACH_CLOUD, dispAxis);
  vec3 rimColor = mix(MOON_CREAM, dispersion, T.glass.w);

  // ── Refracted back-side bleed ──
  float ior = 1.0 / T.glass.z;
  vec3 refr = refract(rayDir, worldNormal, ior);
  float backGlow = 0.0;
  vec3 backTint = vec3(0.0);
  float farGhost = 0.0;
  vec3 farGhostColor = vec3(0.0);
  if (dot(refr, refr) > 1e-4) {
    vec3 oc2 = hit.point - sphereCenter;
    float b2 = dot(refr, oc2);
    float c2 = dot(oc2, oc2) - radius * radius;
    float disc2 = b2 * b2 - c2;
    if (disc2 > 0.0) {
      float t2 = -b2 + sqrt(disc2);
      vec3 exitPoint = hit.point + refr * t2;
      vec3 exitNormalLocal = Rt * normalize(exitPoint - sphereCenter);
      vec2 exitUV = sphericalUV(exitNormalLocal);
      // Fixed coarse LOD: divergent control flow, and a blurred whisper.
      float backSpec = textureLod(continentTex, exitUV, 2.0).r;
      float backLand = 1.0 - backSpec;
      float backContinent = smoothstep(T.coastBand.z, T.coastBand.w, backLand);
      backGlow = backContinent * (T.backBleed.x - fresnelRim * T.backBleed.y);
      backTint = iridescent(T.backBleed.z);

      // Far-side lights ghosting through the glass body.
      if (T.volumetric.w > 0.0) {
        GlowAccum ghostA = accumulateGlow(exitNormalLocal,
                                          classicCount, surfaceCount, T.orbSeat.x,
                                          0.0, T.glowShape.y);
        farGhost = ghostA.glow * T.volumetric.w
                 * max(1.0 - fresnelRim * T.backBleed.y, 0.0);
        farGhostColor = mix(SOFT_LILAC, BLUSH_POWDER, ghostA.glow);
      }
    }
  }

  // ── Breath shimmer ──
  float shimmerN = fbm3(localNormal * 5.0 + vec3(time * 0.04, 0.0, time * 0.025), 2);
  float shimmer = (shimmerN - 0.5) * T.haze.w;

  // ── Volumetric glow shell, hit path (ends at hit.t: occluded for free) ──
  VolAccum vol = volumetricShell(rayOrigin, rayDir,
                                 max(atmoRange.t0, 0.0), hit.t,
                                 sphereCenter, radius, atmoRadius * breathScale,
                                 Rt, classicCount);
  vec3 volColor = mix(SOFT_LILAC, glowPalette(vol.glow, vol.white), T.volumetric.z);

  // ── Emissive composition (HDR linear) ──
  vec3 landColor = mix(iridContinent, glowColor, glow * T.glowShape.z);
  float landBrightness = 1.0 + glow * T.glowShape.w + glowA.white * T.bloomB.z;
  // Glow seats over water only where it is genuinely lit (grey-smudge guard).
  float seaGlow = glow * (1.0 - continent) * smoothstep(0.15, 0.5, glow);

  vec3 emissive = vec3(0.0);
  emissive += landColor * continent * landBrightness * T.emissiveA.x;
  emissive += landColor * continentInner * landBrightness * T.emissiveA.y;
  emissive += glowColor * seaGlow * T.emissiveA.z;
  emissive += landColor * coastHalo * glow * T.bloomB.w;
  vec3 litColor = mix(iridContinent, glowColor, T.lit.y);
  emissive += litColor * continent * glow * T.lit.x;
  emissive += backTint * backGlow * T.emissiveA.w;
  emissive += rimColor * fresnelRim * T.emissiveB.x;
  emissive += dispersion * fresnelEdge * T.emissiveB.y;
  emissive += LAVENDER_MIST * fresnelBody * T.emissiveB.z;
  emissive += shimmer * MOON_CREAM * T.emissiveB.w;
  emissive += volColor * vol.glow;
  emissive += farGhostColor * farGhost;
  emissive += lvEmissive;

  // ── Alpha: crystal-clear ocean, solid continents, a sharp rim ──
  float rimAlpha = pow(1.0 - ndv, 28.0 * T.glass.y);
  float alpha = clamp(
      continent * T.alphaA.x
    + coastHalo * T.alphaA.y
    + rimAlpha * T.alphaA.z
    + backGlow * T.backBleed.w
    + seaGlow * T.alphaA.w
    + vol.glow * T.volumetric.y
    + farGhost * T.volumetric.y * 0.5
    + lvAlpha,
    0.0, 1.0);

  return vec4(emissive, alpha);
}

void main() {
  // Reconstruct the world-space ray from clip-space NDC (GL z in [−1, 1]).
  vec4 nearH = U.inverseViewProj * vec4(vNdc, -1.0, 1.0);
  vec4 farH = U.inverseViewProj * vec4(vNdc, 1.0, 1.0);
  vec3 nearP = nearH.xyz / nearH.w;
  vec3 farP = farH.xyz / farH.w;
  vec3 rayOrigin = nearP;
  vec3 rayDir = normalize(farP - nearP);

  vec3 sphereCenter = U.sphereData.xyz;
  float breathScale = 1.0 + T.haze.z * U.params.y;
  float radius = U.sphereData.w * breathScale;

  // Local frame, so continents stay anchored to the turning sphere.
  mat3 R = mat3(U.sphereOrientation);
  mat3 Rt = transpose(R);

  RangeHit atmoRange = raySphereRange(rayOrigin, rayDir, sphereCenter,
                                      U.atmosphereData.x * breathScale);
  Hit hit = raySphere(rayOrigin, rayDir, sphereCenter, radius);

  // Derivatives in uniform control flow, on a normal every pixel has: the
  // hit normal on the orb, and past the silhouette the direction to the
  // ray's closest approach — the limit the hit normal tends to at the rim, so
  // quads straddling the silhouette still difference continuous values.
  vec3 oc = rayOrigin - sphereCenter;
  vec3 closest = oc - rayDir * dot(rayDir, oc);
  vec3 anyNormal = hit.hit ? hit.normal : normalize(closest + vec3(0.0, 0.0, 1e-6));
  vec3 anyLocal = Rt * anyNormal;
  vec3 dNdx = dFdx(anyLocal);
  vec3 dNdy = dFdy(anyLocal);

  vec4 color = shadeEarth(rayOrigin, rayDir, hit, atmoRange, radius, breathScale, Rt, dNdx, dNdy);

#ifdef EARTH_DIRECT
  // No HDR target to bloom from: tonemap here and write display colour.
  vec3 display = tonemapPalette(color.rgb, T.bloomB.x);
  display += (dither13(gl_FragCoord.xy) - 0.5) * (uDither / 255.0);
  color = vec4(display, color.a);
#endif

  fragColor = color;
}
