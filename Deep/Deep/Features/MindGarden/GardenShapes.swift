import SwiftUI

/// Reusable vector primitives shared by the garden's procedural artwork — the
/// hero scene (`GardenScene`) and the growth-stage plants (`PlantArtwork`) both
/// draw their leaves from the same almond path so foliage reads consistently.
enum GardenShapes {
  /// An almond-shaped leaf that points "up" (toward negative Y) from its origin,
  /// then rotated by `angle` and moved to `point`. Returned pre-positioned so it
  /// can be filled directly into a `GraphicsContext`.
  static func leaf(
    length: CGFloat,
    width: CGFloat,
    angle: CGFloat = 0,
    at point: CGPoint = .zero
  ) -> Path {
    var path = Path()
    path.move(to: .zero)
    path.addQuadCurve(to: CGPoint(x: 0, y: -length), control: CGPoint(x: width, y: -length * 0.5))
    path.addQuadCurve(to: .zero, control: CGPoint(x: -width, y: -length * 0.5))
    let transform = CGAffineTransform(rotationAngle: angle)
      .concatenating(CGAffineTransform(translationX: point.x, y: point.y))
    return path.applying(transform)
  }
}
