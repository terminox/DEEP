import UIKit
import SwiftUI

/// The Global Pause card — one fully-UIKit view that is *both* the feed card
/// and the lobby's content. The card-lift transition re-parents this single
/// instance between the feed slot and the lobby, so the open/close is pure
/// geometry: no crossfade, no snapshots, one Metal renderer.
///
/// Layout is one mode-independent rule set (manual frame math — it animates
/// smoothly under `layoutIfNeeded` inside a property animator). Card rest and
/// lobby rest differ only in chrome/border alpha, corner radius, and globe
/// interactivity — plus the globe's inset rect at lobby scale.
///
/// ## Globe flight
/// A property animator cannot re-layout an `MTKView` every frame: CA would
/// interpolate the bounds while the drawable renders at the final size,
/// smearing the orb into an ellipse. The escape hatch is the shader's own
/// math — the orb is centre-anchored and height-proportional — so a
/// fullscreen-sized render scaled down is pixel-equivalent to a card-sized
/// render. During flight the globe's **bounds stay pinned to the lobby size**
/// and only `transform` + `center` animate; `layoutSubviews` skips the globe
/// so `layoutIfNeeded` can't fight the trick.
final class GlobalPauseCardView: UIControl {
  private enum GlobeLayout {
    case natural, inFlight
  }

  /// Fired on touch-up when the card is in the feed. The coordinator routes
  /// this to the lobby presentation.
  var onTap: (() -> Void)?

  /// The feed slot currently responsible for this card — the dismiss target.
  weak var homeSlot: GlobalPauseCardSlotView?

  /// Faded out on the way up, back in late on the way down — real labels.
  let chrome: GlobalPauseCardChromeView
  /// Hairline card border; fades with the chrome.
  let borderView = UIView()

  private let atmosphere = CardAtmosphereView()
  private let earthScene: EarthSceneView

  private var globeLayout: GlobeLayout = .natural
  private var isLobby = false
  private var lobbyGlobeInsets: UIEdgeInsets = .zero
  private var pinnedGlobeHeight: CGFloat = 0

  init(scene: GlobalPauseEarthScene, caption: String = "Breathe with the world, together") {
    earthScene = EarthSceneView(glow: scene.glow, interaction: scene.interaction)
    chrome = GlobalPauseCardChromeView(caption: caption)
    super.init(frame: .zero)

    clipsToBounds = true
    layer.cornerRadius = .card
    layer.cornerCurve = .continuous

    borderView.isUserInteractionEnabled = false
    borderView.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor
    borderView.layer.borderWidth = 0.5
    borderView.layer.cornerRadius = .card
    borderView.layer.cornerCurve = .continuous

    addSubview(atmosphere)
    addSubview(earthScene)
    addSubview(chrome)
    addSubview(borderView)

    addTarget(self, action: #selector(handleTap), for: .touchUpInside)

    isAccessibilityElement = true
    accessibilityLabel = "Global Pause. \(caption)."
    accessibilityTraits = .button
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Layout

  override func layoutSubviews() {
    super.layoutSubviews()
    atmosphere.frame = bounds
    chrome.frame = bounds
    borderView.frame = bounds

    // In flight only the animator may touch the globe (transform + center).
    if globeLayout == .natural {
      earthScene.transform = .identity
      earthScene.frame = isLobby ? bounds.inset(by: lobbyGlobeInsets) : bounds
    }
  }

  /// Card and border share one radius; the animator morphs it 24 ↔ 0.
  func setCornerRadius(_ radius: CGFloat) {
    layer.cornerRadius = radius
    borderView.layer.cornerRadius = radius
  }

  // MARK: - Rest states

  /// Snaps every non-animated property to the given mode. The animator owns
  /// the animated path; this runs at rest (setup/completion).
  func applyRestState(isLobby: Bool) {
    self.isLobby = isLobby
    chrome.alpha = isLobby ? 0 : 1
    borderView.alpha = isLobby ? 0 : 1
    earthScene.isInteractive = isLobby
    isEnabled = !isLobby
    setCornerRadius(isLobby ? 0 : .card)
    setNeedsLayout()
  }

  // MARK: - Globe flight

  /// Pins the globe's bounds to the final lobby-globe size with a compensating
  /// transform, so the Metal drawable never resizes during the animation.
  /// Call before the animation block, from either rest state.
  func beginGlobeFlight(lobbyBounds: CGRect, safeAreaInsets: UIEdgeInsets) {
    lobbyGlobeInsets = safeAreaInsets
    let target = lobbyBounds.inset(by: safeAreaInsets)
    guard target.height > 0 else { return }

    let naturalHeight = earthScene.bounds.height
    let currentCenter = earthScene.center

    globeLayout = .inFlight
    earthScene.isInteractive = false
    earthScene.bounds = CGRect(origin: .zero, size: target.size)
    // Flush the globe's internal layout NOW, outside any animation block —
    // otherwise the MTKView's frame change gets deferred into the animator's
    // `layoutIfNeeded` and CA animates it non-uniformly (the ellipse smear the
    // pinning exists to prevent).
    earthScene.layoutIfNeeded()
    let scale = naturalHeight / target.height
    earthScene.transform = CGAffineTransform(scaleX: scale, y: scale)
    earthScene.center = currentCenter
    pinnedGlobeHeight = target.height
  }

  /// Sets the globe's animated endpoint. Call INSIDE the animation block,
  /// after the card's bounds have been set to their final value.
  func setGlobeFlightTarget(isLobby: Bool) {
    guard globeLayout == .inFlight, pinnedGlobeHeight > 0 else { return }
    if isLobby {
      let globeRect = bounds.inset(by: lobbyGlobeInsets)
      earthScene.transform = .identity
      earthScene.center = CGPoint(x: globeRect.midX, y: globeRect.midY)
    } else {
      let scale = bounds.height / pinnedGlobeHeight
      earthScene.transform = CGAffineTransform(scaleX: scale, y: scale)
      earthScene.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
  }

  /// Returns the globe to natural layout. The bounds snap is ≤1 frame of
  /// drawable settle and visually identical (the render is height-proportional
  /// and centre-anchored).
  func endGlobeFlight(isLobby: Bool) {
    self.isLobby = isLobby
    globeLayout = .natural
    earthScene.transform = .identity
    setNeedsLayout()
    layoutIfNeeded()
    earthScene.isInteractive = isLobby
  }

  // MARK: - Press feedback (foam-like settle, matching `.softPress`)

  override var isHighlighted: Bool {
    didSet {
      guard oldValue != isHighlighted else { return }
      let spring = UISpringTimingParameters(response: 0.55, dampingFraction: 0.78)
      let animator = UIViewPropertyAnimator(duration: 0.55, timingParameters: spring)
      animator.addAnimations {
        self.transform = self.isHighlighted
          ? CGAffineTransform(scaleX: 0.97, y: 0.97)
          : .identity
      }
      animator.startAnimation()
    }
  }

  @objc private func handleTap() {
    // Reset the press scale before the lift reads geometry from the slot.
    transform = .identity
    onTap?()
  }
}

#Preview("Card — feed scale") {
  let scene = GlobalPauseEarthScene.preview
  let card = GlobalPauseCardView(scene: scene)
  let container = UIView()
  container.backgroundColor = .moonCream
  card.frame = CGRect(x: 20, y: 100, width: 350, height: 200)
  card.autoresizingMask = [.flexibleWidth]
  container.addSubview(card)
  return container
}

#Preview("Card — lobby scale") {
  let scene = GlobalPauseEarthScene.preview
  let card = GlobalPauseCardView(scene: scene)
  card.applyRestState(isLobby: true)
  return card
}
