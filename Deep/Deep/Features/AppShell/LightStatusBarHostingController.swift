import UIKit
import SwiftUI

/// A hosting controller that keeps the status bar light — for screens laid
/// over a full-bleed photograph (Now Playing), where the light-scheme default
/// would draw a dark clock across the image.
final class LightStatusBarHostingController<Content: View>: UIHostingController<Content> {
  override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
