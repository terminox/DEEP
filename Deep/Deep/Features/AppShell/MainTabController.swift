import UIKit
import SwiftUI

/// The app's root shell, built in UIKit. Each tab hosts a SwiftUI feature via
/// `UIHostingController`. New tabs are added by appending to `viewControllers`.
final class MainTabController: UITabBarController {
  /// Shared app-lifetime stores threaded in from `AppRootView`, injected into
  /// the Profile tab so log-out / onboarding-reset act on the same instances
  /// that drive the app's onboarding gate.
  private let onboardingStore: any OnboardingProgressStore
  private let accountStore: any AccountStore
  private let subscriptionStore: any SubscriptionStore

  /// Backend-backed Deep Sound content, injected into every hosted tab (and the
  /// Now Playing lyrics sheet) since the SwiftUI environment can't cross the
  /// UIKit boundary.
  private let soundRepository: any SoundContentRepository

  /// One player shared across the tabs, so a sound started in Global Pause and
  /// a sound started in Sounds drive the same bottom accessory and Now Playing.
  private let sharedPlayer: any SoundPlaying

  /// The shared practice journal and heart ledger, injected into every hosted
  /// tab: the Deep Session flow presents from inside any tab's tree and must
  /// credit the same journal/ledger the Garden and Portfolio read.
  private let practiceStore: any PracticeStore
  private let heartLedger: HeartLedger

  /// The app-long Global Pause engine + backend, handed to the Global Pause
  /// coordinator (phases in the lobby; the caption/schedule now surfaces on
  /// Fuku's Lounge's card).
  private let pauseSession: GlobalPauseSession
  private let pauseRepository: any PauseEventRepository

  /// The shared artwork cache, injected into every hosted tab so all tiles
  /// draw from one memory/disk store.
  private let imageLoader: any ImageLoading

  /// Hosts the mini player inside the tab bar's bottom accessory. Created on
  /// first playback and kept as a child VC for the controller's lifetime.
  private var accessoryHost: PlayerAccessoryHostingController?

  /// A tab item with both of its baked image variants. The minimized bar's
  /// pill must be icon-only while the expanded bar shows icon + label, and
  /// because the label is baked into the image (the unselected-tint
  /// workaround — see `tabItem(title:systemImage:)`), the system can't drop
  /// the text itself; `setTabItemsIconOnly(_:)` swaps the variants by hand.
  private struct ComposedTabItem {
    let item: UITabBarItem
    let full: UIImage
    let iconOnly: UIImage
  }

  private var composedItems: [ComposedTabItem] = []
  private var isTabBarMinimized = false
  /// True only while `setTabItemsIconOnly(_:)` reasserts `selectedIndex` for
  /// its repaint trick, so the delegate can tell that reassignment apart from
  /// a real same-tab tap — see `tabBarController(_:shouldSelect:)`.
  private var isReassertingSelection = false

  init(
    onboardingStore: any OnboardingProgressStore,
    accountStore: any AccountStore,
    subscriptionStore: any SubscriptionStore,
    soundRepository: any SoundContentRepository,
    soundPlayer: any SoundPlaying,
    practiceStore: any PracticeStore,
    heartLedger: HeartLedger,
    pauseSession: GlobalPauseSession,
    pauseRepository: any PauseEventRepository,
    imageLoader: any ImageLoading
  ) {
    self.onboardingStore = onboardingStore
    self.accountStore = accountStore
    self.subscriptionStore = subscriptionStore
    self.soundRepository = soundRepository
    self.sharedPlayer = soundPlayer
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
    configureChildren()
    // Same-tab taps scroll the visible screen back to the top — see
    // `tabBarController(_:shouldSelect:)`.
    delegate = self
    // No custom UITabBarAppearance is installed: that keeps the system Liquid
    // Glass tab bar (iOS 26). Item colours are baked into the item images in
    // `host(_:title:systemImage:)` instead — see the note there.

    // The tab bar starts non-collapsible; `updateAccessory(hasTrack:)` allows
    // minimize-on-scroll only while a track is loaded — see the note there.
    tabBarMinimizeBehavior = .never
    observeHasTrack()
  }

  private func configureChildren() {
    // Global Pause is a UIKit coordinator, so it slots in directly — no
    // hosting wrapper.
    let globalPause = GlobalPauseCoordinatorController(
      soundPlayer: sharedPlayer,
      soundRepository: soundRepository,
      practiceStore: practiceStore,
      heartLedger: heartLedger,
      pauseSession: pauseSession,
      pauseRepository: pauseRepository,
      imageLoader: imageLoader
    )
    globalPause.tabBarItem = tabItem(title: "Home", systemImage: "house.fill")

    // While a track is loaded, the shared player surfaces globally as the tab
    // bar's bottom accessory — see `observeHasTrack()`.
    let sounds = host(
      DeepSoundCoordinatorView(player: sharedPlayer),
      title: "Sounds",
      systemImage: "waveform"
    )

    let garden = host(
      MindGardenCoordinatorView(),
      title: "Garden",
      systemImage: "leaf.fill"
    )

    let portfolio = host(
      CompassionPortfolioCoordinatorView(),
      title: "Portfolio",
      systemImage: "heart.fill"
    )

    let profile = host(
      ProfileView()
        .environment(\.onboardingStore, onboardingStore)
        .environment(\.accountStore, accountStore)
        .environment(\.subscriptionStore, subscriptionStore),
      title: "You",
      systemImage: "person.fill"
    )

    viewControllers = [globalPause, sounds, garden, portfolio, profile]
  }

  // MARK: - Bottom accessory (mini player)

  /// Re-arming observation loop on the `@Observable` player: attach the mini
  /// player accessory while a track is loaded, remove it when playback clears.
  /// `onChange` fires at willSet, so the new value is read on the next
  /// main-actor hop, which also naturally coalesces bursts of changes.
  private func observeHasTrack() {
    let hasTrack = withObservationTracking {
      sharedPlayer.hasTrack
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in self?.observeHasTrack() }
    }
    updateAccessory(hasTrack: hasTrack)
  }

  /// The bar may collapse on scroll only while the accessory exists (the
  /// Apple Music behaviour: bar and mini player condense together). The
  /// accessory's trait flip is also the only signal driving the icon-only
  /// pill swap, so with no track loaded a minimized pill would be stuck with
  /// its baked label — scrolling must not collapse the bar then.
  /// (UIKit additionally engages minimize only once a tab's scroll view has
  /// ~a screen's worth of overflow; today's fixture feeds sit under that.)
  private func updateAccessory(hasTrack: Bool) {
    if hasTrack {
      guard bottomAccessory == nil else { return }
      let host = accessoryHost ?? makeAccessoryHost()
      // The system supplies the Liquid Glass pill; we only hand it content.
      setBottomAccessory(UITabAccessory(contentView: host.view), animated: true)
      tabBarMinimizeBehavior = .onScrollDown
    } else if bottomAccessory != nil {
      setBottomAccessory(nil, animated: true)
      tabBarMinimizeBehavior = .never
      // The accessory was the minimize signal; without it the items could be
      // stranded icon-only, so restore the labelled variants.
      setTabItemsIconOnly(false)
    }
  }

  /// The accessory API takes a bare view, but the hosting controller must be a
  /// child of this controller so it participates in the view-controller
  /// hierarchy (traits, appearance callbacks) like any other tab chrome.
  private func makeAccessoryHost() -> PlayerAccessoryHostingController {
    let host = PlayerAccessoryHostingController(player: sharedPlayer, imageLoader: imageLoader) {
      [weak self] in
      self?.presentNowPlaying()
    }
    addChild(host)
    host.didMove(toParent: self)
    accessoryHost = host

    // The accessory's trait collection is the only public signal of the tab
    // bar minimizing (`.inline` while collapsed) — mirror it onto the tab
    // items so the minimized pill is icon-only. See `setTabItemsIconOnly(_:)`.
    host.view.registerForTraitChanges([UITraitTabAccessoryEnvironment.self]) {
      [weak self] (accessoryView: UIView, _) in
      self?.setTabItemsIconOnly(
        accessoryView.traitCollection.tabAccessoryEnvironment == .inline
      )
    }
    return host
  }

  /// Expands the accessory into the full Now Playing, Apple-Music style. The
  /// shell owns this presentation: a `fullScreenCover` presented from inside
  /// the accessory's own tree renders but receives no touches (the accessory's
  /// system container hit-tests only the pill), so we present from the tab
  /// controller and keep the morph with UIKit's zoom transition, sourced from
  /// the accessory view. Dismissal (button or interactive swipe) pulls the
  /// player back into the pill.
  private func presentNowPlaying() {
    guard presentedViewController == nil else { return }

    let root = NowPlayingView { [weak self] in
      self?.dismiss(animated: true)
    }
    .environment(\.soundPlayer, sharedPlayer)
    .environment(\.soundContentRepository, soundRepository)
    .environment(\.imageLoader, imageLoader)
    .preferredColorScheme(.light)

    let host = UIHostingController(rootView: root)
    host.modalPresentationStyle = .fullScreen
    host.preferredTransition = .zoom { [weak self] _ in
      self?.accessoryHost?.view
    }
    present(host, animated: true)
  }

  private func host<Content: View>(
    _ view: Content,
    title: String,
    systemImage: String
  ) -> UIViewController {
    // Every tab gets the shared player, journal, and ledger: the Deep Session
    // flow presents itself as a full-screen cover from inside a tab's tree,
    // pauses playback on entry, and records its completion — without these it
    // would reach the environment's throwaway defaults and credit nobody.
    let rootView = view
      .environment(\.soundPlayer, sharedPlayer)
      .environment(\.soundContentRepository, soundRepository)
      .environment(\.practiceStore, practiceStore)
      .environment(\.heartLedger, heartLedger)
      .environment(\.imageLoader, imageLoader)
    let controller = UIHostingController(rootView: rootView)
    controller.view.backgroundColor = .clear
    controller.tabBarItem = tabItem(title: title, systemImage: systemImage)
    return controller
  }

  /// Builds a tab item whose icon and label are baked into one image. The iOS 26
  /// Liquid Glass tab bar refuses to tint the unselected (`.normal`) state:
  /// template icons fall back to `UIColor.label` and labels render black, no
  /// matter what we set via `unselectedItemTintColor`, the per-bar/per-item
  /// appearance, or the UIAppearance proxy. To get full control we draw the icon
  /// and label into a single `.alwaysOriginal` image — which the bar displays
  /// verbatim — and clear the system title. Both states use the same image, so
  /// selected and unselected read identically (the glass capsule still marks the
  /// active tab).
  private func tabItem(title: String, systemImage: String) -> UITabBarItem {
    let full = composedItemImage(systemImage: systemImage, title: title, showsTitle: true)
    let iconOnly = composedItemImage(systemImage: systemImage, title: title, showsTitle: false)
    let item = UITabBarItem(title: nil, image: full, selectedImage: full)
    item.imageInsets = .zero
    composedItems.append(ComposedTabItem(item: item, full: full, iconOnly: iconOnly))
    return item
  }

  /// Swaps every item between its icon+label and icon-only image as the tab
  /// bar minimizes/expands: the system's minimized pill is icon-only, but our
  /// labels are baked into the images, so the swap is manual. There is no
  /// public "minimized" state on UITabBarController (verified: no layout pass,
  /// no trait change, no contentLayoutGuide movement reaches this controller
  /// when the bar collapses) — but the bottom accessory's trait collection
  /// flips to `.inline` exactly then, so while a track is loaded (the
  /// accessory exists) the swap tracks minimize precisely. With no accessory
  /// there is no signal and the pill keeps its label — accepted trade-off.
  private func setTabItemsIconOnly(_ iconOnly: Bool) {
    guard iconOnly != isTabBarMinimized else { return }
    isTabBarMinimized = iconOnly

    for entry in composedItems {
      let image = iconOnly ? entry.iconOnly : entry.full
      entry.item.image = image
      entry.item.selectedImage = image
    }

    // Unselected items repaint immediately, but the *selected* item's Liquid
    // Glass capsule keeps rendering the old image for a couple of seconds
    // after an in-place `selectedImage` change (verified on expand — the
    // selected tab sat stale while its siblings were already restored).
    // Reasserting the selection repaints the capsule's *content* right away;
    // its *geometry* never changes because both image variants share one
    // canvas (see `composedItemImage`). Programmatic selection changes don't
    // fire the delegate, but `isReassertingSelection` guards the same-tab
    // scroll-to-top anyway: `isTabBarMinimized` was just cleared above, so a
    // spurious callback here would otherwise scroll on every bar expansion.
    isReassertingSelection = true
    selectedIndex = selectedIndex
    isReassertingSelection = false
  }

  /// Renders an SF Symbol above its label (or alone, when `showsTitle` is
  /// false — the minimized bar's variant) as one lavender, `.alwaysOriginal`
  /// image so the tab bar shows it without applying its own (uncustomisable)
  /// unselected tint.
  ///
  /// Both variants are drawn on the SAME canvas — sized for icon + gap + label
  /// even when the label is omitted, with the lone icon vertically centred.
  /// This is deliberate: the images are swapped while the tab bar's
  /// minimize/expand animation is in flight, and the system animator owns the
  /// selected capsule's frame during that transition. A variant with different
  /// dimensions changes the item's intrinsic size mid-flight, which the
  /// animator absorbs for a couple of seconds — the selected tab rendered its
  /// new image clipped to the old capsule bounds. Identical canvases make the
  /// swap pixels-only, so there is no geometry for the animator to fight.
  private func composedItemImage(systemImage: String, title: String, showsTitle: Bool) -> UIImage {
    let tint = UIColor.lavenderMist
    let symbolConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
    let icon = (UIImage(systemName: systemImage, withConfiguration: symbolConfig) ?? UIImage())
      .withTintColor(tint, renderingMode: .alwaysOriginal)

    let font = UIFont.systemFont(ofSize: 10, weight: .medium)
    let textAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: tint]
    let textSize = (title as NSString).size(withAttributes: textAttributes)

    let gap: CGFloat = 3
    let width = ceil(max(icon.size.width, textSize.width))
    let height = ceil(icon.size.height + gap + textSize.height)

    let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
    let composed = renderer.image { _ in
      let iconX = (width - icon.size.width) / 2
      if showsTitle {
        icon.draw(at: CGPoint(x: iconX, y: 0))
        let textX = (width - textSize.width) / 2
        (title as NSString).draw(
          at: CGPoint(x: textX, y: icon.size.height + gap),
          withAttributes: textAttributes
        )
      } else {
        icon.draw(at: CGPoint(x: iconX, y: (height - icon.size.height) / 2))
      }
    }
    // Belt-and-suspenders: keep the composed pixels exactly as drawn.
    return composed.withRenderingMode(.alwaysOriginal)
  }

  // MARK: - Scroll to top on same-tab tap

  private func scrollSelectedTabToTop() {
    guard let root = selectedViewController?.view,
          let scrollView = Self.frontmostVerticalScrollView(in: root) else { return }
    scrollView.setContentOffset(
      CGPoint(x: scrollView.contentOffset.x, y: -scrollView.adjustedContentInset.top),
      animated: true
    )
  }

  /// Finds the scroll view the user perceives as "the screen": a frontmost-first
  /// DFS (reversed sibling order, so a pushed detail beats anything left behind
  /// it) over the visible hierarchy, matching the node before its children so
  /// the outer home scroll view wins over anything nested inside it. The
  /// vertical-scrollability filter skips the horizontal shelf scroll views.
  /// Screens without a scroll view (the Profile tab) yield nil — a no-op.
  private static func frontmostVerticalScrollView(in view: UIView) -> UIScrollView? {
    guard view.window != nil, !view.isHidden, view.alpha > 0.01 else { return nil }
    if let scrollView = view as? UIScrollView, isVerticallyScrollable(scrollView) {
      return scrollView
    }
    for subview in view.subviews.reversed() {
      if let found = frontmostVerticalScrollView(in: subview) { return found }
    }
    return nil
  }

  private static func isVerticallyScrollable(_ scrollView: UIScrollView) -> Bool {
    guard scrollView.bounds.height > 0 else { return false }
    let insets = scrollView.adjustedContentInset
    let visibleHeight = scrollView.bounds.height - insets.top - insets.bottom
    return scrollView.contentSize.height > visibleHeight + 1 || scrollView.alwaysBounceVertical
  }
}

extension MainTabController: UITabBarControllerDelegate {
  func tabBarController(
    _ tabBarController: UITabBarController,
    shouldSelect viewController: UIViewController
  ) -> Bool {
    // Tapping the tab you're already on scrolls it back to the top — but only
    // while the bar is expanded (a minimized-pill tap just expands the bar),
    // never for the repaint reassertion, and never underneath a modal.
    if viewController === selectedViewController,
       !isTabBarMinimized,
       !isReassertingSelection,
       viewController.presentedViewController == nil {
      scrollSelectedTabToTop()
    }
    return true
  }
}
