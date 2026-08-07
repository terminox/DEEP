import UIKit
import SwiftUI

/// The Global Pause card — one fully-UIKit view that is *both* the feed card
/// and the lobby's content. The card-lift transition re-parents this single
/// instance between the feed slot and the lobby, so the open/close is pure
/// geometry: no crossfade, no snapshots, one Metal renderer.
///
/// Layout is one mode-independent rule set (manual frame math — it animates
/// smoothly under `layoutIfNeeded` inside a property animator). Card rest and
/// lobby rest differ only in chrome/border alpha, corner radius, globe
/// interactivity — and the globe's rest rect: the corner seat in the card
/// (`CardGlobeSeat`), the safe-area inset bounds in the lobby. Both come from
/// `naturalGlobeRect`, the single definition the flight's endpoints also use.
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

  // MARK: Phase placement state

  /// Session phases park the globe at a scale/offset (e.g. raised and small
  /// behind a breathing guide). Held as plain state — `phasePlacementTransform()`
  /// projects it — so layout, flight, and the animated setter all derive the
  /// same geometry from one source.
  private var phaseScale: CGFloat = 1
  /// Offset as a fraction of the card's bounds height (resolution-independent
  /// — the same placement reads identically at card and lobby scale).
  private var phaseOffsetYFraction: CGFloat = 0
  /// Set when a placement request lands mid-flight; `endGlobeFlight` honours
  /// it once the animator has released the globe.
  private var deferredPhasePlacementAnimated: Bool?
  /// Placement captured at `beginGlobeFlight` — the values both flight
  /// endpoints were built from. If a placement request arrives mid-flight,
  /// landing happens on THESE values (visually continuous with the flight)
  /// before easing to the new ones.
  private var flightPhaseScale: CGFloat = 1
  private var flightPhaseOffsetYFraction: CGFloat = 0
  /// Live placement spring. While it runs, `layoutSubviews` must keep its
  /// hands off the globe's transform or the spring would snap to its target.
  private var phasePlacementAnimator: UIViewPropertyAnimator?

  // MARK: Card-rest globe seat

  /// At card rest the globe is parked in the bottom-right corner, larger than
  /// the card can show: the orb crests the corner instead of sitting centred.
  ///
  /// The seat grows the globe unit's **frame** rather than transform-scaling
  /// it, so the Metal drawable grows with the orb and the render stays native
  /// (magnifying a card-sized render would soften the country borders).
  private enum CardGlobeSeat {
    /// The dial: the orb's radius as a fraction of the card's height.
    ///
    /// The shader draws the orb at a fixed fraction of the *globe unit's*
    /// height (`orbScreenRadiusFractionOfHeight`, ≈0.22), so asking for a
    /// radius this large makes the unit several times taller than the card —
    /// the orb is deliberately far bigger than its window onto it.
    static let orbRadiusFractionOfCardHeight: CGFloat = 0.70
    /// Orb centre, inset from the card's bottom-right corner **in orb radii**.
    /// Kept in orb radii rather than points so the crop's composition is
    /// preserved when the radius above changes, and reads identically on every
    /// device (the orb follows the card's fixed height, not its width).
    static let cornerInset: CGFloat = 0.25
  }

  init(scene: GlobalPauseEarthScene, caption: String = "Breathe with the world, together") {
    earthScene = EarthSceneView(glow: scene.glow, interaction: scene.interaction, ripples: scene.ripples)
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

    // In flight only the animator may touch the globe (transform + center);
    // ditto while the placement spring runs — bounds are stable at rest, so
    // skipping the frame pass there is safe.
    if globeLayout == .natural, phasePlacementAnimator?.isRunning != true {
      earthScene.transform = .identity
      earthScene.frame = naturalGlobeRect(isLobby: isLobby, in: bounds)
      // Placement rides on top of natural layout, transform-only — the frame
      // (and with it the Metal drawable) never changes, so no smear.
      earthScene.transform = phasePlacementTransform()
    }
  }

  /// The globe's natural (at-rest) rect for a mode, in card coordinates.
  /// `layoutSubviews` and the flight's endpoints both derive from this, so a
  /// landing is pixel-identical to where the animator left the globe.
  ///
  /// Lobby rest fills the card inside the safe areas; card rest is the corner
  /// seat — bigger than the card, so the orb is cropped by the right and
  /// bottom edges.
  private func naturalGlobeRect(isLobby: Bool, in bounds: CGRect) -> CGRect {
    guard !isLobby else { return bounds.inset(by: lobbyGlobeInsets) }
    let orbRadius = CardGlobeSeat.orbRadiusFractionOfCardHeight * bounds.height
    // Only the unit's *height* sets the orb's size; its width just has to hold
    // the Metal orb and its bloom (the halo and cradle behind it are ordinary
    // unclipped subviews, so they light the card whatever this width is). A
    // square gives ~2.3 orb radii either side of the centre — far past the
    // bloom, and far fewer drawable pixels than matching the card's aspect.
    let side = orbRadius / CGFloat(EarthRendererConstants.orbScreenRadiusFractionOfHeight)
    let inset = CardGlobeSeat.cornerInset * orbRadius
    let centre = CGPoint(x: bounds.maxX - inset, y: bounds.maxY - inset)
    return CGRect(
      x: centre.x - side / 2,
      y: centre.y - side / 2,
      width: side,
      height: side
    )
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

  // MARK: - Phase hooks

  /// Applies the card's state — schedule line at rest, ticking countdown in
  /// the final lead, "Join now" plus the LIVE badge while the world pauses.
  /// The countdown's accessibility copy stays static on purpose: rewriting
  /// the label every second would spam VoiceOver.
  func setChromeState(_ state: GlobalPauseCardState, animated: Bool) {
    chrome.setState(state, animated: animated)
    switch state {
    case .off(let scheduleLine):
      accessibilityLabel = "Global Pause. \(scheduleLine)."
    case .countdown(_, let scheduleLine):
      accessibilityLabel = "Global Pause. \(scheduleLine). Going live soon."
    case .live:
      accessibilityLabel = "Global Pause. Live. The world is pausing. Join now."
    }
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
    // A running placement spring would fight the flight for the transform —
    // flight wins; the placement's *state* survives and re-applies on landing.
    phasePlacementAnimator?.stopAnimation(true)
    phasePlacementAnimator = nil
    earthScene.isInteractive = false
    earthScene.bounds = CGRect(origin: .zero, size: target.size)
    // Flush the globe's internal layout NOW, outside any animation block —
    // otherwise the MTKView's frame change gets deferred into the animator's
    // `layoutIfNeeded` and CA animates it non-uniformly (the ellipse smear the
    // pinning exists to prevent).
    earthScene.layoutIfNeeded()
    let scale = naturalHeight / target.height
    // Freeze the placement the flight is flown with. Both endpoints compose
    // it (here and in `setGlobeFlightTarget`) so t = 0 and t = 1 are each
    // pixel-identical to their placed rest states — the placement rides the
    // flight instead of snapping off and back on.
    flightPhaseScale = phaseScale
    flightPhaseOffsetYFraction = phaseOffsetYFraction
    earthScene.transform = flightPhasePlacementTransform().scaledBy(x: scale, y: scale)
    earthScene.center = currentCenter
    pinnedGlobeHeight = target.height
  }

  /// Sets the globe's animated endpoint. Call INSIDE the animation block,
  /// after the card's bounds have been set to their final value. Endpoints are
  /// the rest rect the destination's `layoutSubviews` will produce, expressed
  /// as the transform that maps the pinned bounds onto it — composed with the
  /// flight-frozen phase placement (see `beginGlobeFlight`), so they match the
  /// destination rest state exactly. At the lobby endpoint the rest rect *is*
  /// the pinned size, so the scale is 1.
  func setGlobeFlightTarget(isLobby: Bool) {
    guard globeLayout == .inFlight, pinnedGlobeHeight > 0 else { return }
    let rect = naturalGlobeRect(isLobby: isLobby, in: bounds)
    let scale = rect.height / pinnedGlobeHeight
    earthScene.transform = flightPhasePlacementTransform().scaledBy(x: scale, y: scale)
    earthScene.center = CGPoint(x: rect.midX, y: rect.midY)
  }

  /// Returns the globe to natural layout. The bounds snap is ≤1 frame of
  /// drawable settle and visually identical (the render is height-proportional
  /// and centre-anchored, and the landing layout re-applies the same placement
  /// the flight endpoint carried).
  func endGlobeFlight(isLobby: Bool) {
    self.isLobby = isLobby
    globeLayout = .natural

    let deferredAnimated = deferredPhasePlacementAnimated
    deferredPhasePlacementAnimated = nil

    if deferredAnimated == true {
      // A placement changed mid-flight and asked to ease in. Land on the
      // placement the flight was flown with (visually continuous), then
      // spring to the new values.
      let (newScale, newOffset) = (phaseScale, phaseOffsetYFraction)
      phaseScale = flightPhaseScale
      phaseOffsetYFraction = flightPhaseOffsetYFraction
      earthScene.transform = .identity
      setNeedsLayout()
      layoutIfNeeded()
      phaseScale = newScale
      phaseOffsetYFraction = newOffset
      applyPhasePlacement(animated: true)
    } else {
      // No change, or a non-animated change: the landing layout pass applies
      // the current placement directly (a deliberate snap when un-animated).
      earthScene.transform = .identity
      setNeedsLayout()
      layoutIfNeeded()
    }
    earthScene.isInteractive = isLobby
  }

  // MARK: - Phase placement

  /// Parks the globe at a scale/offset for a session phase (e.g. raised and
  /// smaller above a breathing guide). Transform-only on the globe unit — the
  /// flight's rule applies here too: an MTKView's bounds must never animate
  /// (drawable smear), its transform is free.
  ///
  /// `offsetY` is a fraction of the card's bounds height (−0.28 raises the
  /// globe by 28% of the card's height), so a placement reads identically at
  /// card and lobby scale. While the globe is `.inFlight` the request is
  /// deferred — flight wins during flight — and `endGlobeFlight` applies it
  /// on landing (last request wins).
  func setGlobePhasePlacement(scale: CGFloat, offsetY: CGFloat, animated: Bool) {
    phaseScale = scale
    phaseOffsetYFraction = offsetY
    guard globeLayout == .natural else {
      deferredPhasePlacementAnimated = animated
      return
    }
    applyPhasePlacement(animated: animated)
  }

  /// Returns the globe to its natural framing.
  func resetGlobePhasePlacement(animated: Bool) {
    setGlobePhasePlacement(scale: 1, offsetY: 0, animated: animated)
  }

  /// The current placement as a transform about the globe's natural frame.
  /// Translation first, then scale, so the globe shrinks about its own centre
  /// and the offset stays a stable fraction of the card regardless of scale.
  private func phasePlacementTransform() -> CGAffineTransform {
    placementTransform(scale: phaseScale, offsetYFraction: phaseOffsetYFraction)
  }

  /// The placement frozen at `beginGlobeFlight` — flight endpoints only.
  private func flightPhasePlacementTransform() -> CGAffineTransform {
    placementTransform(scale: flightPhaseScale, offsetYFraction: flightPhaseOffsetYFraction)
  }

  private func placementTransform(scale: CGFloat, offsetYFraction: CGFloat) -> CGAffineTransform {
    guard scale != 1 || offsetYFraction != 0 else { return .identity }
    return CGAffineTransform(translationX: 0, y: offsetYFraction * bounds.height)
      .scaledBy(x: scale, y: scale)
  }

  private func applyPhasePlacement(animated: Bool) {
    // Retarget from wherever the globe visually is: stopping (not finishing)
    // leaves the presentation value in place for the next animator.
    phasePlacementAnimator?.stopAnimation(true)
    phasePlacementAnimator = nil

    guard animated else {
      earthScene.transform = phasePlacementTransform()
      return
    }
    // Same spring family as the press feedback, fully damped — the orb should
    // settle into its phase seat, not bounce against the chrome around it.
    let spring = UISpringTimingParameters(response: 0.55, dampingFraction: 1.0)
    let animator = UIViewPropertyAnimator(duration: 0.55, timingParameters: spring)
    animator.addAnimations {
      self.earthScene.transform = self.phasePlacementTransform()
    }
    animator.addCompletion { [weak self] _ in
      self?.phasePlacementAnimator = nil
    }
    phasePlacementAnimator = animator
    animator.startAnimation()
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

#Preview("Card — narrow device") {
  // The corner inset is measured in orb radii, and the orb follows the card's
  // fixed height — so an SE-width card must crop the globe identically.
  let scene = GlobalPauseEarthScene.preview
  let card = GlobalPauseCardView(scene: scene)
  let container = UIView()
  container.backgroundColor = .moonCream
  card.frame = CGRect(x: 20, y: 100, width: 280, height: 200)
  container.addSubview(card)
  return container
}

#Preview("Card — lobby scale") {
  let scene = GlobalPauseEarthScene.preview
  let card = GlobalPauseCardView(scene: scene)
  card.applyRestState(isLobby: true)
  return card
}

#Preview("Card — live") {
  let scene = GlobalPauseEarthScene.preview
  let card = GlobalPauseCardView(scene: scene)
  let container = UIView()
  container.backgroundColor = .moonCream
  card.frame = CGRect(x: 20, y: 100, width: 350, height: 200)
  card.autoresizingMask = [.flexibleWidth]
  card.setChromeState(.live, animated: false)
  container.addSubview(card)
  return container
}

#Preview("Card — countdown") {
  let scene = GlobalPauseEarthScene.preview
  let card = GlobalPauseCardView(scene: scene)
  let container = UIView()
  container.backgroundColor = .moonCream
  card.frame = CGRect(x: 20, y: 100, width: 350, height: 200)
  card.autoresizingMask = [.flexibleWidth]
  card.setChromeState(
    .countdown(target: Date().addingTimeInterval(899), scheduleLine: "Tonight · 20:40 Thailand Time"),
    animated: false
  )
  container.addSubview(card)
  return container
}
