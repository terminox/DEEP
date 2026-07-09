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
    let globalPause = host(
      GlobalPauseCoordinatorView(soundPlayer: sharedPlayer),
      title: "Global Pause",
      systemImage: "globe.asia.australia.fill"
    )

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

    // TEMPORARY: Portfolio content swapped for the known-good debug scroll to
    // isolate content vs tab-position in the minimize investigation. Restore.
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

    // The iOS 26 Liquid Glass tab bar refuses to tint the unselected (`.normal`)
    // state: template icons fall back to `UIColor.label` and labels render black,
    // no matter what we set via `unselectedItemTintColor`, the per-bar/per-item
    // appearance, or the UIAppearance proxy. To get full control we draw the icon
    // and label into a single `.alwaysOriginal` image — which the bar displays
    // verbatim — and clear the system title. Both states use the same image, so
    // selected and unselected read identically (the glass capsule still marks the
    // active tab).
    let image = composedItemImage(systemImage: systemImage, title: title)
    let tabItem = UITabBarItem(title: nil, image: image, selectedImage: image)
    tabItem.imageInsets = .zero

    controller.tabBarItem = tabItem
    return controller
  }

  /// Renders an SF Symbol above its label as one lavender, `.alwaysOriginal`
  /// image so the tab bar shows it without applying its own (uncustomisable)
  /// unselected tint.
  private func composedItemImage(systemImage: String, title: String) -> UIImage {
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
      icon.draw(at: CGPoint(x: iconX, y: 0))
      let textX = (width - textSize.width) / 2
      (title as NSString).draw(
        at: CGPoint(x: textX, y: icon.size.height + gap),
        withAttributes: textAttributes
      )
    }
    // Belt-and-suspenders: keep the composed pixels exactly as drawn.
    return composed.withRenderingMode(.alwaysOriginal)
  }
}
