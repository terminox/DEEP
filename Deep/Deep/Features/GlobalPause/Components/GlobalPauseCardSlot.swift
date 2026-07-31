import UIKit
import SwiftUI

/// The card's seat in the SwiftUI feed. Owns the card's drop shadow (the card
/// clips to its rounded corners, so the shadow must live one level up) and is
/// the fixed point the card-lift transition flies from and lands on: the
/// present animator steals the card from here, the dismiss animator hands it
/// back via `adopt`.
///
/// There is one card but there can be several seats. The `.home` seat (the
/// Global Pause feed) adopts the card whenever it is free. A `.guest` seat
/// (Fuku's Lounge, presented over the feed) *borrows* it: it steals the card
/// once its own presentation has settled — so the feed keeps its card for the
/// whole zoom-open — and hands it back to the seat it came from when it leaves
/// the window. While the guest holds the card, `homeSlot` points at the guest,
/// so the card-lift transition naturally flies from and lands on the lounge.
final class GlobalPauseCardSlotView: UIView {
  enum Role {
    case home
    case guest
  }

  let role: Role
  private(set) weak var card: GlobalPauseCardView?

  /// The card this seat exists for, whether or not it is currently seated here.
  private weak var servedCard: GlobalPauseCardView?
  /// Guest only: the seat the card was borrowed from, and returns to.
  private weak var returnSlot: GlobalPauseCardSlotView?

  init(role: Role = .home) {
    self.role = role
    super.init(frame: .zero)
    layer.shadowColor = UIColor.lavenderMist.withAlphaComponent(0.25).cgColor
    // Occupancy-driven (see didAddSubview/willRemoveSubview): an empty seat
    // must not draw a floating shadow while its card is away.
    layer.shadowOpacity = 0
    layer.shadowRadius = 24
    layer.shadowOffset = CGSize(width: 0, height: 12)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func adopt(_ card: GlobalPauseCardView) {
    self.card = card
    servedCard = card
    card.homeSlot = self
    card.frame = bounds
    card.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(card)
  }

  /// Points the seat at its card. `.home` adopts immediately when the card is
  /// free (a SwiftUI remount can never yank it back while another seat holds
  /// it); `.guest` waits for `didMoveToWindow` to borrow it.
  func serve(_ card: GlobalPauseCardView) {
    servedCard = card
    switch role {
    case .home:
      if card.superview == nil {
        adopt(card)
      }
    case .guest:
      break
    }
  }

  /// Guest only: returns the borrowed card to the seat it came from. Safe to
  /// call at any time; if the card is out flying in a lobby, only its landing
  /// target is retargeted home so a later handoff cannot land on a dead seat.
  func handBackCard() {
    guard role == .guest, let servedCard, let returnSlot else { return }
    if servedCard.superview === self {
      returnSlot.adopt(servedCard)
      servedCard.applyRestState(isLobby: false)
      // The handoff lands as the pop settles — ease the home seat back in
      // (card and shadow together) instead of popping it into a still screen.
      returnSlot.alpha = 0
      UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut]) {
        returnSlot.alpha = 1
      }
    } else if servedCard.homeSlot === self {
      servedCard.homeSlot = returnSlot
    }
  }

  /// The live on-screen rect the transition flies from / lands on.
  var frameInWindow: CGRect? {
    window.map { convert(bounds, to: $0) }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: .card).cgPath
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard role == .guest, window != nil else { return }
    borrowWhenSettled()
  }

  override func willMove(toWindow newWindow: UIWindow?) {
    super.willMove(toWindow: newWindow)
    guard role == .guest, newWindow == nil else { return }
    handBackCard()
  }

  // MARK: - Occupancy shadow

  override func didAddSubview(_ subview: UIView) {
    super.didAddSubview(subview)
    if subview === card {
      layer.shadowOpacity = 1
    }
  }

  override func willRemoveSubview(_ subview: UIView) {
    super.willRemoveSubview(subview)
    if subview === card {
      layer.shadowOpacity = 0
    }
  }

  // MARK: - Guest borrowing

  /// Steals the card once the presentation carrying this seat has settled, so
  /// the seat underneath keeps its card until its view leaves the window and
  /// the emptying is invisible.
  private func borrowWhenSettled() {
    guard let servedCard, servedCard.homeSlot !== self else { return }
    returnSlot = servedCard.homeSlot
    if let transition = nearestViewController()?.transitionCoordinator {
      transition.animate(alongsideTransition: nil) { [weak self] _ in
        self?.borrowServedCard()
      }
    } else {
      borrowServedCard()
    }
  }

  private func borrowServedCard() {
    guard window != nil, let servedCard, servedCard.homeSlot !== self else { return }
    adopt(servedCard)
    // The borrow lands only after the host's presentation has settled — ease
    // the whole seat in (card and shadow together) instead of popping it into
    // an already-still screen.
    alpha = 0
    UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut]) {
      self.alpha = 1
    }
  }

  private func nearestViewController() -> UIViewController? {
    var responder: UIResponder? = next
    while let current = responder {
      if let controller = current as? UIViewController { return controller }
      responder = current.next
    }
    return nil
  }
}

/// SwiftUI seat for the coordinator-owned card. Adoption is guarded so a
/// SwiftUI remount can never yank the card back while another seat or the
/// lobby holds it.
struct GlobalPauseCardSlot: UIViewRepresentable {
  let card: GlobalPauseCardView
  var role: GlobalPauseCardSlotView.Role = .home

  func makeUIView(context: Context) -> GlobalPauseCardSlotView {
    let slot = GlobalPauseCardSlotView(role: role)
    slot.serve(card)
    return slot
  }

  func updateUIView(_ uiView: GlobalPauseCardSlotView, context: Context) {
    uiView.serve(card)
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
