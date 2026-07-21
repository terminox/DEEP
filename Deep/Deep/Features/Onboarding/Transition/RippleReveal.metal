#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Layer effect behind the welcome screen's send-off (`RippleRevealOverlay`).
///
/// A circular wavefront expands from `origin` until it has swallowed the whole
/// layer. Behind the front the layer dissolves to transparent (revealing the
/// screen already pushed beneath the overlay); at the front pixels refract
/// radially like disturbed water, faint trailing wavelets run ahead of it, and
/// the crest catches a soft `glow` shimmer. At progress 0 the effect is the
/// identity, so the overlay appears seamlessly over the live screen before the
/// wave sets out; by progress 1 the water has calmed and nothing remains.
[[ stitchable ]] half4 rippleReveal(
  float2 position,
  SwiftUI::Layer layer,
  float2 origin,
  float2 size,
  float progress,
  half4 glow
) {
  const float feather = 150.0;   // width of the dissolving band behind the front
  const float wavelength = 34.0; // radial ripple frequency divisor
  const float amplitude = 9.0;   // peak refraction offset, in points
  const float reach = 120.0;     // how far ahead of the front the wavelets travel

  // The farthest corner fixes the radius at which the layer is fully
  // swallowed, so progress 1 always clears the screen wherever the tap was.
  float2 farCorner = max(origin, size - origin);
  float travel = length(farCorner) + feather;
  float ahead = distance(position, origin) - progress * travel;

  if (ahead < -feather) {
    return half4(0.0);
  }

  // Zero at both ends: the first frame matches the untouched screen exactly,
  // and the water has calmed by the time the wave exits.
  float life = smoothstep(0.0, 0.08, progress) * (1.0 - smoothstep(0.7, 1.0, progress));

  float envelope = exp(-max(ahead, 0.0) / reach) * life;
  float2 radial = normalize(position - origin + float2(0.0001, 0.0001));
  half4 color = layer.sample(position + radial * sin(ahead / wavelength) * amplitude * envelope);

  // Shimmer on the crest. `color` is premultiplied, so the glow is scaled by
  // the sampled alpha to stay premultiplied-correct.
  float crest = exp(-abs(ahead) / 60.0) * life;
  color.rgb = mix(color.rgb, glow.rgb * color.a, half(crest * 0.22));

  // Dissolve across the trailing band.
  float alpha = smoothstep(-feather, -feather * 0.12, ahead);
  return color * half(alpha);
}
