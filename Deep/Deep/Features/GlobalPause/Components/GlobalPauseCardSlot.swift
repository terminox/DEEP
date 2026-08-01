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

  /// Seats the card unless someone else legitimately holds it. Free means
  /// unparented or sitting in a *different* feed slot — a stale seat SwiftUI
  /// has discarded (adding re-parents it out). Any other superview is the
  /// lobby or the transition container mid-flight, and must never be robbed.
  func adoptIfFree(_ card: GlobalPauseCardView) {
    guard card.superview !== self else { return }
    self.card = card
    if card.superview == nil || card.superview is GlobalPauseCardSlotView {
      adopt(card)
    } else {
      // The lobby holds the card; still mark this live seat as the landing
      // target so the dismiss flight comes home here, not to a discarded slot.
      card.homeSlot = self
    }
  }

  /// Re-entry re-attaches this seat to a window without any SwiftUI update
  /// pass; reclaim here so the card never waits for a data-driven tick.
  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil, let card else { return }
    adoptIfFree(card)
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

/// SwiftUI seat for the coordinator-owned card. Adoption is guarded (see
/// `adoptIfFree`) so a SwiftUI remount can never yank the card back while the
/// lobby holds it — but a remount that strands the card in a discarded slot
/// is reclaimed immediately instead of leaving the seat empty until the next
/// data-driven update pass.
struct GlobalPauseCardSlot: UIViewRepresentable {
  let card: GlobalPauseCardView

  func makeUIView(context: Context) -> GlobalPauseCardSlotView {
    let slot = GlobalPauseCardSlotView()
    slot.adoptIfFree(card)
    return slot
  }

  func updateUIView(_ uiView: GlobalPauseCardSlotView, context: Context) {
    uiView.adoptIfFree(card)
  }

  static func dismantleUIView(_ uiView: GlobalPauseCardSlotView, coordinator: ()) {
    // Never leave the card attached to a dead seat — a stale superview would
    // block (pre-`adoptIfFree`) or delay adoption by the replacement slot.
    if let card = uiView.card, card.superview === uiView {
      card.removeFromSuperview()
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
