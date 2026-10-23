import SwiftUI

/// Coordinator view for the You tab — the business-specific composition root.
/// It owns navigation (playlist → settings → the premium invitation) and
/// nothing else.
///
/// Per the project's SwiftUI rules a coordinator keeps styling to a minimum:
/// the atmosphere lives in `PlaylistView`, the leaf, so it renders behind that
/// screen's content rather than behind the `NavigationStack`.
struct YouCoordinatorView: View {
  @State private var path = NavigationPath()

  /// The destinations this tab pushes — settings, the two preference screens
  /// it opens onto, and the premium invitation.
  private enum Route: Hashable {
    case settings
    case language
    case dailyReminder
    /// A real screen on the stack, not a sheet or a cover: the paywall is a
    /// place you go, the same one the first run walks you through, and it
    /// keeps the system's back gesture rather than a lid you have to find.
    case premium(PaywallSource)
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
          case .premium(let source):
            PaywallView(source: source) { pop() }
              .toolbarVisibility(.hidden, for: .navigationBar)
          }
        }
    }
    .environment(\.openPaywall, { path.append(Route.premium($0)) })
    .environment(\.openSettings, { path.append(Route.settings) })
    .environment(\.openLanguage, { path.append(Route.language) })
    .environment(\.openDailyReminder, { path.append(Route.dailyReminder) })
    .preferredColorScheme(.light)
  }

  /// Steps back one screen. The paywall's own "Not right now" calls this, so
  /// the screen never has to know it was pushed.
  private func pop() {
    guard !path.isEmpty else { return }
    path.removeLast()
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
