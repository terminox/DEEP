import SwiftUI

/// Bridges the UIKit `MainTabController` into the SwiftUI app entry point.
struct RootTabView: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> MainTabController {
    MainTabController()
  }

  func updateUIViewController(_ controller: MainTabController, context: Context) {}
}

#Preview {
  RootTabView()
    .ignoresSafeArea()
}
