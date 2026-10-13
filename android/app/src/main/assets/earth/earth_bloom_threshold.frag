// Bloom, pass 1 — iOS `earthBloomThresholdFragment`.
//
// A soft luminance threshold tuned for the pastel palette: lavender and blush
// at full saturation sit at luma ~0.65–0.75, so the band must catch them or
// continents render coloured with no halo.
//
// No y flip: Metal's texture origin is top-left and needed `uv.y = 1 − uv.y`;
// GL's is bottom-left, already agreeing with NDC. Keeping the flip would
// mirror the whole bloom chain.

in vec2 vNdc;
layout(location = 0) out vec4 fragColor;

uniform highp sampler2D src;

void main() {
  vec2 uv = vNdc * 0.5 + 0.5;
  vec4 c = texture(src, uv);
  float luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
  float weight = smoothstep(T.bloomA.x, T.bloomA.y, luma);
  fragColor = vec4(c.rgb * weight, c.a);
}
