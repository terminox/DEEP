// The iOS glass globe, ported to WebGL2. One fullscreen triangle, an analytic ray/sphere hit and
// the crystal-glass shading of Earth3D/Shaders/EarthSurface.metal: iridescent continents, a thin
// Fresnel rim, the refracted back-side ghost, breathing "buried orb" presence lights, classic
// join sparks with their volumetric columns, and the 2D halo ripples of EarthHaloRipples.swift.
// Defaults are EarthTuning.Values(); camera and tilt are EarthRendererConstants; rotation is
// EarthInteraction (north-up yaw/pitch, damped momentum, idle drift).

// MARK: Constants (EarthRendererConstants)

const CAMERA_DISTANCE = 8.5
const FOV_Y = Math.PI / 6
const AXIAL_TILT = (23.5 * Math.PI) / 180
const SPHERE_RADIUS = 1.0
const MAX_SOURCES = 64

/** The orb's radius in iOS NDC units: tan(asin(r / d)) / tan(fovY / 2). */
const ORB_NDC_RADIUS = Math.tan(Math.asin(SPHERE_RADIUS / CAMERA_DISTANCE)) / Math.tan(FOV_Y / 2)

/**
 * Orb diameter as a fraction of the canvas side. The canvas is a centred crop of the iOS
 * frustum (same camera, same rays), so the ocean margin stays small and fragments are not
 * spent on empty sky.
 */
export const GLOBE_FILL = 0.7
const NDC_CROP = ORB_NDC_RADIUS / GLOBE_FILL

// MARK: Interaction tuning (EarthInteraction.Tuning, idle drift raised to read on the web)

const DAMPING = 0.92
const PITCH_LIMIT = (85 * Math.PI) / 180
const IDLE_AFTER = 2.0
const IDLE_DRIFT = 0.08

// MARK: Glow store tuning (EarthGlowStore.Tuning)

const SPARK_LIFE = 2.0
const SPARK_CAP = 8
const SPARK_RADIUS = 0.03
const SPARK_PEAK = 1.3
const SPARK_COLUMN_BOOST = 1.5
const LERP_TAU = 0.8
const STEADY_CAP = 52

// MARK: Ripple tuning (EarthHaloRipples.Tuning)

const RIPPLE_LIFE = 1.2
const RIPPLE_CAP = 8
const RIPPLE_START = 0.05
const RIPPLE_END = 0.32
const RIPPLE_OPACITY = 0.7

// MARK: Shaders

const VERTEX = `#version 300 es
out vec2 vNdc;
void main() {
  vec2 p = vec2(gl_VertexID == 2 ? 3.0 : -1.0, gl_VertexID == 0 ? -3.0 : 1.0);
  vNdc = p;
  gl_Position = vec4(p, 0.0, 1.0);
}
`

const FRAGMENT = `#version 300 es
precision highp float;
precision highp int;

in vec2 vNdc;
out vec4 outColor;

uniform mat4 uInvVP;
uniform mat3 uOrient;
uniform float uTime;
uniform float uCrop;
uniform int uClassicCount;
uniform int uTotalCount;
uniform vec4 uSrcPos[${MAX_SOURCES}];
uniform vec4 uSrcRad[${MAX_SOURCES}];
uniform sampler2D uLand;

const float PI = 3.14159265;

// Palette (DEEP design system)
const vec3 LAVENDER_MIST = vec3(0.722, 0.655, 0.910);
const vec3 SOFT_LILAC    = vec3(0.831, 0.773, 0.941);
const vec3 BLUSH_POWDER  = vec3(0.957, 0.788, 0.831);
const vec3 SKY_WASH      = vec3(0.773, 0.847, 0.941);
const vec3 PEACH_CLOUD   = vec3(0.961, 0.851, 0.769);
const vec3 MOON_CREAM    = vec3(0.984, 0.969, 1.000);

// EarthTuning.Values() defaults
const float GLOW_HALO = 0.30;
const float GLOW_EXPOSURE = 1.2;
const float GLOW_LAND_MIX = 0.75;
const float GLOW_BRIGHTNESS = 0.35;
const float HAZE_ALPHA = 0.1;
const float HAZE_EXP = 2.0;
const float ATMO_STRENGTH = 0.1;
const float ATMO_RADIUS = 1.06;
const float SHIMMER_AMP = 0.06;
const vec4 CONTINENT_BAND = vec4(0.32, 0.68, 0.40, 0.75);
const vec4 COAST_BAND = vec4(0.15, 0.55, 0.30, 0.70);
const vec4 IRIDESCENCE = vec4(0.18, 0.06, 0.25, 0.75);
const vec4 GLASS = vec4(2.2, 1.0, 1.45, 0.45);
const vec4 BACK_BLEED = vec4(0.55, 0.45, 0.42, 0.45);
const vec4 EMISSIVE_A = vec4(1.00, 0.30, 0.40, 0.40);
const vec4 EMISSIVE_B = vec4(1.50, 0.90, 0.08, 1.0);
const vec4 ALPHA_A = vec4(0.92, 0.18, 1.20, 0.30);
const float TONEMAP_K = 1.5;
const vec4 VOL = vec4(0.8, 0.6, 0.6, 0.25);   // softness, alphaLift, tintMix, backGhost
const float VOL_INTENSITY = 0.85;
const float VOL_HEIGHT = 0.35;
const vec4 ORB_SHAPE = vec4(1.0, 2.6, 0.9, 1.4);
const vec4 ORB_TINT = vec4(0.45, 0.85, 0.35, 1.6);
const float ORB_SEAT = 0.35;

// Hash + tiny FBM (breath shimmer)
float hash13(vec3 p) {
  p = fract(p * 0.1031);
  p += dot(p, p.yzx + 33.33);
  return fract((p.x + p.y) * p.z);
}

float valueNoise3(vec3 p) {
  vec3 i = floor(p);
  vec3 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float n000 = hash13(i + vec3(0, 0, 0));
  float n100 = hash13(i + vec3(1, 0, 0));
  float n010 = hash13(i + vec3(0, 1, 0));
  float n110 = hash13(i + vec3(1, 1, 0));
  float n001 = hash13(i + vec3(0, 0, 1));
  float n101 = hash13(i + vec3(1, 0, 1));
  float n011 = hash13(i + vec3(0, 1, 1));
  float n111 = hash13(i + vec3(1, 1, 1));
  float nx00 = mix(n000, n100, f.x);
  float nx10 = mix(n010, n110, f.x);
  float nx01 = mix(n001, n101, f.x);
  float nx11 = mix(n011, n111, f.x);
  return mix(mix(nx00, nx10, f.y), mix(nx01, nx11, f.y), f.z);
}

float fbm3(vec3 p) {
  float sum = 0.0;
  float amp = 0.5;
  float freq = 1.0;
  for (int i = 0; i < 2; ++i) {
    sum += amp * valueNoise3(p * freq);
    freq *= 2.0;
    amp *= 0.5;
  }
  return sum;
}

// Equirectangular: U = 0.5 at lon 0, V = 0 at the north pole.
vec2 sphericalUV(vec3 p) {
  return vec2(atan(p.x, p.z) / (2.0 * PI) + 0.5, 0.5 - asin(clamp(p.y, -1.0, 1.0)) / PI);
}

vec3 iridescent(float t) {
  if (t < 0.25) return mix(SKY_WASH, LAVENDER_MIST, smoothstep(0.0, 0.25, t));
  if (t < 0.5) return mix(LAVENDER_MIST, SOFT_LILAC, smoothstep(0.25, 0.5, t));
  if (t < 0.75) return mix(SOFT_LILAC, BLUSH_POWDER, smoothstep(0.5, 0.75, t));
  return mix(BLUSH_POWDER, PEACH_CLOUD, smoothstep(0.75, 1.0, t));
}

vec3 glowPalette(float v, float white) {
  vec3 c = mix(SOFT_LILAC, BLUSH_POWDER, v);
  c = mix(c, PEACH_CLOUD, smoothstep(0.55, 0.95, v));
  return mix(c, MOON_CREAM, min(white, 0.55));
}

float landAt(vec2 uv) {
  return 1.0 - texture(uLand, uv).r;
}

// Classic range plus the orb range (orbs keep a dimmed seat on the land).
vec2 accumulateGlow(vec3 nLocal, float haloWeight) {
  float total = 0.0;
  float whiteTotal = 0.0;
  for (int i = 0; i < ${MAX_SOURCES}; ++i) {
    if (i >= uTotalCount) break;
    vec3 p = uSrcPos[i].xyz;
    float intensity = uSrcPos[i].w;
    float r = max(uSrcRad[i].x, 0.01);
    float x = acos(clamp(dot(nLocal, p), -1.0, 1.0)) / r;
    if (x > 7.5) continue;
    // Web-only: fade the skirt out before the 7.5r cutoff; on the night stage the cutoff
    // otherwise prints a hard circle that the iOS bloom chain used to blur away.
    float f = (exp(-x * x * 0.5) + haloWeight * exp(-x * x * 0.5 / 9.0)) * intensity
      * (1.0 - smoothstep(5.0, 7.5, x));
    if (i >= uClassicCount) f *= ORB_SEAT;
    total += f;
    whiteTotal += f * uSrcRad[i].y;
  }
  return vec2(1.0 - exp(-total * GLOW_EXPOSURE), clamp(whiteTotal, 0.0, 1.0));
}

// Volumetric glow columns for the classic range (join sparks), six midpoint samples.
vec2 volumetricShell(vec3 ro, vec3 rd, float t0, float t1, mat3 Rt) {
  if (uClassicCount == 0 || t1 <= t0) return vec2(0.0);
  float gap = ATMO_RADIUS - 1.0;
  float dt = (t1 - t0) / 6.0;
  float w = dt / gap;
  vec3 midLocal = Rt * normalize(ro + rd * (0.5 * (t0 + t1)));
  float total = 0.0;
  float whiteTotal = 0.0;
  for (int i = 0; i < ${SPARK_CAP}; ++i) {
    if (i >= uClassicCount) break;
    vec3 p = uSrcPos[i].xyz;
    float srcRadius = max(uSrcRad[i].x, 0.01);
    float heightMul = max(uSrcRad[i].z, 0.2);
    float margin = srcRadius * (1.0 + VOL.x) * 4.0 + gap * 1.2;
    if (acos(clamp(dot(midLocal, p), -1.0, 1.0)) > margin) continue;
    float srcTotal = 0.0;
    for (int s = 0; s < 6; ++s) {
      vec3 q = ro + rd * (t0 + (float(s) + 0.5) * dt);
      float r = length(q);
      float h = clamp((r - 1.0) / gap, 0.0, 1.0);
      vec3 dirLocal = Rt * (q / r);
      float sigma = srcRadius * (1.0 + VOL.x * h);
      float x = acos(clamp(dot(dirLocal, p), -1.0, 1.0)) / sigma;
      if (x > 4.0) continue;
      srcTotal += exp(-x * x * 0.5) * exp(-h / (VOL_HEIGHT * heightMul)) * (1.0 - smoothstep(0.85, 1.0, h));
    }
    float f = srcTotal * w * uSrcPos[i].w;
    total += f;
    whiteTotal += f * uSrcRad[i].y;
  }
  return vec2(1.0 - exp(-total * VOL_INTENSITY), clamp(whiteTotal, 0.0, 1.0));
}

// Peak-normalised line integral of a gaussian light ball (orbCoreHalo).
vec2 orbCoreHalo(vec3 ro, vec3 rd, vec3 c, float sigma, float tMax) {
  vec3 u = c - ro;
  float tc = dot(u, rd);
  float b2 = max(dot(u, u) - tc * tc, 0.0);
  float s2 = sigma * sigma;
  if (b2 > 56.25 * s2) return vec2(0.0);
  float g = 0.5 * b2 / s2;
  float d = (tMax - tc) / sigma;
  float edge = 1.0 - smoothstep(0.45, 1.0, b2 / (56.25 * s2));  // web-only soft cutoff
  return vec2(exp(-g) * smoothstep(-2.0, 2.0, d), exp(-g / 9.0) * smoothstep(-6.0, 6.0, d) * edge);
}

vec3 tonemapPalette(vec3 x) {
  float luma = dot(x, vec3(0.2126, 0.7152, 0.0722));
  if (luma < 1e-5) return x;
  vec3 result = x * ((1.0 - exp(-luma * TONEMAP_K)) / luma);
  float maxC = max(max(result.r, result.g), result.b);
  if (maxC > 1.0) {
    float t = clamp((maxC - 1.0) * 0.8, 0.0, 1.0);
    result = min(mix(result, vec3(1.0), t * 0.35), vec3(1.0));
  }
  return result;
}

vec4 finish(vec3 emissive, float alpha) {
  vec3 c = tonemapPalette(emissive);
  c += (hash13(vec3(gl_FragCoord.xy, 1.0)) - 0.5) / 255.0;
  return vec4(max(c, 0.0), clamp(alpha, 0.0, 1.0));
}

void main() {
  // Rebuild the world ray from NDC with the inverse view-projection. The canvas is a centred
  // crop of the iOS frame, so NDC is scaled into the iOS frustum first.
  vec2 ndc = vNdc * uCrop;
  vec4 nearH = uInvVP * vec4(ndc, -1.0, 1.0);
  vec4 farH = uInvVP * vec4(ndc, 1.0, 1.0);
  vec3 ro = nearH.xyz / nearH.w;
  vec3 rd = normalize(farH.xyz / farH.w - ro);

  mat3 Rt = transpose(uOrient);

  // Analytic hits: the orb and the atmosphere shell.
  float b = dot(rd, ro);
  float cS = dot(ro, ro) - 1.0;
  float disc = b * b - cS;
  bool hit = disc >= 0.0 && (-b - sqrt(disc)) >= 0.0;
  float tHit = hit ? -b - sqrt(disc) : 0.0;
  float cA = dot(ro, ro) - ATMO_RADIUS * ATMO_RADIUS;
  float discA = b * b - cA;
  bool atmoHit = discA >= 0.0 && (-b + sqrt(max(discA, 0.0))) >= 0.0;
  float atmoT0 = -b - sqrt(max(discA, 0.0));
  float atmoT1 = -b + sqrt(max(discA, 0.0));

  // Buried presence orbs (the orb range), in the rebased local frame.
  vec3 roL = Rt * ro;
  vec3 rdL = Rt * rd;
  float tS = -dot(roL, rdL);
  roL += rdL * tS;
  float tMaxL = hit ? (tHit - tS) : 1e6;
  float orbDensity = 0.0;
  float orbHot = 0.0;
  float orbWhite = 0.0;
  for (int i = 0; i < ${MAX_SOURCES}; ++i) {
    if (i >= uTotalCount) break;
    if (i < uClassicCount) continue;
    vec3 p = uSrcPos[i].xyz;
    float intensity = uSrcPos[i].w;
    float sigma = max(uSrcRad[i].x * ORB_SHAPE.x, 1e-3);
    vec2 ch = orbCoreHalo(roL, rdL, p, sigma, tMaxL);
    float f = (ch.x + ORB_TINT.z * ch.y) * intensity;
    orbDensity += f;
    orbHot += ch.x * ch.x * intensity;
    orbWhite += f * min(uSrcRad[i].y + ORB_TINT.x * ch.x, 1.0);
  }
  float orbCov = 1.0 - exp(-orbDensity * ORB_SHAPE.y);
  vec3 lvEmissive = vec3(0.0);
  float lvAlpha = 0.0;
  if (orbCov > 5e-4) {
    vec3 orbCol = glowPalette(orbCov, clamp(orbWhite / max(orbDensity, 1e-4), 0.0, 1.0));
    lvEmissive = orbCol * orbCov * ORB_SHAPE.z + mix(orbCol, MOON_CREAM, 0.6) * orbHot * ORB_SHAPE.w;
    lvAlpha = orbCov * ORB_TINT.y;
  }

  if (!hit) {
    if (!atmoHit) {
      if (orbCov <= 5e-4) { outColor = vec4(0.0); return; }
      outColor = finish(lvEmissive, lvAlpha);
      return;
    }
    vec3 n = normalize(ro + rd * atmoT0);
    float density = pow(1.0 - abs(dot(n, -rd)), HAZE_EXP);
    vec3 tint = mix(SOFT_LILAC, BLUSH_POWDER, smoothstep(-0.6, 0.6, -n.y));
    tint = mix(tint, LAVENDER_MIST, 0.4);
    float a = density * ATMO_STRENGTH * HAZE_ALPHA;
    vec2 vol = volumetricShell(ro, rd, max(atmoT0, 0.0), atmoT1, Rt);
    vec3 volColor = mix(SOFT_LILAC, glowPalette(vol.x, vol.y), VOL.z);
    outColor = finish(tint * a + volColor * vol.x + lvEmissive, a + vol.x * VOL.y + lvAlpha);
    return;
  }

  vec3 hitPoint = ro + rd * tHit;
  vec3 worldNormal = normalize(hitPoint);
  vec3 localNormal = Rt * worldNormal;

  // Continents: black = land in the source, so invert. The texture has no mipmaps, so the
  // atan seam at the dateline can't pick a wrong mip level.
  float landRaw = landAt(sphericalUV(localNormal));
  float continent = smoothstep(CONTINENT_BAND.x, CONTINENT_BAND.y, landRaw);
  float coastHalo = smoothstep(COAST_BAND.x, COAST_BAND.y, landRaw) - continent;

  float ndv = clamp(dot(worldNormal, -rd), 0.0, 1.0);
  float iridDrift = sin(uTime * IRIDESCENCE.x) * IRIDESCENCE.y;
  float latT = smoothstep(0.0, 1.0, clamp(0.5 - localNormal.y * 0.5, 0.0, 1.0));
  vec3 iridContinent = iridescent(clamp(IRIDESCENCE.z + latT * IRIDESCENCE.w + iridDrift, 0.0, 1.0));
  float continentInner = smoothstep(CONTINENT_BAND.z, CONTINENT_BAND.w, landRaw);

  vec2 glowA = accumulateGlow(localNormal, GLOW_HALO);
  float glow = glowA.x;
  vec3 glowColor = glowPalette(glow, glowA.y);

  // Glass: soft body gleam, sharp rim, ultra-thin dispersion sliver (10 : 18 : 28).
  float fresnelBody = pow(1.0 - ndv, GLASS.x);
  float fresnelRim = pow(1.0 - ndv, 10.0 * GLASS.y);
  float fresnelEdge = pow(1.0 - ndv, 18.0 * GLASS.y);
  vec3 dispersion = mix(LAVENDER_MIST, PEACH_CLOUD, clamp(worldNormal.x * 0.5 + 0.5, 0.0, 1.0));
  vec3 rimColor = mix(MOON_CREAM, dispersion, GLASS.w);

  // Refracted back-side bleed: the far hemisphere ghosting through solid glass.
  vec3 refr = refract(rd, worldNormal, 1.0 / GLASS.z);
  float backGlow = 0.0;
  vec3 backTint = vec3(0.0);
  float farGhost = 0.0;
  vec3 farGhostColor = vec3(0.0);
  if (dot(refr, refr) > 1e-4) {
    float b2 = dot(refr, hitPoint);
    float c2 = dot(hitPoint, hitPoint) - 1.0;
    float disc2 = b2 * b2 - c2;
    if (disc2 > 0.0) {
      vec3 exitPoint = hitPoint + refr * (-b2 + sqrt(disc2));
      vec3 exitNormalLocal = Rt * normalize(exitPoint);
      float backContinent = smoothstep(COAST_BAND.z, COAST_BAND.w, landAt(sphericalUV(exitNormalLocal)));
      backGlow = backContinent * (BACK_BLEED.x - fresnelRim * BACK_BLEED.y);
      backTint = iridescent(BACK_BLEED.z);
      vec2 ghostA = accumulateGlow(exitNormalLocal, 0.0);
      farGhost = ghostA.x * VOL.w * max(1.0 - fresnelRim * BACK_BLEED.y, 0.0);
      farGhostColor = mix(SOFT_LILAC, BLUSH_POWDER, ghostA.x);
    }
  }

  float shimmer = (fbm3(localNormal * 5.0 + vec3(uTime * 0.04, 0.0, uTime * 0.025)) - 0.5) * SHIMMER_AMP;

  vec2 vol = volumetricShell(ro, rd, max(atmoT0, 0.0), tHit, Rt);
  vec3 volColor = mix(SOFT_LILAC, glowPalette(vol.x, vol.y), VOL.z);

  vec3 landColor = mix(iridContinent, glowColor, glow * GLOW_LAND_MIX);
  float landBrightness = 1.0 + glow * GLOW_BRIGHTNESS;
  float seaGlow = glow * (1.0 - continent) * smoothstep(0.15, 0.5, glow);

  vec3 emissive = vec3(0.0);
  emissive += landColor * continent * landBrightness * EMISSIVE_A.x;
  emissive += landColor * continentInner * landBrightness * EMISSIVE_A.y;
  emissive += glowColor * seaGlow * EMISSIVE_A.z;
  emissive += backTint * backGlow * EMISSIVE_A.w;
  emissive += rimColor * fresnelRim * EMISSIVE_B.x;
  emissive += dispersion * fresnelEdge * EMISSIVE_B.y;
  emissive += LAVENDER_MIST * fresnelBody * EMISSIVE_B.z;
  emissive += shimmer * MOON_CREAM * EMISSIVE_B.w;
  emissive += volColor * vol.x;
  emissive += farGhostColor * farGhost;
  emissive += lvEmissive;

  float rimAlpha = pow(1.0 - ndv, 28.0 * GLASS.y);
  float alpha = continent * ALPHA_A.x
    + coastHalo * ALPHA_A.y
    + rimAlpha * ALPHA_A.z
    + backGlow * BACK_BLEED.w
    + seaGlow * ALPHA_A.w
    + vol.x * VOL.y
    + farGhost * VOL.y * 0.5
    + lvAlpha;

  outColor = finish(emissive, alpha);
}
`

// MARK: Presence data

type LatLon = readonly [number, number]

/** ~40 stubbed participants, weighted toward where people live. */
const PARTICIPANTS: readonly LatLon[] = [
  [13.8, 100.5], [18.8, 99.0], [21.0, 105.8], [14.6, 121.0], [-6.2, 106.8], [1.4, 103.8],
  [35.7, 139.7], [37.6, 127.0], [31.2, 121.5], [39.9, 116.4], [22.5, 114.1], [28.6, 77.2],
  [19.1, 72.9], [12.97, 77.6], [23.8, 90.4], [25.2, 55.3], [41.0, 29.0], [30.0, 31.2],
  [6.5, 3.4], [-1.3, 36.8], [-26.2, 28.0], [9.0, 38.7], [51.5, -0.1], [48.9, 2.4],
  [52.5, 13.4], [41.9, 12.5], [40.4, -3.7], [59.3, 18.1], [55.8, 37.6], [40.7, -74.0],
  [34.1, -118.2], [43.7, -79.4], [41.9, -87.6], [19.4, -99.1], [-23.6, -46.6], [-34.6, -58.4],
  [4.7, -74.1], [-12.0, -77.0], [-33.9, 151.2], [-37.8, 145.0], [-41.3, 174.8], [64.1, -21.9],
]

function unitVector(lat: number, lon: number): [number, number, number] {
  const la = (lat * Math.PI) / 180
  const lo = (lon * Math.PI) / 180
  return [Math.cos(la) * Math.sin(lo), Math.sin(la), Math.cos(la) * Math.cos(lo)]
}

type Steady = {
  pos: [number, number, number]
  sigma: number
  target: number
  current: number
  phase: number
}

type Spark = { pos: [number, number, number]; age: number }
type Ripple = { pos: [number, number, number]; born: number }

const smoothstep = (a: number, b: number, x: number) => {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a)))
  return t * t * (3 - 2 * t)
}

// MARK: Matrices (column-major)

type Mat3 = number[]

function mul3(a: Mat3, b: Mat3): Mat3 {
  const out = new Array<number>(9).fill(0)
  for (let c = 0; c < 3; c++) {
    for (let r = 0; r < 3; r++) {
      out[c * 3 + r] = a[r] * b[c * 3] + a[3 + r] * b[c * 3 + 1] + a[6 + r] * b[c * 3 + 2]
    }
  }
  return out
}

const rotZ = (a: number): Mat3 => [Math.cos(a), Math.sin(a), 0, -Math.sin(a), Math.cos(a), 0, 0, 0, 1]
const rotX = (a: number): Mat3 => [1, 0, 0, 0, Math.cos(a), Math.sin(a), 0, -Math.sin(a), Math.cos(a)]
const rotY = (a: number): Mat3 => [Math.cos(a), 0, -Math.sin(a), 0, 1, 0, Math.sin(a), 0, Math.cos(a)]

/** Inverse of perspective(fovY, aspect 1) × translate(0, 0, -d), written out analytically. */
function inverseViewProjection(): Float32Array {
  const near = 0.1
  const far = 100
  const f = 1 / Math.tan(FOV_Y / 2)
  const A = (far + near) / (near - far)
  const B = (2 * far * near) / (near - far)
  // Inverse projection (column-major), then undo the view translation.
  const invP = [1 / f, 0, 0, 0, 0, 1 / f, 0, 0, 0, 0, 0, 1 / B, 0, 0, -1, A / B]
  const d = CAMERA_DISTANCE
  const out = new Float32Array(16)
  for (let c = 0; c < 4; c++) {
    const x = invP[c * 4]
    const y = invP[c * 4 + 1]
    const z = invP[c * 4 + 2]
    const w = invP[c * 4 + 3]
    out[c * 4] = x
    out[c * 4 + 1] = y
    out[c * 4 + 2] = z + d * w
    out[c * 4 + 3] = w
  }
  return out
}

// MARK: Globe

export type GlassGlobeOptions = {
  reducedMotion: boolean
  /** Called for every simulated join, so the page can tick its count. */
  onJoin?: () => void
  /** Called once the land texture has uploaded and the first frame is drawn. */
  onReady?: () => void
  /** Receives drags; defaults to the canvas. Lets a globe-sized hit area sit over a larger canvas. */
  hitTarget?: HTMLElement
}

export class GlassGlobe {
  private gl: WebGL2RenderingContext
  private program: WebGLProgram
  private vao: WebGLVertexArrayObject
  private texture: WebGLTexture
  private uniforms: Record<string, WebGLUniformLocation | null> = {}
  private ctx2d: CanvasRenderingContext2D | null
  private srcPos = new Float32Array(MAX_SOURCES * 4)
  private srcRad = new Float32Array(MAX_SOURCES * 4)

  private ready = false
  private active = false
  private destroyed = false
  private raf = 0
  private start = performance.now() / 1000
  private lastFrame: number | null = null
  private cssSize = 0

  // EarthInteraction state: north-up yaw/pitch, damped momentum, idle drift.
  private yaw = -1.85
  private pitch = 0.12
  private momentum: [number, number] = [0, 0]
  private dragVelocity: [number, number] = [0, 0]
  private lastInteraction = -100
  private lastPointer: { x: number; y: number; id: number } | null = null

  private steady: Steady[] = []
  private sparks: Spark[] = []
  private ripples: Ripple[] = []
  private nextJoin = 1.2

  private canvas: HTMLCanvasElement
  private overlay: HTMLCanvasElement
  private options: GlassGlobeOptions

  private constructor(
    canvas: HTMLCanvasElement,
    overlay: HTMLCanvasElement,
    options: GlassGlobeOptions,
    gl: WebGL2RenderingContext,
    program: WebGLProgram,
  ) {
    this.canvas = canvas
    this.overlay = overlay
    this.options = options
    this.gl = gl
    this.program = program
    this.vao = gl.createVertexArray()!
    this.texture = gl.createTexture()!
    this.ctx2d = overlay.getContext('2d')
    for (const name of [
      'uInvVP', 'uOrient', 'uTime', 'uCrop', 'uClassicCount', 'uTotalCount', 'uSrcPos', 'uSrcRad', 'uLand',
    ]) {
      this.uniforms[name] = gl.getUniformLocation(program, name)
    }
    gl.useProgram(program)
    gl.uniformMatrix4fv(this.uniforms.uInvVP, false, inverseViewProjection())
    gl.uniform1f(this.uniforms.uCrop, NDC_CROP)
    gl.uniform1i(this.uniforms.uLand, 0)

    for (const [lat, lon] of PARTICIPANTS) this.addSteady(lat, lon, true)

    this.bindPointer()
    this.loadLand()
  }

  /** Returns null when WebGL2 (or the shader) is unavailable, so the caller can fall back. */
  static create(canvas: HTMLCanvasElement, overlay: HTMLCanvasElement, options: GlassGlobeOptions) {
    const gl = canvas.getContext('webgl2', { alpha: true, premultipliedAlpha: true, antialias: false })
    if (!gl) return null
    const program = compile(gl)
    if (!program) return null
    return new GlassGlobe(canvas, overlay, options, gl, program)
  }

  // MARK: Lifecycle

  /** Runs the loop only while on screen and the tab is visible. */
  setActive(active: boolean) {
    this.active = active
    if (active) this.kick()
  }

  destroy() {
    this.destroyed = true
    cancelAnimationFrame(this.raf)
    this.unbindPointer()
    const gl = this.gl
    gl.deleteTexture(this.texture)
    gl.deleteVertexArray(this.vao)
    gl.deleteProgram(this.program)
  }

  resize(cssSize: number) {
    const dpr = Math.min(window.devicePixelRatio || 1, 2)
    this.cssSize = cssSize
    const px = Math.max(1, Math.round(cssSize * dpr))
    for (const c of [this.canvas, this.overlay]) {
      if (c.width !== px) {
        c.width = px
        c.height = px
      }
    }
    this.gl.viewport(0, 0, px, px)
    this.kick(true)
  }

  private loadLand() {
    const img = new Image()
    img.decoding = 'async'
    img.onload = () => {
      if (this.destroyed) return
      const gl = this.gl
      gl.bindTexture(gl.TEXTURE_2D, this.texture)
      gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false)
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.R8, gl.RED, gl.UNSIGNED_BYTE, img)
      // No mipmaps: LINEAR both ways, so the dateline's atan jump can't choose a wrong mip.
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
      this.ready = true
      this.kick(true)
      this.options.onReady?.()
    }
    img.src = '/media/earth-land.jpg'
  }

  private looping() {
    return !this.options.reducedMotion || this.lastPointer !== null || Math.hypot(...this.momentum) > 1e-4
  }

  /** Starts the loop, or draws one still frame under reduced motion. */
  private kick(force = false) {
    if (!this.ready || this.destroyed) return
    cancelAnimationFrame(this.raf)
    if (this.active && this.looping()) {
      this.raf = requestAnimationFrame(this.frame)
    } else if (force || this.active) {
      this.raf = requestAnimationFrame(() => this.draw(this.now(), 0))
    }
  }

  private now() {
    return performance.now() / 1000 - this.start
  }

  private frame = () => {
    if (!this.active || this.destroyed) return
    const t = this.now()
    const dt = this.lastFrame === null ? 0 : Math.min(t - this.lastFrame, 0.1)
    this.lastFrame = t
    this.draw(t, dt)
    if (this.looping()) this.raf = requestAnimationFrame(this.frame)
    else this.lastFrame = null
  }

  // MARK: Simulation

  private advance(t: number, dt: number) {
    if (Math.hypot(...this.momentum) > 1e-4) {
      this.yaw += this.momentum[0] * dt
      const target = this.pitch + this.momentum[1] * dt
      const clamped = Math.min(Math.max(target, -PITCH_LIMIT), PITCH_LIMIT)
      if (clamped !== target) this.momentum[1] = 0
      this.pitch = clamped
      const perSecond = Math.pow(DAMPING, 60)
      const k = Math.pow(perSecond, dt)
      this.momentum = [this.momentum[0] * k, this.momentum[1] * k]
    } else {
      this.momentum = [0, 0]
    }

    const idleFor = t - this.lastInteraction
    if (!this.options.reducedMotion && idleFor > IDLE_AFTER && dt > 0 && !this.lastPointer) {
      const strength = Math.min(1, (idleFor - IDLE_AFTER) / 1.5)
      this.yaw += IDLE_DRIFT * dt * strength
      this.pitch = Math.min(
        Math.max(this.pitch + Math.cos(t * 0.097) * 0.04 * 0.097 * dt * strength, -PITCH_LIMIT),
        PITCH_LIMIT,
      )
    }
    this.yaw = ((this.yaw + Math.PI) % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI) - Math.PI

    if (this.options.reducedMotion) return

    // Presence lights lerp toward their targets; sparks age out.
    const k = 1 - Math.exp(-dt / LERP_TAU)
    for (const s of this.steady) s.current += (s.target - s.current) * k
    for (const s of this.sparks) s.age += dt
    this.sparks = this.sparks.filter((s) => s.age <= SPARK_LIFE)
    this.ripples = this.ripples.filter((r) => t - r.born <= RIPPLE_LIFE)

    this.nextJoin -= dt
    if (this.nextJoin <= 0) {
      this.nextJoin = 1.5 + Math.random() * 1.5
      this.join(t)
    }
  }

  /** Someone joins: a fresh presence light, a classic spark flare and a ripple ring. */
  private join(t: number) {
    const [lat, lon] = PARTICIPANTS[Math.floor(Math.random() * PARTICIPANTS.length)]
    const jLat = lat + (Math.random() - 0.5) * 6
    const jLon = lon + (Math.random() - 0.5) * 8
    const pos = unitVector(jLat, jLon)
    if (this.steady.length < STEADY_CAP) this.addSteady(jLat, jLon, false)
    if (this.sparks.length >= SPARK_CAP) this.sparks.shift()
    this.sparks.push({ pos, age: 0 })
    if (this.ripples.length >= RIPPLE_CAP) this.ripples.shift()
    this.ripples.push({ pos, born: t })
    this.options.onJoin?.()
  }

  private addSteady(lat: number, lon: number, seeded: boolean) {
    const count = 1 + Math.floor(Math.random() * 3)
    const target = 0.65 + 0.3 * Math.min(1, Math.log2(count) / 1.6)
    this.steady.push({
      pos: unitVector(lat, lon),
      sigma: Math.min(Math.max(0.034 + 0.014 * (count - 1) * 0.5, 0.018), 0.055),
      target,
      current: seeded ? target : 0,
      phase: Math.random() * Math.PI * 2,
    })
  }

  private orientation(): Mat3 {
    return mul3(rotZ(AXIAL_TILT), mul3(rotX(this.pitch), rotY(this.yaw)))
  }

  // MARK: Draw

  private draw(t: number, dt: number) {
    if (!this.ready || this.destroyed) return
    this.advance(t, dt)
    const gl = this.gl
    const orient = this.orientation()

    // Classic range: sparks (attack 120ms, exponential settle, whiteness decays first).
    let n = 0
    for (const s of this.sparks) {
      const intensity = smoothstep(0, 0.12, s.age) * Math.exp(-Math.max(0, s.age - 0.12) / 0.6) * SPARK_PEAK
      if (intensity <= 0.003) continue
      this.srcPos.set([...s.pos, intensity], n * 4)
      this.srcRad.set(
        [SPARK_RADIUS, smoothstep(0, 0.1, s.age) * Math.exp(-s.age / 0.45), 1 + SPARK_COLUMN_BOOST * Math.exp(-s.age / 0.45), 0],
        n * 4,
      )
      n++
    }
    const classicCount = n
    // Orb range: buried presence orbs that breathe (4s in, 6s out would be too literal per light;
    // each carries its own slow sine at the home-breath rate).
    for (const s of this.steady) {
      if (n >= MAX_SOURCES) break
      if (s.current <= 0.003) continue
      const breath = this.options.reducedMotion ? 1 : 1 + 0.13 * Math.sin(t * 0.63 + s.phase)
      this.srcPos.set([...s.pos, s.current * breath], n * 4)
      this.srcRad.set([s.sigma, 0, 2, 1], n * 4)
      n++
    }

    gl.useProgram(this.program)
    gl.bindVertexArray(this.vao)
    gl.activeTexture(gl.TEXTURE0)
    gl.bindTexture(gl.TEXTURE_2D, this.texture)
    gl.uniformMatrix3fv(this.uniforms.uOrient, false, orient)
    gl.uniform1f(this.uniforms.uTime, t)
    gl.uniform1i(this.uniforms.uClassicCount, classicCount)
    gl.uniform1i(this.uniforms.uTotalCount, n)
    gl.uniform4fv(this.uniforms.uSrcPos, this.srcPos)
    gl.uniform4fv(this.uniforms.uSrcRad, this.srcRad)
    gl.clearColor(0, 0, 0, 0)
    gl.clear(gl.COLOR_BUFFER_BIT)
    gl.drawArrays(gl.TRIANGLES, 0, 3)

    this.drawRipples(t, orient)
  }

  /** EarthHaloRipplesOverlay: a lavender ring and a softer blush ring, local to the join. */
  private drawRipples(t: number, orient: Mat3) {
    const ctx = this.ctx2d
    if (!ctx) return
    const w = this.overlay.width
    ctx.clearRect(0, 0, w, w)
    if (!this.ripples.length) return
    const scale = w / Math.max(this.cssSize, 1)
    const R = (w / 2) * GLOBE_FILL
    const cx = w / 2
    for (const r of this.ripples) {
      const age = t - r.born
      if (age < 0 || age > RIPPLE_LIFE) continue
      const [x, y, z] = r.pos
      const wx = orient[0] * x + orient[3] * y + orient[6] * z
      const wy = orient[1] * x + orient[4] * y + orient[7] * z
      const wz = orient[2] * x + orient[5] * y + orient[8] * z
      if (wz < -0.1) continue
      const visibility = smoothstep(-0.1, 0.25, wz)
      const p = age / RIPPLE_LIFE
      const ease = 1 - Math.pow(1 - p, 3)
      const radius = (RIPPLE_START + (RIPPLE_END - RIPPLE_START) * ease) * R
      const opacity = RIPPLE_OPACITY * (1 - p) * visibility
      const px = cx + wx * R
      const py = cx - wy * R
      ctx.lineWidth = 1.4 * scale
      ctx.strokeStyle = `rgb(184 167 232 / ${opacity})`
      ctx.beginPath()
      ctx.arc(px, py, radius, 0, Math.PI * 2)
      ctx.stroke()
      ctx.lineWidth = 0.8 * scale
      ctx.strokeStyle = `rgb(244 201 212 / ${opacity * 0.5})`
      ctx.beginPath()
      ctx.arc(px, py, radius * 0.85, 0, Math.PI * 2)
      ctx.stroke()
    }
  }

  // MARK: Pointer (drag to spin, arc-length correct at the orb's centre)

  private orbPixelRadius() {
    return Math.max(1, (this.cssSize / 2) * GLOBE_FILL)
  }

  private onDown = (e: PointerEvent) => {
    this.lastPointer = { x: e.clientX, y: e.clientY, id: e.pointerId }
    this.momentum = [0, 0]
    this.dragVelocity = [0, 0]
    this.lastInteraction = this.now()
    this.hit.setPointerCapture?.(e.pointerId)
    this.kick()
  }

  private onMove = (e: PointerEvent) => {
    const last = this.lastPointer
    if (!last || last.id !== e.pointerId) return
    const dx = e.clientX - last.x
    const dy = e.clientY - last.y
    this.lastPointer = { x: e.clientX, y: e.clientY, id: e.pointerId }
    const perPx = 1 / this.orbPixelRadius()
    const newPitch = Math.min(Math.max(this.pitch + dy * perPx, -PITCH_LIMIT), PITCH_LIMIT)
    const dYaw = dx * perPx
    const dPitch = newPitch - this.pitch
    this.yaw += dYaw
    this.pitch = newPitch
    this.dragVelocity = [dYaw * 60, dPitch * 60]
    this.lastInteraction = this.now()
  }

  private onUp = (e: PointerEvent) => {
    if (!this.lastPointer || this.lastPointer.id !== e.pointerId) return
    this.momentum = this.dragVelocity
    this.dragVelocity = [0, 0]
    this.lastPointer = null
    this.lastInteraction = this.now()
    this.lastFrame = null
    this.kick()
  }

  private get hit(): HTMLElement {
    return this.options.hitTarget ?? this.canvas
  }

  private bindPointer() {
    this.hit.addEventListener('pointerdown', this.onDown)
    this.hit.addEventListener('pointermove', this.onMove)
    this.hit.addEventListener('pointerup', this.onUp)
    this.hit.addEventListener('pointercancel', this.onUp)
  }

  private unbindPointer() {
    this.hit.removeEventListener('pointerdown', this.onDown)
    this.hit.removeEventListener('pointermove', this.onMove)
    this.hit.removeEventListener('pointerup', this.onUp)
    this.hit.removeEventListener('pointercancel', this.onUp)
  }
}

function compile(gl: WebGL2RenderingContext): WebGLProgram | null {
  const make = (type: number, src: string) => {
    const s = gl.createShader(type)!
    gl.shaderSource(s, src)
    gl.compileShader(s)
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
      console.warn('GlassGlobe shader:', gl.getShaderInfoLog(s))
      return null
    }
    return s
  }
  const vs = make(gl.VERTEX_SHADER, VERTEX)
  const fs = make(gl.FRAGMENT_SHADER, FRAGMENT)
  if (!vs || !fs) return null
  const program = gl.createProgram()!
  gl.attachShader(program, vs)
  gl.attachShader(program, fs)
  gl.linkProgram(program)
  gl.deleteShader(vs)
  gl.deleteShader(fs)
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    console.warn('GlassGlobe link:', gl.getProgramInfoLog(program))
    return null
  }
  return program
}
