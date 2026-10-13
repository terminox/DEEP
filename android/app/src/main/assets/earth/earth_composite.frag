// Bloom, pass 4 — iOS `earthCompositeFragment`: the HDR scene plus its
// blurred bloom, tonemapped to keep palette hue, dithered, written to the
// window. `earth_tonemap.glsl` is prepended.
//
// Straight (not premultiplied) colour with an independent alpha, exactly as
// iOS writes it. The compositor treats the TextureView's buffer as
// premultiplied, as Core Animation treats the drawable; it reads right
// because emissive tracks alpha by construction — do not "fix" it
// (EARTH3D_SPIKE.md §2.5).

in vec2 vNdc;
layout(location = 0) out vec4 fragColor;

uniform highp sampler2D scene;
uniform highp sampler2D bloom;
// Dither amplitude in 8-bit steps: 1 / render scale (the upscale smooths it).
uniform float uDither;

void main() {
  vec2 uv = vNdc * 0.5 + 0.5;

  vec4 sBase = texture(scene, uv);
  vec3 sceneColor = sBase.rgb;
  float alpha = sBase.a;

  // Additive HDR bloom: generous radius, modest strength.
  vec3 bloomColor = texture(bloom, uv).rgb * T.bloomA.w;
  // Bloom is light spilling into the air past the silhouette: lift alpha by
  // its visible luminance.
  float bloomLuma = dot(bloomColor, vec3(0.2126, 0.7152, 0.0722));
  alpha = clamp(alpha + (1.0 - exp(-bloomLuma)) * T.bloomB.y, 0.0, 1.0);

  vec3 hdrSum = sceneColor + bloomColor;
  vec3 finalColor = tonemapPalette(hdrSum, T.bloomB.x);

  // Dither masks 8-bit banding in the lavender → cream gradient.
  float d = (dither13(gl_FragCoord.xy) - 0.5) * (uDither / 255.0);
  finalColor += d;

  fragColor = vec4(finalColor, alpha);
}
