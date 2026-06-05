import SwiftUI

/// A procedural plant illustration for a garden growth stage. Drawn entirely in
/// a `Canvas` from gradients and simple paths so it scales crisply at any tile
/// size — the same "shapes, never bitmaps" approach the app uses for
/// `SoundArtwork`.
struct PlantArtwork: View {
  let kind: PlantKind
  var leaf: Color = GardenColor.sage
  var leafLight: Color = GardenColor.meadow
  var stem: Color = GardenColor.fern
  var blossom: Color = DeepColor.blushPowder

  var body: some View {
    Canvas { context, size in
      let w = size.width
      let h = size.height
      let cx = w / 2
      let baseY = h * 0.88
      let s = min(w, h)

      // Soft ground shadow grounding the plant.
      let shadow = Path(ellipseIn: CGRect(
        x: cx - s * 0.24, y: baseY - s * 0.025,
        width: s * 0.48, height: s * 0.10
      ))
      context.fill(shadow, with: .color(GardenColor.soil.opacity(0.22)))

      switch kind {
      case .seedling: drawSeedling(&context, cx: cx, baseY: baseY, s: s)
      case .sprout:   drawSprout(&context, cx: cx, baseY: baseY, s: s)
      case .bloom:    drawBloom(&context, cx: cx, baseY: baseY, s: s)
      case .tree:     drawTree(&context, cx: cx, baseY: baseY, s: s)
      }
    }
  }

  // MARK: - Stages

  private func drawSeedling(_ ctx: inout GraphicsContext, cx: CGFloat, baseY: CGFloat, s: CGFloat) {
    let topY = baseY - s * 0.30
    strokeStem(&ctx, from: CGPoint(x: cx, y: baseY), to: CGPoint(x: cx, y: topY), width: s * 0.045)

    let pair = CGPoint(x: cx, y: topY + s * 0.02)
    ctx.fill(GardenShapes.leaf(length: s * 0.26, width: s * 0.15, angle: -0.7, at: pair), with: .color(leaf))
    ctx.fill(GardenShapes.leaf(length: s * 0.26, width: s * 0.15, angle: 0.7, at: pair), with: .color(leafLight))
  }

  private func drawSprout(_ ctx: inout GraphicsContext, cx: CGFloat, baseY: CGFloat, s: CGFloat) {
    let topY = baseY - s * 0.52
    var stemPath = Path()
    stemPath.move(to: CGPoint(x: cx, y: baseY))
    stemPath.addQuadCurve(to: CGPoint(x: cx, y: topY), control: CGPoint(x: cx + s * 0.10, y: (baseY + topY) / 2))
    ctx.stroke(stemPath, with: .color(stem), style: StrokeStyle(lineWidth: s * 0.045, lineCap: .round))

    // Lower and upper leaf pairs.
    let low = CGPoint(x: cx, y: baseY - s * 0.20)
    ctx.fill(GardenShapes.leaf(length: s * 0.22, width: s * 0.12, angle: -1.0, at: low), with: .color(leaf))
    ctx.fill(GardenShapes.leaf(length: s * 0.20, width: s * 0.11, angle: 1.0, at: low), with: .color(leafLight))

    let high = CGPoint(x: cx, y: baseY - s * 0.38)
    ctx.fill(GardenShapes.leaf(length: s * 0.24, width: s * 0.13, angle: -0.55, at: high), with: .color(leafLight))
    ctx.fill(GardenShapes.leaf(length: s * 0.24, width: s * 0.13, angle: 0.55, at: high), with: .color(leaf))

    // Closed bud at the tip.
    let bud = Path(ellipseIn: CGRect(x: cx - s * 0.05, y: topY - s * 0.06, width: s * 0.10, height: s * 0.14))
    ctx.fill(bud, with: .color(leafLight))
  }

  private func drawBloom(_ ctx: inout GraphicsContext, cx: CGFloat, baseY: CGFloat, s: CGFloat) {
    let topY = baseY - s * 0.50
    var stemPath = Path()
    stemPath.move(to: CGPoint(x: cx, y: baseY))
    stemPath.addQuadCurve(to: CGPoint(x: cx, y: topY), control: CGPoint(x: cx - s * 0.08, y: (baseY + topY) / 2))
    ctx.stroke(stemPath, with: .color(stem), style: StrokeStyle(lineWidth: s * 0.045, lineCap: .round))

    let mid = CGPoint(x: cx, y: baseY - s * 0.24)
    ctx.fill(GardenShapes.leaf(length: s * 0.22, width: s * 0.12, angle: -1.1, at: mid), with: .color(leaf))
    ctx.fill(GardenShapes.leaf(length: s * 0.20, width: s * 0.11, angle: 1.1, at: mid), with: .color(leafLight))

    // Flower — five petals around a warm centre.
    let center = CGPoint(x: cx, y: topY)
    let petalColors = [blossom, DeepColor.softLilac, blossom, DeepColor.softLilac, blossom]
    for i in 0..<5 {
      let angle = CGFloat(i) * (.pi * 2 / 5)
      let petal = GardenShapes.leaf(length: s * 0.20, width: s * 0.12, angle: angle, at: center)
      ctx.fill(petal, with: .color(petalColors[i].opacity(0.95)))
    }
    let core = Path(ellipseIn: CGRect(x: center.x - s * 0.06, y: center.y - s * 0.06, width: s * 0.12, height: s * 0.12))
    ctx.fill(core, with: .color(DeepColor.peachCloud))
  }

  private func drawTree(_ ctx: inout GraphicsContext, cx: CGFloat, baseY: CGFloat, s: CGFloat) {
    let crownY = baseY - s * 0.50
    strokeStem(&ctx, from: CGPoint(x: cx, y: baseY), to: CGPoint(x: cx, y: crownY + s * 0.10), width: s * 0.075, color: GardenColor.soil)

    // Layered canopy from overlapping discs.
    let crowns: [(CGFloat, CGFloat, CGFloat, Color)] = [
      (cx - s * 0.16, crownY + s * 0.06, s * 0.20, leaf),
      (cx + s * 0.16, crownY + s * 0.06, s * 0.20, leaf),
      (cx, crownY - s * 0.04, s * 0.26, leafLight),
      (cx, crownY + s * 0.10, s * 0.22, leaf)
    ]
    for (x, y, r, color) in crowns {
      let disc = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
      ctx.fill(disc, with: .color(color.opacity(0.95)))
    }
    // Soft highlight.
    let highlight = Path(ellipseIn: CGRect(x: cx - s * 0.04, y: crownY - s * 0.10, width: s * 0.16, height: s * 0.16))
    ctx.fill(highlight, with: .color(GardenColor.meadow.opacity(0.7)))
  }

  // MARK: - Helpers

  private func strokeStem(
    _ ctx: inout GraphicsContext,
    from: CGPoint,
    to: CGPoint,
    width: CGFloat,
    color: Color? = nil
  ) {
    var path = Path()
    path.move(to: from)
    path.addLine(to: to)
    ctx.stroke(path, with: .color(color ?? stem), style: StrokeStyle(lineWidth: width, lineCap: .round))
  }
}

#Preview("Plant stages") {
  HStack(spacing: 12) {
    ForEach(PlantKind.allCases, id: \.self) { kind in
      PlantArtwork(kind: kind)
        .frame(width: 80, height: 100)
        .background(DeepColor.moonCream, in: RoundedRectangle(cornerRadius: 16))
    }
  }
  .padding()
  .background(DeepColor.softLilac.opacity(0.3))
}
