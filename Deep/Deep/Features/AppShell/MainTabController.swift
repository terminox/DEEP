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

  /// One player shared across the tabs, so a sound started in Global Pause and
  /// a sound started in Sounds drive the same bottom accessory and Now Playing.
  private let sharedPlayer: any SoundPlaying = SoundPlayer()
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

  init(onboardingStore: any OnboardingProgressStore, accountStore: any AccountStore) {
    self.onboardingStore = onboardingStore
    self.accountStore = accountStore
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    configureChildren()
    // No custom UITabBarAppearance is installed: that keeps the system Liquid
    // Glass tab bar (iOS 26). Item colours are baked into the item images in
    // `host(_:title:systemImage:)` instead — see the note there.

    // Scrolling down collapses the tab bar and the bottom accessory condenses
    // into an inline pill beside it (the Apple Music behaviour). UIKit only
    // engages this once a tab's scroll view has enough overflow (~a screen's
    // worth); today's fixture feeds sit under that, so the bar stays put
    // until real content lengthens them — verified against a long feed.
    tabBarMinimizeBehavior = .onScrollDown
    observeHasTrack()
  }

  private func configureChildren() {
    // Global Pause is a UIKit coordinator, so it slots in directly — no hosting
    // wrapper — and receives the deep-session action explicitly (the SwiftUI
    // environment can't cross this boundary).
    let globalPause = GlobalPauseCoordinatorController(
      soundPlayer: sharedPlayer,
      startDeepSession: { [weak self] session in self?.presentDeepSession(session) })
    globalPause.tabBarItem = tabItem(title: "Global Pause", systemImage: "globe.asia.australia.fill")

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
        .environment(\.accountStore, accountStore),
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

  private func updateAccessory(hasTrack: Bool) {
    if hasTrack {
      guard bottomAccessory == nil else { return }
      let host = accessoryHost ?? makeAccessoryHost()
      // The system supplies the Liquid Glass pill; we only hand it content.
      setBottomAccessory(UITabAccessory(contentView: host.view), animated: true)
    } else if bottomAccessory != nil {
      setBottomAccessory(nil, animated: true)
      // The accessory was the minimize signal; without it the items could be
      // stranded icon-only, so restore the labelled variants.
      setTabItemsIconOnly(false)
    }
  }

  /// The accessory API takes a bare view, but the hosting controller must be a
  /// child of this controller so it participates in the view-controller
  /// hierarchy (traits, appearance callbacks) like any other tab chrome.
  private func makeAccessoryHost() -> PlayerAccessoryHostingController {
    let host = PlayerAccessoryHostingController(player: sharedPlayer) { [weak self] in
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
    .preferredColorScheme(.light)

    let host = UIHostingController(rootView: root)
    host.modalPresentationStyle = .fullScreen
    host.preferredTransition = .zoom { [weak self] _ in
      self?.accessoryHost?.view
    }
    present(host, animated: true)
  }

  /// Presents a guided Deep Session full-screen over the tab bar. Presenting from
  /// the tab controller (rather than a per-tab cover) guarantees a single
  /// presentation that always covers the bar, no matter which tab launched it.
  private func presentDeepSession(_ session: DeepSession) {
    guard presentedViewController == nil else { return }

    let root = DeepSessionCoordinatorView(session: session) { [weak self] in
      self?.dismiss(animated: true)
    }
    let host = UIHostingController(rootView: root)
    host.modalPresentationStyle = .overFullScreen
    host.view.backgroundColor = .clear
    present(host, animated: true)
  }

  private func host<Content: View>(
    _ view: Content,
    title: String,
    systemImage: String
  ) -> UIViewController {
    // Every tab can launch a Deep Session from anywhere in its tree. Leaf screens
    // depend only on this abstract action; the shell owns presentation.
    let rootView = view.environment(\.startDeepSession) { [weak self] session in
      self?.presentDeepSession(session)
    }
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
    let full = composedItemImage(systemImage: systemImage, title: title)
    let iconOnly = composedItemImage(systemImage: systemImage, title: nil)
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
  }

  /// Renders an SF Symbol above its label (or alone, when `title` is nil — the
  /// minimized bar's variant) as one lavender, `.alwaysOriginal` image so the
  /// tab bar shows it without applying its own (uncustomisable) unselected tint.
  private func composedItemImage(systemImage: String, title: String?) -> UIImage {
    let tint = UIColor.lavenderMist
    let symbolConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
    let icon = (UIImage(systemName: systemImage, withConfiguration: symbolConfig) ?? UIImage())
      .withTintColor(tint, renderingMode: .alwaysOriginal)

    let font = UIFont.systemFont(ofSize: 10, weight: .medium)
    let textAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: tint]
    let textSize = title.map { ($0 as NSString).size(withAttributes: textAttributes) } ?? .zero

    let gap: CGFloat = title == nil ? 0 : 3
    let width = ceil(max(icon.size.width, textSize.width))
    let height = ceil(icon.size.height + gap + textSize.height)

    let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
    let composed = renderer.image { _ in
      let iconX = (width - icon.size.width) / 2
      icon.draw(at: CGPoint(x: iconX, y: 0))
      if let title {
        let textX = (width - textSize.width) / 2
        (title as NSString).draw(
          at: CGPoint(x: textX, y: icon.size.height + gap),
          withAttributes: textAttributes
        )
      }
    }
    // Belt-and-suspenders: keep the composed pixels exactly as drawn.
    return composed.withRenderingMode(.alwaysOriginal)
  }
}
