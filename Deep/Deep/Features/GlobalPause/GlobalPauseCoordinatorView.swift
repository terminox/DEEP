import SwiftUI

/// Composition root for the Global Pause tab. Owns the navigation path and wires
/// leaf screens to it: cards append a `HomeItem` via the injected `openHomeItem`
/// action, and `navigationDestination` resolves it to a detail screen. Styling
/// lives in the leaf screens (see CLAUDE.md) — this view only composes and routes.
struct GlobalPauseCoordinatorView: View {
  @State private var path = NavigationPath()

  private let tabBarInset: CGFloat = 100

  var body: some View {
    NavigationStack(path: $path) {
      GlobalPauseHomeView(bottomInset: tabBarInset)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: HomeItem.self) { item in
          HomeItemDetailView(item: item)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    .environment(\.openHomeItem) { item in path.append(item) }
    .preferredColorScheme(.light)
  }
}

extension EnvironmentValues {
  /// Routes a tapped home item to the coordinator's navigation path. Defaults to
  /// a no-op so leaf screens stay previewable without a live coordinator.
  @Entry var openHomeItem: (HomeItem) -> Void = { _ in }
}

#Preview("Global Pause Coordinator") {
  GlobalPauseCoordinatorView()
}
