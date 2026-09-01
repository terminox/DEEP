import SwiftUI

/// Coordinator view for the You tab — the business-specific composition root.
/// It owns navigation (playlist → settings) and nothing else.
///
/// Per the project's SwiftUI rules a coordinator keeps styling to a minimum:
/// the atmosphere lives in `PlaylistView`, the leaf, so it renders behind that
/// screen's content rather than behind the `NavigationStack`.
struct YouCoordinatorView: View {
  @State private var path = NavigationPath()

  /// The destinations this tab pushes — settings, and the two preference
  /// screens it opens onto.
  private enum Route: Hashable {
    case settings
    case language
    case dailyReminder
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
          case .language:
            LanguageView()
          case .dailyReminder:
            DailyReminderView()
          }
        }
    }
    .environment(\.openSettings, { path.append(Route.settings) })
    .environment(\.openLanguage, { path.append(Route.language) })
    .environment(\.openDailyReminder, { path.append(Route.dailyReminder) })
    .preferredColorScheme(.light)
  }
}

extension EnvironmentValues {
  /// Pushes the system settings onto the You tab's navigation path. The
  /// coordinator injects the real append; the header's gear calls it from a
  /// plain `Button`, so all routing flows through the one `NavigationPath`.
  /// The default is a no-op that keeps previews hermetic.
  @Entry var openSettings: () -> Void = {}

  /// Pushes the language picker. Injected by the You coordinator; Settings
  /// calls it from a plain `Button` so routing stays in the one path.
  @Entry var openLanguage: () -> Void = {}

  /// Pushes the daily reminder screen, on the same terms.
  @Entry var openDailyReminder: () -> Void = {}
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
