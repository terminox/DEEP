import SwiftUI

/// Coordinator view for the You tab — the business-specific composition root.
/// It owns navigation (playlist → settings) and nothing else.
///
/// Per the project's SwiftUI rules a coordinator keeps styling to a minimum:
/// the atmosphere lives in `PlaylistView`, the leaf, so it renders behind that
/// screen's content rather than behind the `NavigationStack`.
struct YouCoordinatorView: View {
  @State private var path = NavigationPath()

  /// The one destination this tab pushes. An enum rather than a bare value so
  /// a second settings-adjacent screen has somewhere obvious to go.
  private enum Route: Hashable {
    case settings
  }

  var body: some View {
    NavigationStack(path: $path) {
      // The bottom accessory participates in the safe area, so content clears
      // the mini player natively; `.rhythm` is pure breathing room.
      PlaylistView(bottomInset: .rhythm)
        .navigationDestination(for: Route.self) { route in
          switch route {
          case .settings:
            SettingsView()
          }
        }
    }
    .environment(\.openSettings, { path.append(Route.settings) })
    .preferredColorScheme(.light)
  }
}

extension EnvironmentValues {
  /// Pushes the system settings onto the You tab's navigation path. The
  /// coordinator injects the real append; the header's gear calls it from a
  /// plain `Button`, so all routing flows through the one `NavigationPath`.
  /// The default is a no-op that keeps previews hermetic.
  @Entry var openSettings: () -> Void = {}
}

#if DEBUG
#Preview("You — saved sounds") {
  YouCoordinatorView()
    .environment(\.playlistStore, .sample)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
    .environment(\.accountStore, MockAccountStore.emailUser)
    .environment(\.onboardingStore, MockOnboardingStore.fresh)
    .environment(\.subscriptionStore, MockSubscriptionStore.free)
}

#Preview("You — nothing saved") {
  YouCoordinatorView()
    .environment(\.playlistStore, .empty)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
    .environment(\.accountStore, MockAccountStore.appleUser)
    .environment(\.onboardingStore, MockOnboardingStore.fresh)
    .environment(\.subscriptionStore, MockSubscriptionStore.subscribed)
}
#endif
