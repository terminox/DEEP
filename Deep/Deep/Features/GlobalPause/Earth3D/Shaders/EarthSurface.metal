#include <metal_stdlib>
using namespace metal;

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

  // ── Country glow ──────────────────────────────────────────────────────────
  float glow = accumulateGlow(localNormal, glowSources, glowCount);
  float3 glowColor = mix(SOFT_LILAC, BLUSH_POWDER, glow);
  glowColor = mix(glowColor, PEACH_CLOUD, smoothstep(0.55, 0.95, glow));

  // ── Glass body — sharp rim, specular, dispersion ──────────────────────────
  //
  // Fresnel split into a soft outer "body" cue and a sharp narrow edge so the
  // silhouette has a clean glassy outline without losing the held softness
  // expected from the Deep palette.
  float fresnelBody = pow(1.0 - ndv, 2.2);   // gentle inner gleam near rim
  float fresnelRim  = pow(1.0 - ndv, 5.0);   // sharp bright outline
  float fresnelEdge = pow(1.0 - ndv, 9.0);   // ultra-thin dispersion sliver

  // Sun-driven specular. Phong reflection vector against the view direction,
  // shininess tuned to read as a soft wet gleam rather than a hard pinpoint.
  float3 L = normalize(U.sunDirection.xyz);
  float3 reflLight = reflect(-L, worldNormal);
  float specular = pow(max(dot(reflLight, -rayDir), 0.0), 64.0);
  // Fresnel-weight the specular so the highlight feels embedded in the glass.
  specular *= (0.55 + 0.45 * fresnelBody);

  // Subtle warm/cool chromatic dispersion at the very edge. Stays inside the
  // Deep palette — no rainbow, just a hint of sky/peach split.
  float dispAxis = clamp(worldNormal.x * 0.5 + 0.5, 0.0, 1.0);
  float3 dispersion = mix(SKY_WASH, PEACH_CLOUD, dispAxis);
  float3 rimColor = mix(MOON_CREAM, dispersion, 0.45);

  // ── Refracted back-side bleed ─────────────────────────────────────────────
  //
  // Refract the view ray on entry, march through the sphere to the inner
  // back surface, and sample the continent map at the exit point. The result
  // is a faint ghost of the far hemisphere visible through the front face —
  // the visual cue that says "this is a solid glass ball, not a soap bubble."
  float ior = 1.0 / 1.45;
  float3 refr = refract(rayDir, worldNormal, ior);
  float backGlow = 0.0;
  float3 backTint = float3(0.0);
  if (dot(refr, refr) > 1e-4) {
    // Refracted ray starts on the front surface, points into the glass.
    float3 oc2 = hit.point - sphereCenter;
    float b2 = dot(refr, oc2);
    float c2 = dot(oc2, oc2) - radius * radius;
    float disc2 = b2 * b2 - c2;
    if (disc2 > 0.0) {
      float t2 = -b2 + sqrt(disc2);
      float3 exitPoint = hit.point + refr * t2;
      float3 exitNormalLocal = transpose(R) * normalize(exitPoint - sphereCenter);
      float2 exitUV = sphericalUV(exitNormalLocal);
      float backSpec = continentTex.sample(texSampler, exitUV).r;
      float backLand = 1.0 - backSpec;
      float backContinent = smoothstep(0.30, 0.70, backLand);
      // Fade the bleed near the rim so it doesn't fight the dispersion edge,
      // and dim it overall so it stays a whisper.
      backGlow = backContinent * (0.55 - fresnelRim * 0.45);
      backTint = iridescent(0.42);
    }
  }

  // ── Breath shimmer (very low amplitude, iridescent drift) ────────────────
  float shimmerN = fbm3(localNormal * 5.0 + float3(time * 0.04, 0, time * 0.025), 2);
  float shimmer = (shimmerN - 0.5) * 0.06;

  // ── Emissive composition ──────────────────────────────────────────────────
  //
  // Order of contribution (front to back, conceptually):
  //   - Specular highlight (brightest, wet gleam)
  //   - Rim with dispersion
  //   - Front-face continents + coast halo + country glow
  //   - Faint back-side bleed (continents visible through the glass)
  //   - Soft body gleam near rim
  float3 emissive = float3(0.0);
  emissive += iridContinent * continent * 1.85;
  emissive += iridCoast * coastHalo * 0.85;
  emissive += glowColor * continent * glow * 1.6;
  emissive += backTint * backGlow * 0.55;
  emissive += rimColor * fresnelRim * 1.9;
  emissive += dispersion * fresnelEdge * 1.1;
  emissive += MOON_CREAM * specular * 1.35;
  emissive += SKY_WASH * fresnelBody * 0.10;
  emissive += shimmer * MOON_CREAM;

  // ── Alpha ─────────────────────────────────────────────────────────────────
  //
  // Crystal-clear body: ocean reads almost transparent. Continents remain
  // solid so the map stays legible. The sharp rim and specular gleam supply
  // the visual edge that says "glass," and the back-side bleed gives the
  // interior substance without fogging it out.
  float alpha = saturate(
      continent * 0.90
    + coastHalo * 0.40
    + fresnelRim * 1.05
    + fresnelEdge * 0.75
    + specular * 0.95
    + backGlow * 0.45
    + fresnelBody * 0.08
  );

  return float4(emissive, alpha);
}
