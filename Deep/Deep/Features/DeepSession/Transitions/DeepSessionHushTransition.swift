import UIKit

/// The fade + lift that carries the Deep Session threshold into the practice —
/// the same beat `.softDrift` on `.hush` plays between the session's own
/// stages, ported to UIKit because the practice has to escape the tab bar while
/// the threshold stays pushed underneath it.
///
/// Only the *presented* view is animated: it rises `lift` points and fades up
/// over the still screen below. Fading the presenter too would open a hole —
/// with `shouldRemovePresentersView == false` the threshold sits *under* the
/// transition container, so at half opacity the window itself shows through
/// both. An opaque view fading in over a still one already reads as the
/// crossfade: the practice's `moonCream` base is the scrim.
///
/// UIKit does not retain transitioning delegates; the presenter must hold this
/// object for the lifetime of the presentation.
final class DeepSessionHushTransition: NSObject, UIViewControllerTransitioningDelegate {
  func animationController(
    forPresented presented: UIViewController,
    presenting: UIViewController,
    source: UIViewController
  ) -> (any UIViewControllerAnimatedTransitioning)? {
    HushDriftAnimator(isPresenting: true)
  }

  func animationController(
    forDismissed dismissed: UIViewController
  ) -> (any UIViewControllerAnimatedTransitioning)? {
    HushDriftAnimator(isPresenting: false)
  }

  func presentationController(
    forPresented presented: UIViewController,
    presenting: UIViewController?,
    source: UIViewController
  ) -> UIPresentationController? {
    HushPresentationController(presentedViewController: presented, presenting: presenting)
  }
}

// MARK: - Presentation controller (threshold stays lit)

/// Keeps the pushed threshold alive under the practice, so the close can drift
/// straight back onto it — and so the fade always has something opaque to
/// resolve against. No dim: the practice's own `moonCream` base is the scrim.
private final class HushPresentationController: UIPresentationController {
  override var shouldRemovePresentersView: Bool { false }

  override func containerViewWillLayoutSubviews() {
    super.containerViewWillLayoutSubviews()
    guard let containerView, let presentedView else { return }
    // Re-resolving the frame while the lift's transform is live corrupts the
    // geometry — the animator owns the view until it settles.
    guard presentedView.transform == .identity else { return }
    presentedView.frame = containerView.bounds
  }
}

// MARK: - Animator

private final class HushDriftAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  private let isPresenting: Bool

  /// The vertical travel, matching `SoftDrift.drop` — the practice rises into
  /// place, and sinks back the same distance on the way out.
  private let lift: CGFloat = 16

  init(isPresenting: Bool) {
    self.isPresenting = isPresenting
  }

  func transitionDuration(
    using transitionContext: (any UIViewControllerContextTransitioning)?
  ) -> TimeInterval {
    .hush
  }

  func animateTransition(using context: any UIViewControllerContextTransitioning) {
    // Reduce Motion drops the drift and keeps the crossfade at full length —
    // less motion, not less time (the `SoftDriftEffect` rule).
    let drift: CGAffineTransform = UIAccessibility.isReduceMotionEnabled
      ? .identity
      : CGAffineTransform(translationX: 0, y: lift)

    if isPresenting {
      present(using: context, drift: drift)
    } else {
      dismiss(using: context, drift: drift)
    }
  }

  private func present(using context: any UIViewControllerContextTransitioning, drift: CGAffineTransform) {
    guard
      let toController = context.viewController(forKey: .to),
      let toView = context.view(forKey: .to)
    else {
      context.completeTransition(false)
      return
    }

    let container = context.containerView
    container.addSubview(toView)
    toView.frame = context.finalFrame(for: toController)
    toView.layoutIfNeeded()
    toView.alpha = 0
    toView.transform = drift

    let animator = UIViewPropertyAnimator(
      duration: .hush,
      timingParameters: UICubicTimingParameters.hush
    )
    animator.addAnimations {
      toView.alpha = 1
      toView.transform = .identity
    }
    animator.addCompletion { _ in
      if context.transitionWasCancelled {
        toView.removeFromSuperview()
      }
      toView.transform = .identity
      context.completeTransition(!context.transitionWasCancelled)
    }
    animator.startAnimation()
  }

  private func dismiss(using context: any UIViewControllerContextTransitioning, drift: CGAffineTransform) {
    // The from-view is handed over on dismiss, but fall back to the controller's
    // own view the way the card-lift animator does — a dismissal must always
    // complete.
    guard
      let fromView = context.view(forKey: .from)
        ?? context.viewController(forKey: .from)?.viewIfLoaded
    else {
      context.completeTransition(true)
      return
    }

    let animator = UIViewPropertyAnimator(
      duration: .hush,
      timingParameters: UICubicTimingParameters.hush
    )
    animator.addAnimations {
      fromView.alpha = 0
      fromView.transform = drift
    }
    animator.addCompletion { _ in
      if context.transitionWasCancelled {
        fromView.alpha = 1
        fromView.transform = .identity
      }
      context.completeTransition(!context.transitionWasCancelled)
    }
    animator.startAnimation()
  }
}
