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
  }

  private func configureChildren() {
    // One player shared across the tabs, so a sound started in Global Pause and a
    // sound started in Sounds drive the same floating mini-player and Now Playing.
    let sharedPlayer: any SoundPlaying = SoundPlayer()

    // Global Pause is a UIKit coordinator, so it slots in directly — no hosting
    // wrapper — and receives the deep-session action explicitly (the SwiftUI
    // environment can't cross this boundary).
    let globalPause = GlobalPauseCoordinatorController(
      soundPlayer: sharedPlayer,
      startDeepSession: { [weak self] session in self?.presentDeepSession(session) }
    )
    globalPause.tabBarItem = tabItem(title: "Global Pause", systemImage: "globe.asia.australia.fill")

    // Now Playing presents as a full-screen cover that covers the tab bar on its
    // own (the way Apple Music's player covers the bar), so no dimming is needed.
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
    let image = composedItemImage(systemImage: systemImage, title: title)
    let item = UITabBarItem(title: nil, image: image, selectedImage: image)
    item.imageInsets = .zero
    return item
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
