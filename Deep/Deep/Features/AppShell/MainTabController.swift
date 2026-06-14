import UIKit
import SwiftUI

/// The app's root shell, built in UIKit. Each tab hosts a SwiftUI feature via
/// `UIHostingController`. New tabs are added by appending to `viewControllers`.
final class MainTabController: UITabBarController {
  override func viewDidLoad() {
    super.viewDidLoad()
    configureChildren()
    // No custom UITabBarAppearance is installed: that keeps the system Liquid
    // Glass tab bar (iOS 26). Item colours are baked into the item images in
    // `host(_:title:systemImage:)` instead — see the note there.
  }

  private func configureChildren() {
    let globalPause = host(
      GlobalPauseCoordinatorView(),
      title: "Global Pause",
      systemImage: "globe.asia.australia.fill"
    )

    // Deep Sound dims the tab bar while Now Playing is open so the player
    // reads as full-screen, the way Apple Music's player covers the bar.
    let sounds = host(
      DeepSoundCoordinatorView(onNowPlayingVisibilityChange: { [weak self] isOpen in
        self?.setTabBarHidden(isOpen)
      }),
      title: "Sounds",
      systemImage: "waveform"
    )

    let garden = host(
      MindGardenCoordinatorView(),
      title: "Garden",
      systemImage: "leaf.fill"
    )

    let portfolio = host(
      CompassionPortfolioView(),
      title: "Portfolio",
      systemImage: "heart.fill"
    )

    viewControllers = [globalPause, sounds, garden, portfolio]
  }

  private func host<Content: View>(
    _ view: Content,
    title: String,
    systemImage: String
  ) -> UIViewController {
    let controller = UIHostingController(rootView: view)
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

  /// Fade the tab bar without changing layout, so the SwiftUI content behind
  /// it (which already fills the screen) shows through.
  private func setTabBarHidden(_ hidden: Bool) {
    UIView.animate(withDuration: 0.45, delay: 0, options: [.curveEaseInOut]) {
      self.tabBar.alpha = hidden ? 0 : 1
    }
  }
}
