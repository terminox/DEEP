#include <metal_stdlib>
using namespace metal;

// ───────────────────────────────────────────────────────────────────────────
// Holographic Earth surface fragment shader.
//
// Single fullscreen triangle, sphere SDF raymarch, single hit point.
// Continents come from a bundled equirectangular texture (2048×1024,
// "specular" polarity: black = land, white = ocean → inverted at sample).
//
// Holographic ingredients (all driven in-shader, no per-frame uniforms
// needed beyond what we already had):
//   1. Viewing-angle iridescence walking the design palette
//      (sky_wash → lavender → lilac → blush → peach)
//   2. Lat/lon grid lines (sin-thresholded, faint)
//   3. Translucent body — only continents + grid + rim carry alpha
//   4. Country glow (gaussian accumulator, unchanged)
//   5. Fresnel rim warmed toward peach
//   6. Internal "glass" haze so the silhouette feels held, not hollow
//   7. Breath shimmer (subtle FBM iridescent drift)
//
// All palette constants are codified from Deep/Theme/DeepTheme.swift, which
// is the DESIGN.md palette. No high-saturation values anywhere.
// ───────────────────────────────────────────────────────────────────────────

struct GlowSourceGPU {
  float4 positionAndIntensity;  // xyz = unit pos on sphere, w = intensity 0..1
  float4 radiusPacked;          // x = angular radius (rad), yzw = reserved
};

struct EarthUniforms {
  float4x4 inverseViewProj;
  float4   cameraPosition;
  float4x4 sphereOrientation;
  float4   sunDirection;
  float4   params;          // x=time, y=breathPhase 0..1, z=aspect, w=glowCount
  float4   sphereData;      // xyz=center, w=radius
  float4   atmosphereData;  // x=atmoRadius, y=atmoStrength, z=baselineEmissive
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

// ── Glow accumulator ────────────────────────────────────────────────────────

static float accumulateGlow(float3 surfaceNormalLocal,
                            constant GlowSourceGPU* sources,
                            int count) {
  float total = 0.0;
  for (int i = 0; i < count; ++i) {
    float3 p = sources[i].positionAndIntensity.xyz;
    float intensity = sources[i].positionAndIntensity.w;
    float angularRadius = max(sources[i].radiusPacked.x, 0.01);
    float cosAngle = clamp(dot(surfaceNormalLocal, p), -1.0, 1.0);
    float angle = acos(cosAngle);
    float x = angle / angularRadius;
    if (x > 3.0) continue;
    float falloff = exp(-x * x * 0.5);
    total += falloff * intensity;
  }
  return 1.0 - exp(-total * 1.2);
}

// ── Main fragment ───────────────────────────────────────────────────────────

fragment float4 earthSurfaceFragment(
  FSIn in [[stage_in]],
  constant EarthUniforms& U [[buffer(0)]],
  constant GlowSourceGPU* glowSources [[buffer(1)]],
  texture2d<float> continentTex [[texture(0)]]
) {
  constexpr sampler texSampler(filter::linear,
                               mip_filter::linear,
                               address::repeat,
                               s_address::clamp_to_edge,
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
  float breathScale = 1.0 + 0.015 * breath;
  float radius = baseRadius * breathScale;

  Hit atmoHit = raySphere(rayOrigin, rayDir, sphereCenter, atmoRadius * breathScale);
  Hit hit = raySphere(rayOrigin, rayDir, sphereCenter, radius);

  if (!hit.hit) {
    // Atmosphere haze beyond the orb silhouette.
    if (!atmoHit.hit) return float4(0, 0, 0, 0);
    float3 n = atmoHit.normal;
    float density = pow(1.0 - abs(dot(n, -rayDir)), 2.0);
    float lat = n.y;
    float3 tint = mix(SOFT_LILAC, BLUSH_POWDER, smoothstep(-0.6, 0.6, -lat));
    tint = mix(tint, LAVENDER_MIST, 0.4);
    float a = density * atmoStrength * 0.55;
    return float4(tint * a, a);
  }

  float3 worldNormal = hit.normal;

  // Local frame so continents stay anchored to the rotating sphere.
  float3x3 R = float3x3(
    U.sphereOrientation[0].xyz,
    U.sphereOrientation[1].xyz,
    U.sphereOrientation[2].xyz
  );
  float3 localNormal = transpose(R) * worldNormal;

  // ── Continents from the bundled texture ───────────────────────────────────
  // Source polarity: black=land, white=ocean. Invert for our continent value.
  float2 uv = sphericalUV(localNormal);
  float specularSample = continentTex.sample(texSampler, uv).r;
  float landRaw = 1.0 - specularSample;
  // Soft threshold cleans up JPG artifacts + ignores the fine river/inland
  // detail (which would look like noise on a holographic orb at this scale).
  float continent = smoothstep(0.32, 0.68, landRaw);
  // A second, wider band keeps the soft "halo" around coasts so they don't
  // read as paper cutouts — gives a faint glow falloff at every coastline.
  float coastHalo = smoothstep(0.15, 0.55, landRaw) - continent;

  // ── Iridescent palette walk ───────────────────────────────────────────────
  float ndv = clamp(dot(worldNormal, -rayDir), 0.0, 1.0);
  // Fresnel-driven hue scrubber. Bias the walk so the center reads as
  // lavender/lilac and the rim drifts toward peach.
  float iridT = pow(1.0 - ndv, 1.4);
  // Slow rotation of the palette over time so the orb subtly breathes through
  // its color (very low-frequency — well under 10s per full cycle).
  float iridDrift = sin(time * 0.18) * 0.08;
  float3 iridContinent = iridescent(clamp(0.35 + iridT * 0.55 + iridDrift, 0.0, 1.0));
  float3 iridCoast = iridescent(clamp(0.55 + iridT * 0.4, 0.0, 1.0));

  // ── Lat/lon grid (faint, sin-thresholded) ─────────────────────────────────
  // 36 meridians × 18 parallels: classic globe density without being busy.
  // smoothstep edge at 0.985 keeps lines hair-thin so bloom does the heavy
  // lifting (post-pass turns 1px lines into soft halos).
  float meridianWave = abs(sin(uv.x * M_PI_F * 36.0));
  float parallelWave = abs(sin(uv.y * M_PI_F * 18.0));
  float meridians = smoothstep(0.984, 1.0, meridianWave);
  float parallels = smoothstep(0.984, 1.0, parallelWave);
  float grid = max(meridians, parallels);

  // ── Country glow ──────────────────────────────────────────────────────────
  float glow = accumulateGlow(localNormal, glowSources, glowCount);
  float3 glowColor = mix(SOFT_LILAC, BLUSH_POWDER, glow);
  glowColor = mix(glowColor, PEACH_CLOUD, smoothstep(0.55, 0.95, glow));

  // ── Fresnel rim ───────────────────────────────────────────────────────────
  float fresnel = pow(1.0 - ndv, 3.0);

  // ── Internal "glass" haze ─────────────────────────────────────────────────
  // Without this, the orb's ocean is invisible and the silhouette feels
  // hollow. A subtle inverse-fresnel haze gives the body a soft glass shell.
  float internalHaze = pow(1.0 - ndv, 1.6) * 0.5 + 0.08;

  // ── Breath shimmer (very low amplitude, iridescent drift) ────────────────
  float shimmerN = fbm3(localNormal * 5.0 + float3(time * 0.04, 0, time * 0.025), 2);
  float shimmer = (shimmerN - 0.5) * 0.08;

  // ── Emissive composition ──────────────────────────────────────────────────
  // Continents are the strongest emitter, then coast halo, then grid, then
  // glow blobs on top of land only (people are land), then peach rim.
  float3 emissive = float3(0.0);
  emissive += iridContinent * continent * 1.85;
  emissive += iridCoast * coastHalo * 0.85;
  emissive += iridescent(0.5) * grid * 0.45;
  emissive += glowColor * continent * glow * 1.6;
  emissive += PEACH_CLOUD * fresnel * 0.65;
  emissive += SKY_WASH * internalHaze * 0.35;
  emissive += shimmer * MOON_CREAM;

  // ── Alpha ─────────────────────────────────────────────────────────────────
  // Translucent body — continents make it solid, grid + haze + rim fill in
  // the rest so the silhouette is fully present without being opaque.
  float alpha = saturate(
      continent * 0.88
    + coastHalo * 0.45
    + grid * 0.35
    + fresnel * 0.55
    + internalHaze * 0.45
  );

  return float4(emissive, alpha);
}
