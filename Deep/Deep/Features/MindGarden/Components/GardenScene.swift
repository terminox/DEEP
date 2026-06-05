import SwiftUI

/// The full-bleed atmospheric header for the Mind Garden home — a calm dawn over
/// still water, framed by soft foliage. Rendered procedurally in a `Canvas` from
/// gradients and shapes (no bitmaps), echoing the reference's serene
/// garden-at-sunrise mood while staying native to the Deep palette.
struct GardenScene: View {
  var body: some View {
    Canvas { context, size in
      let w = size.width
      let h = size.height
      let horizon = h * 0.60

      drawSky(&context, w: w, horizon: horizon)
      drawSun(&context, w: w, horizon: horizon)
      drawHills(&context, w: w, h: h, horizon: horizon)
      drawWater(&context, w: w, h: h, horizon: horizon)
      drawReflection(&context, w: w, h: h, horizon: horizon)
      drawHorizonShimmer(&context, w: w, horizon: horizon)
      drawFoliage(&context, w: w, h: h)
    }
  }

  // MARK: - Layers

  private func drawSky(_ ctx: inout GraphicsContext, w: CGFloat, horizon: CGFloat) {
    let sky = Path(CGRect(x: 0, y: 0, width: w, height: horizon + 1))
    ctx.fill(sky, with: .linearGradient(
      Gradient(colors: [DeepColor.skyWash, DeepColor.softLilac, DeepColor.blushPowder, DeepColor.peachCloud]),
      startPoint: CGPoint(x: w / 2, y: 0),
      endPoint: CGPoint(x: w / 2, y: horizon)
    ))
  }

  private func drawSun(_ ctx: inout GraphicsContext, w: CGFloat, horizon: CGFloat) {
    let center = CGPoint(x: w * 0.5, y: horizon * 0.66)

    let halo = Path(ellipseIn: CGRect(x: center.x - w * 0.55, y: center.y - w * 0.55, width: w * 1.1, height: w * 1.1))
    ctx.fill(halo, with: .radialGradient(
      Gradient(colors: [Color.white.opacity(0.55), DeepColor.peachCloud.opacity(0)]),
      center: center, startRadius: 0, endRadius: w * 0.55
    ))

    let disc = Path(ellipseIn: CGRect(x: center.x - w * 0.13, y: center.y - w * 0.13, width: w * 0.26, height: w * 0.26))
    ctx.fill(disc, with: .radialGradient(
      Gradient(colors: [Color.white, DeepColor.moonCream.opacity(0)]),
      center: center, startRadius: 0, endRadius: w * 0.16
    ))
  }

  private func drawHills(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, horizon: CGFloat) {
    let left = Path(ellipseIn: CGRect(x: -w * 0.12, y: horizon - h * 0.11, width: w * 0.72, height: h * 0.24))
    ctx.fill(left, with: .color(GardenColor.sage.opacity(0.32)))

    let right = Path(ellipseIn: CGRect(x: w * 0.44, y: horizon - h * 0.08, width: w * 0.74, height: h * 0.20))
    ctx.fill(right, with: .color(GardenColor.fern.opacity(0.26)))
  }

  private func drawWater(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, horizon: CGFloat) {
    let water = Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon))
    ctx.fill(water, with: .linearGradient(
      Gradient(colors: [DeepColor.peachCloud.opacity(0.9), DeepColor.softLilac, DeepColor.lavenderMist]),
      startPoint: CGPoint(x: w / 2, y: horizon),
      endPoint: CGPoint(x: w / 2, y: h)
    ))
  }

  private func drawReflection(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, horizon: CGFloat) {
    let streak = Path(roundedRect: CGRect(
      x: w * 0.5 - w * 0.05, y: horizon,
      width: w * 0.10, height: (h - horizon) * 0.85
    ), cornerRadius: w * 0.05)
    ctx.fill(streak, with: .linearGradient(
      Gradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0)]),
      startPoint: CGPoint(x: 0, y: horizon),
      endPoint: CGPoint(x: 0, y: h)
    ))
  }

  private func drawHorizonShimmer(_ ctx: inout GraphicsContext, w: CGFloat, horizon: CGFloat) {
    let line = Path(CGRect(x: 0, y: horizon - 1, width: w, height: 2))
    ctx.fill(line, with: .color(Color.white.opacity(0.35)))
  }

  /// Soft, blurred leaves anchoring the lower corners — the "garden" framing.
  /// Kept short and lightly saturated so they read as foliage accents rather
  /// than muddy shapes where they sit over the lavender water.
  private func drawFoliage(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
    var blurred = ctx
    blurred.addFilter(.blur(radius: w * 0.014))

    // Lower-left cluster.
    blurred.fill(GardenShapes.leaf(length: h * 0.24, width: w * 0.085, angle: 0.45, at: CGPoint(x: w * 0.04, y: h * 1.03)), with: .color(GardenColor.sage.opacity(0.72)))
    blurred.fill(GardenShapes.leaf(length: h * 0.17, width: w * 0.065, angle: 0.85, at: CGPoint(x: w * 0.12, y: h * 1.03)), with: .color(GardenColor.meadow.opacity(0.68)))

    // Lower-right cluster.
    blurred.fill(GardenShapes.leaf(length: h * 0.22, width: w * 0.08, angle: -0.45, at: CGPoint(x: w * 0.96, y: h * 1.03)), with: .color(GardenColor.sage.opacity(0.72)))
    blurred.fill(GardenShapes.leaf(length: h * 0.15, width: w * 0.06, angle: -0.8, at: CGPoint(x: w * 0.88, y: h * 1.03)), with: .color(GardenColor.meadow.opacity(0.62)))
  }
}

#Preview("Garden scene") {
  GardenScene()
    .frame(height: 320)
    .ignoresSafeArea()
}
