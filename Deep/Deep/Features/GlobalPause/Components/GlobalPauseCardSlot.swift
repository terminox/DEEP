import UIKit
import SwiftUI

/// The card's seat in the SwiftUI feed. Owns the card's drop shadow (the card
/// clips to its rounded corners, so the shadow must live one level up) and is
/// the fixed point the card-lift transition flies from and lands on: the
/// present animator steals the card from here, the dismiss animator hands it
/// back via `adopt`.
final class GlobalPauseCardSlotView: UIView {
  private(set) weak var card: GlobalPauseCardView?

  override init(frame: CGRect) {
    super.init(frame: frame)
    layer.shadowColor = UIColor.lavenderMist.withAlphaComponent(0.25).cgColor
    layer.shadowOpacity = 1
    layer.shadowRadius = 24
    layer.shadowOffset = CGSize(width: 0, height: 12)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func adopt(_ card: GlobalPauseCardView) {
    self.card = card
    card.homeSlot = self
    card.frame = bounds
    card.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(card)
  }

  /// The live on-screen rect the transition flies from / lands on.
  var frameInWindow: CGRect? {
    window.map { convert(bounds, to: $0) }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: .card).cgPath
  }
}

/// SwiftUI seat for the coordinator-owned card. Adoption is guarded so a
/// SwiftUI remount can never yank the card back while the lobby holds it.
struct GlobalPauseCardSlot: UIViewRepresentable {
  let card: GlobalPauseCardView

  func makeUIView(context: Context) -> GlobalPauseCardSlotView {
    let slot = GlobalPauseCardSlotView()
    if card.superview == nil {
      slot.adopt(card)
    }
    return slot
  }

  func updateUIView(_ uiView: GlobalPauseCardSlotView, context: Context) {
    if card.superview == nil {
      uiView.adopt(card)
    }
  }
}

#Preview("Card in its slot") {
  let scene = GlobalPauseEarthScene.preview
  let card = GlobalPauseCardView(scene: scene)
  let slot = GlobalPauseCardSlotView()
  slot.adopt(card)

  let container = UIView()
  container.backgroundColor = .moonCream
  slot.frame = CGRect(x: 20, y: 100, width: 350, height: 200)
  container.addSubview(slot)
  return container
}
