import UIKit
import SwiftUI

/// Layer-backed gradient views.
///
/// Every gradient in UIKit code MUST be one of these views — never a
/// standalone `CAGradientLayer` sublayer. Standalone sublayers do not inherit
/// `UIView` animation blocks, so they snap to their final geometry while
/// everything around them animates — fatal inside the card-lift transition.
/// A layer-backed view's gradient rides UIView animations like any other view.

/// A radial gradient filling the view from its centre to its edges. Size the
/// *frame* to control the bloom radius (a square frame yields a circle).
final class RadialGradientView: UIView {
  override class var layerClass: AnyClass { CAGradientLayer.self }

  private var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }

  init(colors: [UIColor], locations: [NSNumber]? = nil) {
    super.init(frame: .zero)
    isUserInteractionEnabled = false
    gradientLayer.type = .radial
    gradientLayer.colors = colors.map(\.cgColor)
    gradientLayer.locations = locations
    gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
    gradientLayer.endPoint = CGPoint(x: 1, y: 1)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

/// An axial gradient between two unit-space points.
final class LinearGradientView: UIView {
  override class var layerClass: AnyClass { CAGradientLayer.self }

  private var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }

  init(
    colors: [UIColor],
    startPoint: CGPoint = CGPoint(x: 0.5, y: 0),
    endPoint: CGPoint = CGPoint(x: 0.5, y: 1),
    locations: [NSNumber]? = nil
  ) {
    super.init(frame: .zero)
    isUserInteractionEnabled = false
    gradientLayer.colors = colors.map(\.cgColor)
    gradientLayer.startPoint = startPoint
    gradientLayer.endPoint = endPoint
    gradientLayer.locations = locations
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

#Preview("Gradient views") {
  let container = UIView()
  container.backgroundColor = .moonCream

  let radial = RadialGradientView(colors: [.softLilac, .softLilac.withAlphaComponent(0)])
  radial.frame = CGRect(x: 40, y: 80, width: 240, height: 240)
  container.addSubview(radial)

  let linear = LinearGradientView(
    colors: [.lavenderMist, .blushPowder],
    startPoint: CGPoint(x: 0, y: 0.5),
    endPoint: CGPoint(x: 1, y: 0.5)
  )
  linear.frame = CGRect(x: 40, y: 360, width: 240, height: 56)
  linear.layer.cornerRadius = 28
  linear.clipsToBounds = true
  container.addSubview(linear)

  return container
}
