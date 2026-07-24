import SwiftUI

/// The lobby outside the nightly window: the globe keeps its slow turn while
/// the bottom half counts down to tonight and replays recent voices of peace.
struct GlobalPauseOffHoursView: View {
  @Environment(\.globalPauseSession) private var session
  @Environment(\.pauseReminder) private var reminder

  @State private var notifyEnabled = false
  @State private var recent: [PeaceMessage] = []

  var body: some View {
    VStack(spacing: .rhythm) {
      Spacer(minLength: 0)

      if case .offHours(let nextLobbyStart) = session.phase {
        NextPauseCard(
          scheduleLine: scheduleLine(for: nextLobbyStart),
          target: nextLobbyStart,
          rsvpCount: nil,
          clockOffset: session.clock.effectiveOffset,
          isNotifyEnabled: $notifyEnabled
        )
        .padding(.horizontal, .edge)
      }

      if !recent.isEmpty {
        VoicesOfPeaceSection(voices: recent.map(\.asVoiceOfPeace))
      }
    }
    .padding(.bottom, .rhythm)
    .task {
      notifyEnabled = reminder.isEnabled
      recent = await session.recentMessages(limit: 4)
    }
    .onChange(of: notifyEnabled) { _, wanted in
      guard wanted != reminder.isEnabled else { return }
      Task {
        let granted = await reminder.setEnabled(wanted)
        if granted != wanted {
          withAnimation(.settle) { notifyEnabled = granted }
        }
      }
    }
  }

  private func scheduleLine(for target: Date) -> String {
    var calendar = Calendar(identifier: .gregorian)
    let timeZone = TimeZone(identifier: session.schedule?.timezone ?? "Asia/Bangkok") ?? .current
    calendar.timeZone = timeZone
    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    formatter.dateFormat = "HH:mm"
    let day = calendar.isDate(session.clock.now, inSameDayAs: target) ? "Tonight" : "Tomorrow"
    return "\(day) · \(formatter.string(from: target)) Thailand Time"
  }
}

#Preview("Off hours") {
  ZStack {
    Color.moonCream.ignoresSafeArea()
    GlobalPauseOffHoursView()
      .environment(
        \.globalPauseSession,
        .preview(phase: .offHours(nextLobbyStart: Date().addingTimeInterval(3 * 3600)))
      )
      .environment(\.pauseReminder, MockPauseReminder())
  }
}
