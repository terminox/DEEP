import SwiftUI
import UIKit

/// Composition root for the Global Pause tab, in UIKit. Owns the navigation
/// controller, the shared Earth scene, and the ONE `GlobalPauseCardView`
/// (which the card-lift transition re-parents between the feed and the
/// lobby). Leaf content stays SwiftUI and routes back through the injected
/// environment actions (`openHomeItem`, `openGlobalPause`), so no leaf ever
/// hosts a navigation container. The mini player is not this tab's concern:
/// it lives in the tab bar's bottom accessory, owned by `MainTabController`,
/// and extends the bottom safe area here automatically.
final class GlobalPauseCoordinatorController: UIViewController {
  private let player: any SoundPlaying
  private let startDeepSession: StartDeepSessionAction
  private let scene = GlobalPauseEarthScene()
  private let navigation = UINavigationController()

  /// The single shared card — feed hero and lobby content in one instance.
  private lazy var card: GlobalPauseCardView = {
    let card = GlobalPauseCardView(scene: scene)
    card.onTap = { [weak self] in self?.presentLobby() }
    return card
  }()

  // UIKit does not retain transitioning delegates; the coordinator must.
  private lazy var cardLiftTransition = GlobalPauseCardLiftTransition(
    card: { [weak self] in self?.card }
  )

  init(soundPlayer: any SoundPlaying, startDeepSession: StartDeepSessionAction) {
    self.player = soundPlayer
    self.startDeepSession = startDeepSession
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    overrideUserInterfaceStyle = .light

    navigation.setViewControllers([makeHomeController()], animated: false)
    navigation.setNavigationBarHidden(true, animated: false)
    navigation.delegate = self

    embedNavigation()

    // Hiding the bar kills the edge-swipe pop: UIKit clears the recognizer's
    // delegate-driven activation and re-disables it around every transition.
    // Own the delegate here and re-arm in `didShow` (below) so pushed detail
    // screens can always swipe back.
    navigation.interactivePopGestureRecognizer?.delegate = self
    navigation.interactivePopGestureRecognizer?.isEnabled = true
  }

  // MARK: - Children

  private func embedNavigation() {
    addChild(navigation)
    navigation.view.frame = view.bounds
    navigation.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(navigation.view)
    navigation.didMove(toParent: self)
  }

  private func makeHomeController() -> UIViewController {
    let root = GlobalPauseHomeView(card: card)
      .environment(\.openHomeItem) { [weak self] item in self?.showHomeItem(item) }
      .environment(\.openGlobalPause) { [weak self] in self?.presentLobby() }
      .environment(\.startDeepSession, startDeepSession)
      .environment(\.soundPlayer, player)
      .preferredColorScheme(.light)
    let host = UIHostingController(rootView: root)
    host.view.backgroundColor = .clear
    return host
  }

  // MARK: - Routing

  private func showHomeItem(_ item: HomeItem) {
    let leaf = HomeItemDetailView(item: item)
      .environment(\.soundPlayer, player)
      .environment(\.startDeepSession, startDeepSession)
      .preferredColorScheme(.light)
    let host = UIHostingController(rootView: leaf)
    host.view.backgroundColor = .clear
    navigation.pushViewController(host, animated: true)
  }

  private func presentLobby() {
    guard presentedViewController == nil else { return }

    let lobby = GlobalPauseLobbyController { [weak self] in
      self?.dismiss(animated: true)
    }
    lobby.modalPresentationStyle = .custom
    lobby.transitioningDelegate = cardLiftTransition
    // Catch any dismissal that bypasses the close button, so the card can
    // always be handed back to the feed.
    lobby.presentationController?.delegate = self

    present(lobby, animated: true)
  }
}

extension GlobalPauseCoordinatorController: UIAdaptivePresentationControllerDelegate {
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    // Safety net: if a dismissal bypassed the animator's handoff, return the
    // orphaned card to its feed slot.
    guard !(card.superview is GlobalPauseCardSlotView), let slot = card.homeSlot else { return }
    card.removeFromSuperview()
    slot.adopt(card)
    card.endGlobeFlight(isLobby: false)
    card.applyRestState(isLobby: false)
  }
}

extension GlobalPauseCoordinatorController: UIGestureRecognizerDelegate {
  /// Allows the edge-swipe pop only when there is something to pop — beginning
  /// it on the root screen freezes the navigation controller.
  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    navigation.viewControllers.count > 1
  }
}

extension GlobalPauseCoordinatorController: UINavigationControllerDelegate {
  func navigationController(
    _ navigationController: UINavigationController,
    didShow viewController: UIViewController,
    animated: Bool
  ) {
    // With the bar hidden, UIKit re-disables the pop gesture on every
    // transition — re-arm it whenever a pushed screen is on top.
    navigationController.interactivePopGestureRecognizer?.isEnabled =
      navigationController.viewControllers.count > 1
  }
}
