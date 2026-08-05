import SwiftUI
import UIKit

extension View {
  /// Runs the guided practice over the entire shell — tab bar and mini player
  /// included — when `isPresented` flips, arriving on the `DeepSessionHushTransition`'s
  /// fade + lift and leaving on its reverse. The threshold that attaches this
  /// stays pushed underneath the whole time, so closing the practice drifts
  /// straight back onto it.
  ///
  /// The presentation is UIKit (`.custom`, so its container sits at window
  /// level and the tab bar can't peek), driven from here rather than the shell:
  /// the shared stores are readable in this tree and can be handed straight to
  /// the presented hosting controller, which the UIKit boundary would
  /// otherwise strip.
  func deepSessionRun(session: DeepSession, isPresented: Binding<Bool>) -> some View {
    modifier(DeepSessionRunModifier(session: session, isPresented: isPresented))
  }
}

private struct DeepSessionRunModifier: ViewModifier {
  let session: DeepSession
  @Binding var isPresented: Bool

  @Environment(\.soundPlayer) private var soundPlayer
  @Environment(\.practiceStore) private var practiceStore
  @Environment(\.heartLedger) private var heartLedger

  func body(content: Content) -> some View {
    content
      .background {
        DeepSessionPresenter(isPresented: $isPresented) { onFinish in
          DeepSessionCoordinatorView(session: session, onFinish: onFinish)
            .environment(\.soundPlayer, soundPlayer)
            .environment(\.practiceStore, practiceStore)
            .environment(\.heartLedger, heartLedger)
            .preferredColorScheme(.light)
        }
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
      }
  }
}

// MARK: - Presenter

/// A zero-size bridge that presents the practice from its own hierarchy. It
/// walks up to the pushed hosting controller before presenting — a child view
/// controller SwiftUI parks inside a background is not a presentation source —
/// and stops at the navigation / tab container, which resolves identically for
/// the Global Pause tab's `UINavigationController` and the two SwiftUI
/// `NavigationStack`s.
private struct DeepSessionPresenter<Practice: View>: UIViewControllerRepresentable {
  @Binding var isPresented: Bool
  /// Built at presentation time, handed the closure that ends the practice.
  let practice: (@escaping () -> Void) -> Practice

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeUIViewController(context: Context) -> PresenterController {
    let controller = PresenterController()
    controller.onDidAppear = { [weak coordinator = context.coordinator] in
      coordinator?.flushPendingPresent()
    }
    return controller
  }

  func updateUIViewController(_ controller: PresenterController, context: Context) {
    let coordinator = context.coordinator
    // Rebuilt every update: a closure captured once would write to a binding
    // that has since gone stale, and the practice could never be closed.
    coordinator.onFinish = { isPresented = false }
    coordinator.makePractice = { [practice] onFinish in
      UIHostingController(rootView: practice(onFinish))
    }
    coordinator.setPresented(isPresented, from: controller)
  }

  static func dismantleUIViewController(_ controller: PresenterController, coordinator: Coordinator) {
    // Popping the threshold while the practice is up would strand the modal —
    // and with it the disabled idle timer.
    coordinator.tearDown()
  }

  /// Hosts nothing; it exists only to be a view controller in the threshold's
  /// hierarchy, and to say when that hierarchy reaches a window.
  final class PresenterController: UIViewController {
    var onDidAppear: (() -> Void)?

    override func loadView() {
      let view = UIView()
      view.backgroundColor = .clear
      view.isUserInteractionEnabled = false
      self.view = view
    }

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      onDidAppear?()
    }
  }

  @MainActor
  final class Coordinator {
    /// UIKit does not retain transitioning delegates; this does.
    private let transition = DeepSessionHushTransition()
    private var presented: UIViewController?
    /// Set when a launch arrives before the threshold is on screen — the very
    /// first update after a push runs with no window.
    private var pendingSource: PresenterController?

    var onFinish: () -> Void = {}
    var makePractice: (@escaping () -> Void) -> UIViewController = { _ in UIViewController() }

    func setPresented(_ shouldPresent: Bool, from source: PresenterController) {
      if shouldPresent {
        present(from: source)
      } else {
        dismiss()
      }
    }

    func flushPendingPresent() {
      guard let source = pendingSource else { return }
      pendingSource = nil
      present(from: source)
    }

    func tearDown() {
      pendingSource = nil
      guard let presented else { return }
      self.presented = nil
      presented.presentingViewController?.dismiss(animated: false)
    }

    private func present(from source: PresenterController) {
      guard presented == nil else { return }
      guard source.viewIfLoaded?.window != nil else {
        // Wait for the push to land; `viewDidAppear` flushes it.
        pendingSource = source
        return
      }
      guard let host = Self.presentationSource(for: source) else { return }
      // Never present into a transition already in flight.
      guard host.presentedViewController == nil,
            host.transitionCoordinator == nil,
            !host.isBeingPresented,
            !host.isBeingDismissed
      else { return }

      let practice = makePractice { [weak self] in self?.onFinish() }
      practice.modalPresentationStyle = .custom
      practice.transitioningDelegate = transition
      practice.overrideUserInterfaceStyle = .light
      // Opaque under the flow's own atmosphere: the fade must never resolve
      // against the window.
      practice.view.backgroundColor = .moonCream

      presented = practice
      host.present(practice, animated: true)
    }

    private func dismiss() {
      pendingSource = nil
      guard let presented, presented.presentingViewController != nil else {
        self.presented = nil
        return
      }
      self.presented = nil
      presented.presentingViewController?.dismiss(animated: true)
    }

    /// The nearest ancestor that owns a screen — the pushed hosting controller
    /// — rather than the zero-size child SwiftUI parked in the background.
    private static func presentationSource(for controller: UIViewController) -> UIViewController? {
      var source = controller
      while let parent = source.parent,
            !(parent is UINavigationController),
            !(parent is UITabBarController) {
        source = parent
      }
      return source
    }
  }
}
