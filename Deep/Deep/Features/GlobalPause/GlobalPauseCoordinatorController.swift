import SwiftUI
import UIKit

/// Composition root for the Global Pause tab, in UIKit. Owns the navigation
/// controller, the shared Earth scene, and the ONE `GlobalPauseCardView`
/// (which the card-lift transition re-parents between the feed and the
/// lobby). Leaf content stays SwiftUI and routes back through the injected
/// environment actions (`openCollection`, `openCollectionList`,
/// `openGlobalPause`), so no leaf ever hosts a navigation container. The mini
/// player is not this tab's concern: it lives in the tab bar's bottom
/// accessory, owned by `MainTabController`, and extends the bottom safe area
/// here automatically.
final class GlobalPauseCoordinatorController: UIViewController {
  private let player: any SoundPlaying
  private let soundRepository: any SoundContentRepository
  /// Threaded through for the home feed's Deep Session doorway — a session
  /// launched from this tab must credit the shared journal and ledger.
  private let practiceStore: any PracticeStore
  private let heartLedger: HeartLedger
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

  init(
    soundPlayer: any SoundPlaying,
    soundRepository: any SoundContentRepository,
    practiceStore: any PracticeStore,
    heartLedger: HeartLedger
  ) {
    self.player = soundPlayer
    self.soundRepository = soundRepository
    self.practiceStore = practiceStore
    self.heartLedger = heartLedger
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    navigation.setViewControllers([makeHomeController()], animated: false)
    navigation.setNavigationBarHidden(true, animated: false)
    navigation.navigationBar.tintColor = .deepPlum
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
      .environment(\.soundContentRepository, soundRepository)
      .environment(\.openCollection) { [weak self] collection in self?.showCollection(collection) }
      .environment(\.openCollectionList) { [weak self] title, collections in
        self?.showCollectionList(title: title, collections: collections)
      }
      .environment(\.openGlobalPause) { [weak self] in self?.presentLobby() }
      .environment(\.soundPlayer, player)
      .environment(\.practiceStore, practiceStore)
      .environment(\.heartLedger, heartLedger)
    let host = UIHostingController(rootView: root)
    host.view.backgroundColor = .clear
    return host
  }

  // MARK: - Routing

  /// Pushes the real Deep Sound collection detail. `subscriptionStore` stays on
  /// its environment default here — the same behaviour the Sounds tab has today,
  /// since the SwiftUI environment can't cross the UIKit tab boundary.
  private func showCollection(_ collection: SoundCollection) {
    push(
      CollectionDetailView(collection: collection, bottomInset: .rhythm)
        .environment(\.soundPlayer, player)
        .environment(\.soundContentRepository, soundRepository)
    )
  }

  private func showCollectionList(title: String, collections: [SoundCollection]) {
    push(
      CollectionListView(title: title, collections: collections)
        .environment(\.soundPlayer, player)
        .environment(\.openCollection) { [weak self] collection in
          self?.showCollection(collection)
        }
    )
  }

  private func push(_ leaf: some View) {
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
  /// The root feed owns its chrome (no bar); pushed leaves need the system bar
  /// for the back button and their inline title, so visibility follows depth.
  func navigationController(
    _ navigationController: UINavigationController,
    willShow viewController: UIViewController,
    animated: Bool
  ) {
    navigationController.setNavigationBarHidden(
      viewController === navigationController.viewControllers.first,
      animated: animated
    )
  }

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
