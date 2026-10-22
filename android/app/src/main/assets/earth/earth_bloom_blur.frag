// Bloom, passes 2 and 3 — iOS `earthBloomBlurHFragment` and
// `earthBloomBlurVFragment` as one program: a separable 9-tap gaussian whose
// axis is [uDirection] — (1, 0) for the horizontal pass, (0, 1) for the
// vertical. The step is in source texels × the tuning's blur step scale, a
// wide, soft, atmospheric bloom.

in vec2 vNdc;
layout(location = 0) out vec4 fragColor;

uniform highp sampler2D src;
uniform vec2 uDirection;

const float BLUR_WEIGHTS[5] = float[5](
  0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216
);

void main() {
  vec2 uv = vNdc * 0.5 + 0.5;
  vec2 texel = 1.0 / vec2(textureSize(src, 0));
  vec2 stepUv = uDirection * texel * T.bloomA.z;
  vec4 acc = texture(src, uv) * BLUR_WEIGHTS[0];
  for (int i = 1; i < 5; ++i) {
    vec2 off = stepUv * float(i);
    acc += texture(src, uv + off) * BLUR_WEIGHTS[i];
    acc += texture(src, uv - off) * BLUR_WEIGHTS[i];
  }
  fragColor = acc;
}
