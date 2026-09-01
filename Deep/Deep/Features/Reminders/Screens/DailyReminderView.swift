import SwiftUI

/// The daily reminder screen, pushed from Settings.
///
/// This is the first system permission Deep has ever asked for, so the screen
/// explains itself before the switch is touched rather than after — a refusal
/// here can only be undone in iOS Settings, so it's worth one sentence to
/// avoid earning one.
struct DailyReminderView: View {
  @Environment(\.reminderStore) private var reminderStore
  @Environment(\.practiceStore) private var practiceStore
  @Environment(\.openURL) private var openURL

  @State private var pickedTime = Date()

  private var goalMetToday: Bool {
    practiceStore.minutesToday >= practiceStore.dailyGoalMinutes
  }

  var body: some View {
    ZStack {
      AtmosphereBackground()

      ScrollView {
        VStack(alignment: .leading, spacing: .rhythm) {
          intro
          SettingsSection {
            SettingsToggleRow(
              icon: "bell",
              title: "Daily reminder",
              isOn: Binding(
                get: { reminderStore.reminder.isEnabled },
                set: { wantsOn in Task { await setEnabled(wantsOn) } }
              )
            )
            if reminderStore.reminder.isEnabled {
              SettingsTimeRow(icon: "clock", title: "Time", date: $pickedTime)
            }
          }
          if reminderStore.permission == .denied {
            deniedNote
          } else if reminderStore.reminder.isEnabled {
            skipNote
          }
        }
        .padding(.horizontal, .edge)
        .padding(.top, .rhythm)
        .padding(.bottom, 40)
      }
      .scrollIndicators(.hidden)
    }
    .navigationTitle("Daily reminder")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .animation(.settle, value: reminderStore.reminder.isEnabled)
    .animation(.settle, value: reminderStore.permission)
    .task {
      pickedTime = reminderStore.reminder.pickerDate()
      await reminderStore.refreshPermission()
    }
    .onChange(of: pickedTime) { _, newValue in
      Task { await reminderStore.setTime(newValue, goalMetToday: goalMetToday) }
    }
  }

  // MARK: - Copy

  private var intro: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("A quiet nudge, once a day")
        .font(DeepType.displayTitle)
        .foregroundStyle(.deepPlum)
      Text("Deep will send one gentle note at the time you choose. No streak to defend, nothing to catch up on.")
        .font(DeepType.body)
        .foregroundStyle(.driftGrey)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 8)
  }

  private var skipNote: some View {
    Text("On days you've already practised, the reminder stays quiet.")
      .font(DeepType.caption)
      .foregroundStyle(.driftGrey)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 8)
  }

  private var deniedNote: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Notifications are switched off for Deep, so the reminder can't reach you. You can turn them back on in iOS Settings.")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .fixedSize(horizontal: false, vertical: true)
      Button("Open Settings") {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
      }
      .font(DeepType.body)
      .foregroundStyle(.deepPlum)
    }
    .padding(.horizontal, 8)
  }

  // MARK: - Actions

  private func setEnabled(_ wantsOn: Bool) async {
    if wantsOn {
      await reminderStore.enable(goalMetToday: goalMetToday)
      pickedTime = reminderStore.reminder.pickerDate()
    } else {
      await reminderStore.disable()
    }
  }
}

#if DEBUG
#Preview("Reminder — never asked") {
  NavigationStack {
    DailyReminderView()
      .environment(\.reminderStore, .previewOff)
  }
}

#Preview("Reminder — on") {
  NavigationStack {
    DailyReminderView()
      .environment(\.reminderStore, .previewOn)
  }
}

#Preview("Reminder — refused") {
  NavigationStack {
    DailyReminderView()
      .environment(\.reminderStore, .previewDenied)
  }
}
#endif
