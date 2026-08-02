import SwiftUI
import UIKit

/// Composition root for the Global Pause tab, in UIKit. Owns the navigation
/// controller, the shared Earth scene, and the ONE `GlobalPauseCardView`
/// (which the card-lift transition re-parents between Fuku's Lounge and the
/// presented session). Leaf content stays SwiftUI and routes back through the injected
/// environment actions (`openCollection`, `openCollectionList`), so no leaf
/// ever hosts a navigation container. The mini player is not this tab's
/// concern: it lives in the tab bar's bottom accessory, owned by
/// `MainTabController`, and extends the bottom safe area here automatically.
final class GlobalPauseCoordinatorController: UIViewController {
  private let player: any SoundPlaying
  private let soundRepository: any SoundContentRepository
  /// Threaded through for the home feed's Deep Session doorway — a session
  /// launched from this tab must credit the shared journal and ledger.
  private let practiceStore: any PracticeStore
  private let heartLedger: HeartLedger
  private let pauseSession: GlobalPauseSession
  private let pauseRepository: any PauseEventRepository
  private let imageLoader: any ImageLoading
  private let scene = GlobalPauseEarthScene()
  private let navigation = UINavigationController()

  /// The session audio, alive only while the experience is presented.
  private var sessionAudio: GlobalPauseAudioPlayer?

  /// The single shared card — lounge hero and session content in one instance.
  private lazy var card: GlobalPauseCardView = {
    let card = GlobalPauseCardView(scene: scene)
    card.onTap = { [weak self] in self?.presentSession() }
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
    heartLedger: HeartLedger,
    pauseSession: GlobalPauseSession,
    pauseRepository: any PauseEventRepository,
    imageLoader: any ImageLoading
  ) {
    self.player = soundPlayer
    self.soundRepository = soundRepository
    self.practiceStore = practiceStore
    self.heartLedger = heartLedger
    self.pauseSession = pauseSession
    self.pauseRepository = pauseRepository
    self.imageLoader = imageLoader
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
    navigation.navigationBar.tintColor = .deepPlum
    navigation.delegate = self

    embedNavigation()

    // Hiding the bar kills the edge-swipe pop: UIKit clears the recognizer's
    // delegate-driven activation and re-disables it around every transition.
    // Own the delegate here and re-arm in `didShow` (below) so pushed detail
    // screens can always swipe back.
    navigation.interactivePopGestureRecognizer?.delegate = self
    navigation.interactivePopGestureRecognizer?.isEnabled = true

    // Resolve tonight's schedule immediately: the feed countdown needs it
    // long before the lobby is ever opened.
    Task { await pauseSession.start() }
    observeLiveForChrome()
  }

  /// Keeps the card's caption honest about the nightly meditation — the next
  /// start's schedule line while the world waits, "Live now…" while it's live
  /// — via the `observeHasTrack` re-arming pattern.
  private func observeLiveForChrome() {
    let (isLive, nextStart) = withObservationTracking {
      (pauseSession.isMeditationLive, pauseSession.nextMeditationStart)
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in self?.observeLiveForChrome() }
    }
    let caption: String
    if isLive {
      caption = "Live now — the world is pausing"
    } else if let nextStart {
      caption = pauseSession.scheduleLine(for: nextStart)
    } else {
      caption = "Breathe with the world, together"
    }
    card.setChromeCaption(caption, animated: viewIfLoaded?.window != nil)
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
    let root = GlobalPauseHomeView()
      .environment(\.soundContentRepository, soundRepository)
      .environment(\.openCollection) { [weak self] collection in self?.showCollection(collection) }
      .environment(\.openCollectionList) { [weak self] title, collections in
        self?.showCollectionList(title: title, collections: collections)
      }
      .environment(\.openFukuLounge) { [weak self] in self?.showLobby() }
      .environment(\.soundPlayer, player)
      .environment(\.practiceStore, practiceStore)
      .environment(\.heartLedger, heartLedger)
      .environment(\.globalPauseSession, pauseSession)
      .environment(\.pauseEventRepository, pauseRepository)
      .environment(\.imageLoader, imageLoader)
      .preferredColorScheme(.light)
    let host = UIHostingController(rootView: root)
    host.view.backgroundColor = .clear
    // Screens pushed from the (title-less) home get a chevron-only system
    // back button instead of a "Back" label.
    host.navigationItem.backButtonDisplayMode = .minimal
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
        .environment(\.imageLoader, imageLoader)
    )
  }

  private func showCollectionList(title: String, collections: [SoundCollection]) {
    push(
      CollectionListView(title: title, collections: collections)
        .environment(\.soundPlayer, player)
        .environment(\.openCollection) { [weak self] collection in
          self?.showCollection(collection)
        }
        .environment(\.imageLoader, imageLoader)
    )
  }

  private func push(_ leaf: some View) {
    let host = UIHostingController(rootView: leaf.preferredColorScheme(.light))
    host.view.backgroundColor = .clear
    navigation.pushViewController(host, animated: true)
  }

  /// Fuku's Lounge rides the system push (the card-lift into the session is
  /// the tab's one hero transition). The lounge is the card's only seat now,
  /// so pushing here adopts it directly.
  private func showLobby() {
    push(
      GlobalPauseLobbyView(card: card)
        .environment(\.globalPauseSession, pauseSession)
        .environment(\.pauseEventRepository, pauseRepository)
    )
  }

  private func presentSession() {
    // The session is the live meditation only — outside the nightly window
    // the card's tap rests (its caption already carries the countdown).
    guard pauseSession.isMeditationLive else { return }

    // The card can summon the session from a screen presented over the feed
    // (Fuku's Lounge borrows the card). Always lift from — and stack onto —
    // whatever is frontmost, so the flight lands above the summoning screen;
    // the close must then dismiss from that same presenter, because
    // dismissing from the coordinator would tear down the whole stack.
    var presenter: UIViewController = self
    while let next = presenter.presentedViewController { presenter = next }
    guard !(presenter is GlobalPauseSessionController) else { return }

    // The session owns its own audio, so the shared player pauses (its track
    // stays loaded — the mini player resumes where it left off, the Deep
    // Session precedent). A fresh engine per presentation keeps teardown
    // trivially complete.
    player.pause()
    let audio = GlobalPauseAudioPlayer()
    sessionAudio = audio

    let controller = GlobalPauseSessionController(
      session: pauseSession,
      scene: scene,
      audio: audio
    ) { [weak self, weak presenter] in
      presenter?.dismiss(animated: true)
      self?.sessionAudio = nil
    }
    controller.modalPresentationStyle = .custom
    controller.transitioningDelegate = cardLiftTransition
    // Catch any dismissal that bypasses the close button, so the card can
    // always be handed back to the feed.
    controller.presentationController?.delegate = self

    presenter.present(controller, animated: true)
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
