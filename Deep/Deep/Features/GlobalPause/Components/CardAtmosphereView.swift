import UIKit
import SwiftUI

/// UIKit twin of the retired SwiftUI `CardAtmosphere`: a **scale-invariant**
/// atmosphere for the Global Pause card — a `moonCream` base with centered,
/// size-relative blooms, so it reads identically at 200pt card scale and at
/// full-screen lobby scale, and morphs smoothly between them (every bloom is a
/// layer-backed gradient view, so the whole background rides the card-lift
/// animation frame-for-frame).
final class CardAtmosphereView: UIView {
  private let lilacBloom = RadialGradientView(
    colors: [.softLilac.withAlphaComponent(0.55), .softLilac.withAlphaComponent(0)]
  )
  private let blushBloom = RadialGradientView(
    colors: [.blushPowder.withAlphaComponent(0.32), .blushPowder.withAlphaComponent(0)]
  )

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    backgroundColor = .moonCream
    addSubview(lilacBloom)
    addSubview(blushBloom)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let side = min(bounds.width, bounds.height)

    // Centered lilac bloom — endRadius 0.85·side in the SwiftUI original.
    let lilacSide = side * 1.7
    lilacBloom.frame = CGRect(
      x: bounds.midX - lilacSide / 2,
      y: bounds.midY - lilacSide / 2,
      width: lilacSide,
      height: lilacSide
    )

    // Blush lift from just below the bottom edge — endRadius 0.7·side.
    let blushSide = side * 1.4
    blushBloom.frame = CGRect(
      x: bounds.midX - blushSide / 2,
      y: bounds.height * 1.05 - blushSide / 2,
      width: blushSide,
      height: blushSide
    )
  }
}

#Preview("CardAtmosphere — card vs full") {
  let container = UIView()
  container.backgroundColor = .white

  let card = CardAtmosphereView()
  card.frame = CGRect(x: 20, y: 60, width: 350, height: 200)
  card.layer.cornerRadius = 24
  card.layer.cornerCurve = .continuous
  card.clipsToBounds = true
  container.addSubview(card)

  let full = CardAtmosphereView()
  full.frame = CGRect(x: 20, y: 300, width: 350, height: 500)
  full.clipsToBounds = true
  container.addSubview(full)

  return container
}
