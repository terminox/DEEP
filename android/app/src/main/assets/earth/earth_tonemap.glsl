// The display transform shared by the composite pass and the bloom-less
// direct surface pass — iOS `EarthBloom.metal`'s `tonemapPalette` and
// `dither13`, unchanged.

// Luminance-preserving tonemap: compress only the brightness, leave chroma,
// so palette colours never flatten to white at high intensity. Any channel
// still over 1.0 is then pulled softly toward white — a palette rescue so a
// saturated lavender keeps its blue at the 8-bit boundary.
vec3 tonemapPalette(vec3 x, float k) {
  float luma = dot(x, vec3(0.2126, 0.7152, 0.0722));
  if (luma < 1e-5) return x;
  float compressed = 1.0 - exp(-luma * k);
  vec3 result = x * (compressed / luma);
  float maxC = max(max(result.r, result.g), result.b);
  if (maxC > 1.0) {
    float t = clamp((maxC - 1.0) * 0.8, 0.0, 1.0);
    result = mix(result, vec3(1.0), t * 0.35);
    result = min(result, vec3(1.0));
  }
  return result;
}

// A tiny hash in [0, 1), for the anti-banding dither.
float dither13(vec2 p) {
  vec3 q = fract(vec3(p.x * 0.1031, p.y * 0.103, (p.x + p.y) * 0.0973));
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}
