import UIKit

/// Which way DEEP may turn, decided at runtime. Every screen is portrait
/// unless it asks otherwise while it is on screen; today only the Aurora
/// experiment does.
///
/// `Info.plist` lists portrait and both landscapes so landscape is *possible*;
/// `DeepAppDelegate` narrows that to `mask` for every window, which keeps the
/// tab shell, DEEP Session, Global Pause and every UIKit presentation portrait
/// without each of them overriding `supportedInterfaceOrientations`.
enum OrientationLock {
  private(set) static var mask: UIInterfaceOrientationMask = .portrait

  /// Sets the allowed orientations and makes the window honour them now:
  /// leaving a landscape screen rotates straight back to portrait.
  static func allow(_ newMask: UIInterfaceOrientationMask) {
    guard newMask != mask else { return }
    mask = newMask
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for scene in scenes {
      for window in scene.windows {
        var controller = window.rootViewController
        while let current = controller {
          current.setNeedsUpdateOfSupportedInterfaceOrientations()
          controller = current.presentedViewController
        }
      }
      scene.requestGeometryUpdate(.iOS(interfaceOrientations: newMask))
    }
  }
}

/// The app delegate exists for one answer: which orientations each window may
/// use right now (see `OrientationLock`).
final class DeepAppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    OrientationLock.mask
  }
}
