import UIKit

extension UISpringTimingParameters {
  /// UIKit twin of SwiftUI `.spring(response:dampingFraction:)`, so UIKit
  /// transitions can match the app's SwiftUI motion exactly.
  convenience init(response: CGFloat, dampingFraction: CGFloat) {
    let stiffness = pow(2 * .pi / response, 2)
    let damping = 4 * .pi * dampingFraction / response
    self.init(mass: 1, stiffness: stiffness, damping: damping, initialVelocity: .zero)
  }
}

/// The App-Store card lift, done as a true shared-element transition: the ONE
/// `GlobalPauseCardView` is re-parented from its feed slot into the lobby at
/// the start of the present, and handed back at the end of the dismiss. The
/// animator then animates pure geometry — the lobby view's frame and corner
/// radius, with the globe riding the transform trick (see
/// `GlobalPauseCardView.beginGlobeFlight`). No snapshots, no crossfade: at
/// t = 0 the lobby *is* the card.
///
/// UIKit does not retain transitioning delegates; the coordinator must hold
/// this object for the lifetime of the presentation.
final class GlobalPauseCardLiftTransition: NSObject, UIViewControllerTransitioningDelegate {
  /// Resolves the shared card at animation time.
  private let card: @MainActor () -> GlobalPauseCardView?

  init(card: @escaping @MainActor () -> GlobalPauseCardView?) {
    self.card = card
  }

  func animationController(
    forPresented presented: UIViewController,
    presenting: UIViewController,
    source: UIViewController
  ) -> (any UIViewControllerAnimatedTransitioning)? {
    GlobalPauseCardLiftAnimator(card: card, isPresenting: true)
  }

  func animationController(
    forDismissed dismissed: UIViewController
  ) -> (any UIViewControllerAnimatedTransitioning)? {
    // After the reflection handback the session controller no longer holds
    // the card — it is already seated on its lounge slot. Flying the card-
    // lift animator here would re-resolve the shared card and steal it back
    // mid-dismiss; a plain fade is the correct exit (the presentation
    // controller's dim already fades on any dismissal).
    if let controller = dismissed as? GlobalPauseSessionController, controller.card == nil {
      return FadeOutAnimator()
    }
    return GlobalPauseCardLiftAnimator(card: card, isPresenting: false)
  }

  func presentationController(
    forPresented presented: UIViewController,
    presenting: UIViewController?,
    source: UIViewController
  ) -> UIPresentationController? {
    GlobalPauseCardLiftPresentationController(
      presentedViewController: presented,
      presenting: presenting
    )
  }
}

// MARK: - Presentation controller (feed recede)

/// Keeps the feed alive under the lobby (`shouldRemovePresentersView == false`)
/// and owns the plum dim that makes it recede.
private final class GlobalPauseCardLiftPresentationController: UIPresentationController {
  private let dim = UIView()

  override var shouldRemovePresentersView: Bool { false }

  override func presentationTransitionWillBegin() {
    super.presentationTransitionWillBegin()
    guard let containerView else { return }

    dim.backgroundColor = .deepPlum
    dim.alpha = 0
    dim.frame = containerView.bounds
    dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    containerView.insertSubview(dim, at: 0)

    presentedViewController.transitionCoordinator?.animate { [dim] _ in
      dim.alpha = 0.18
    }
  }

  override func dismissalTransitionWillBegin() {
    super.dismissalTransitionWillBegin()
    presentedViewController.transitionCoordinator?.animate { [dim] _ in
      dim.alpha = 0
    }
  }

  override func dismissalTransitionDidEnd(_ completed: Bool) {
    super.dismissalTransitionDidEnd(completed)
    if completed { dim.removeFromSuperview() }
  }
}

// MARK: - Fade-out animator (card already handed back)

/// The dismissal for a session whose card has already gone home behind the
/// reflection screen: nothing to fly, just fade the presented view away.
private final class FadeOutAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  func transitionDuration(
    using transitionContext: (any UIViewControllerContextTransitioning)?
  ) -> TimeInterval {
    0.3
  }

  func animateTransition(using context: any UIViewControllerContextTransitioning) {
    guard
      let fromView = context.view(forKey: .from)
        ?? context.viewController(forKey: .from)?.viewIfLoaded
    else {
      context.completeTransition(true)
      return
    }
    UIView.animate(withDuration: transitionDuration(using: context)) {
      fromView.alpha = 0
    } completion: { _ in
      context.completeTransition(!context.transitionWasCancelled)
    }
  }
}

// MARK: - Animator

private final class GlobalPauseCardLiftAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  private let card: @MainActor () -> GlobalPauseCardView?
  private let isPresenting: Bool

  /// Chrome timings: late back in on close so the title/pill reappear only as
  /// the card settles. The fade-out no longer lives here — the coordinator
  /// plays it as a pre-fade beat before ever presenting.
  private let chromeInDuration: TimeInterval = 0.20
  private let chromeInDelay: TimeInterval = 0.26

  init(card: @escaping @MainActor () -> GlobalPauseCardView?, isPresenting: Bool) {
    self.card = card
    self.isPresenting = isPresenting
  }

  /// Lively on the way up (overshoot happens past the screen edge), critically
  /// damped on the way back down so the card eases exactly onto the feed.
  private var spring: UISpringTimingParameters {
    isPresenting
      ? UISpringTimingParameters(response: 0.46, dampingFraction: 0.82)
      : UISpringTimingParameters(response: 0.45, dampingFraction: 1.0)
  }

  private var duration: TimeInterval { isPresenting ? 0.46 : 0.45 }

  func transitionDuration(
    using transitionContext: (any UIViewControllerContextTransitioning)?
  ) -> TimeInterval {
    duration
  }

  func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
    if isPresenting {
      present(using: transitionContext)
    } else {
      dismiss(using: transitionContext)
    }
  }

  // MARK: Present

  private func present(using context: any UIViewControllerContextTransitioning) {
    guard
      let lobby = context.viewController(forKey: .to) as? GlobalPauseSessionController,
      let lobbyView = context.view(forKey: .to)
    else {
      context.completeTransition(false)
      return
    }

    let container = context.containerView
    let finalFrame = context.finalFrame(for: lobby)

    // P0.1 — resolve safe areas and the close button's constraints at final
    // metrics, before any geometry is disturbed.
    container.addSubview(lobbyView)
    lobbyView.frame = finalFrame
    lobbyView.layoutIfNeeded()
    let lobbySafeInsets = lobbyView.safeAreaInsets

    guard
      let card = card(),
      let slot = card.homeSlot,
      let slotFrameInWindow = slot.frameInWindow
    else {
      // No slot geometry to fly from — degrade to a simple fade. The lobby
      // must still own the globe on this path: seat the card at lobby rest
      // (the pin + immediate landing sets the lobby insets the natural
      // layout needs), don't just fade in an empty shell.
      if let card = card() {
        card.removeFromSuperview()
        lobby.install(card)
        card.beginGlobeFlight(
          lobbyBounds: CGRect(origin: .zero, size: finalFrame.size),
          safeAreaInsets: lobbySafeInsets
        )
        card.endGlobeFlight(isLobby: true)
        card.applyRestState(isLobby: true)
      }
      lobbyView.alpha = 0
      UIView.animate(withDuration: 0.25) {
        lobbyView.alpha = 1
        lobby.closeButton.alpha = 1
      } completion: { _ in
        context.completeTransition(!context.transitionWasCancelled)
      }
      return
    }

    // P0.2 — steal the card. The lobby frame always contains the card frame,
    // so the emptied slot (shadow only) is never visible.
    card.removeFromSuperview()
    lobby.install(card)

    // P0.3 — collapse the lobby onto the card's live footprint. After this
    // the screen is pixel-identical to rest: same card pixels, same chrome.
    let cardFrame = container.convert(slotFrameInWindow, from: nil)
    lobbyView.frame = cardFrame
    lobbyView.layer.cornerRadius = .card
    lobbyView.layer.cornerCurve = .continuous
    lobbyView.clipsToBounds = true
    lobbyView.layoutIfNeeded()

    // The coordinator's pre-fade has already emptied the chrome; snap it here
    // too so a present that skipped the beat can never fly the text along.
    card.chrome.alpha = 0
    card.borderView.alpha = 0

    // P0.4 — pin the globe for flight (drawable stops resizing from here on).
    card.beginGlobeFlight(
      lobbyBounds: CGRect(origin: .zero, size: finalFrame.size),
      safeAreaInsets: lobbySafeInsets
    )

    // P1 — flight.
    let animator = UIViewPropertyAnimator(duration: duration, timingParameters: spring)
    animator.addAnimations {
      lobbyView.frame = finalFrame
      lobbyView.layer.cornerRadius = 0
      card.setCornerRadius(0)
      card.setGlobeFlightTarget(isLobby: true)
      lobbyView.layoutIfNeeded()
    }

    UIView.animate(withDuration: chromeInDuration, delay: chromeInDelay, options: [.curveEaseOut]) {
      lobby.closeButton.alpha = 1
    }

    // P2 — completion.
    animator.addCompletion { _ in
      if context.transitionWasCancelled {
        if let card = lobby.uninstallCard() {
          slot.adopt(card)
          card.endGlobeFlight(isLobby: false)
          card.applyRestState(isLobby: false)
        }
      } else {
        card.endGlobeFlight(isLobby: true)
        card.applyRestState(isLobby: true)
        lobbyView.clipsToBounds = false
      }
      context.completeTransition(!context.transitionWasCancelled)
    }
    animator.startAnimation()
  }

  // MARK: Dismiss

  private func dismiss(using context: any UIViewControllerContextTransitioning) {
    guard
      let lobby = context.viewController(forKey: .from) as? GlobalPauseSessionController,
      let lobbyView = context.view(forKey: .from) ?? lobby.viewIfLoaded
    else {
      context.completeTransition(false)
      return
    }

    let container = context.containerView
    let card = card()
    let slot = card?.homeSlot

    // D0 — resolve the live landing rect. Fallback: fade out, but still hand
    // the card back — it must return home on every terminal path.
    guard
      let card,
      let slot,
      let slotFrameInWindow = slot.frameInWindow
    else {
      UIView.animate(withDuration: 0.25, animations: { lobbyView.alpha = 0 }) { _ in
        if let card = lobby.uninstallCard() ?? card, let slot = slot ?? card.homeSlot {
          slot.adopt(card)
          card.endGlobeFlight(isLobby: false)
          card.applyRestState(isLobby: false)
        }
        context.completeTransition(!context.transitionWasCancelled)
      }
      return
    }

    let cardFrame = container.convert(slotFrameInWindow, from: nil)

    // Re-enter flight from lobby rest — bounds are already the pinned size, so
    // this is visually a no-op; it just re-arms the transform path.
    card.beginGlobeFlight(
      lobbyBounds: lobbyView.bounds,
      safeAreaInsets: lobbyView.safeAreaInsets
    )
    lobbyView.clipsToBounds = true
    lobbyView.layer.cornerCurve = .continuous

    // D1 — flight home.
    let animator = UIViewPropertyAnimator(duration: duration, timingParameters: spring)
    animator.addAnimations {
      lobbyView.frame = cardFrame
      lobbyView.layer.cornerRadius = .card
      card.setCornerRadius(.card)
      card.setGlobeFlightTarget(isLobby: false)
      lobbyView.layoutIfNeeded()
    }

    UIView.animate(withDuration: chromeInDuration, delay: chromeInDelay, options: [.curveEaseOut]) {
      card.chrome.alpha = 1
      card.borderView.alpha = 1
    }
    UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut]) {
      lobby.closeButton.alpha = 0
    }

    // D2 — completion.
    animator.addCompletion { _ in
      if context.transitionWasCancelled {
        card.endGlobeFlight(isLobby: true)
        card.applyRestState(isLobby: true)
        lobbyView.clipsToBounds = false
        lobby.closeButton.alpha = 1
      } else {
        _ = lobby.uninstallCard()
        slot.adopt(card)
        card.endGlobeFlight(isLobby: false)
        card.applyRestState(isLobby: false)
      }
      context.completeTransition(!context.transitionWasCancelled)
    }
    animator.startAnimation()
  }
}
