import UIKit
import SwiftUI

/// The app's root shell, built in UIKit. Each tab hosts a SwiftUI feature via
/// `UIHostingController`. New tabs are added by appending to `viewControllers`.
final class MainTabController: UITabBarController {
  override func viewDidLoad() {
    super.viewDidLoad()
    configureChildren()
    configureAppearance()
  }

  private func configureChildren() {
    let globalPause = host(
      GlobalPauseView(),
      title: "Global Pause",
      systemImage: "globe.asia.australia.fill"
    )

    // Deep Sound dims the tab bar while Now Playing is open so the player
    // reads as full-screen, the way Apple Music's player covers the bar.
    let sounds = host(
      DeepSoundView(onNowPlayingVisibilityChange: { [weak self] isOpen in
        self?.setTabBarHidden(isOpen)
      }),
      title: "Sounds",
      systemImage: "waveform"
    )

    let garden = host(
      MindGardenView(),
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
    controller.tabBarItem = UITabBarItem(
      title: title,
      image: UIImage(systemName: systemImage),
      selectedImage: UIImage(systemName: systemImage)
    )
    return controller
  }

  private func configureAppearance() {
    // Don't install a custom UITabBarAppearance background — that opts out of
    // the system Liquid Glass tab bar on iOS 26. Only tint the items.
    tabBar.tintColor = UIColor(red: 0.722, green: 0.655, blue: 0.910, alpha: 1) // lavenderMist
    tabBar.unselectedItemTintColor = UIColor(red: 0.545, green: 0.510, blue: 0.659, alpha: 1) // driftGrey
  }

  /// Fade the tab bar without changing layout, so the SwiftUI content behind
  /// it (which already fills the screen) shows through.
  private func setTabBarHidden(_ hidden: Bool) {
    UIView.animate(withDuration: 0.45, delay: 0, options: [.curveEaseInOut]) {
      self.tabBar.alpha = hidden ? 0 : 1
    }
  }
}
