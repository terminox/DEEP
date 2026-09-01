import SwiftUI

/// The language picker, pushed from Settings.
///
/// Two rows and no symbol column — every row here is the same kind of
/// choice, so a repeating icon would only add noise. Each language is named in
/// its own language, which is the only labelling that stays legible whichever
/// language the screen is currently showing.
///
/// There is no row for following the device: Deep already does that until
/// someone picks, so the device's language is simply the one arriving checked.
struct LanguageView: View {
  @Environment(\.languageStore) private var languageStore
  @Environment(\.practiceStore) private var practiceStore
  @Environment(\.reminderStore) private var reminderStore

  var body: some View {
    ZStack {
      AtmosphereBackground()

      ScrollView {
        VStack(alignment: .leading, spacing: .rhythm) {
          SettingsSection {
            ForEach(AppLanguage.allCases) { language in
              SettingsRow(
                title: language.endonym,
                accessory: languageStore.selection == language ? .check : .none
              ) {
                select(language)
              }
            }
          }
          Text("Deep reads in this language everywhere, including the reminders it sends you.")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, .edge)
        .padding(.top, .rhythm)
        .padding(.bottom, 40)
      }
      .scrollIndicators(.hidden)
    }
    .navigationTitle("Language")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
  }

  /// Adopting a language re-keys the view tree from `AppRootView`, but pending
  /// notifications were written in the old one — their copy was resolved when
  /// they were scheduled, not when they fire — so the queue is rebuilt here.
  ///
  /// The already-checked row is still a real tap: it pins a language that was
  /// so far only matching the device. Nothing on screen changes, so nothing has
  /// to be rescheduled either.
  private func select(_ language: AppLanguage) {
    let changed = languageStore.selection != language
    languageStore.select(language)
    guard changed else { return }
    Task {
      await reminderStore.reschedule(
        goalMetToday: practiceStore.minutesToday >= practiceStore.dailyGoalMinutes
      )
    }
  }
}

#if DEBUG
#Preview("Language — English") {
  NavigationStack {
    LanguageView()
      .environment(\.languageStore, .preview)
      .environment(\.reminderStore, .previewOff)
  }
}

#Preview("Language — Thai") {
  NavigationStack {
    LanguageView()
      .environment(\.languageStore, .previewThai)
      .environment(\.reminderStore, .previewOff)
  }
}
#endif
