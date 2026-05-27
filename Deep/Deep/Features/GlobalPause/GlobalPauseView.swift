import SwiftUI

struct GlobalPauseView: View {
  let nextSessionStart: Date

  init(nextSessionStart: Date = Date().addingTimeInterval(60 * 60 + 18 * 60 + 42)) {
    self.nextSessionStart = nextSessionStart
  }

  @State private var isNotifyEnabled = false
  @State private var hasJoinedSession = false

  private let sessionDuration: TimeInterval = 20 * 60
  private let pauses = CountryPause.samples
  private let liveParticipantCount = 128_756
  private let rsvpCount = 142

  var body: some View {
    ZStack(alignment: .top) {
      AtmosphereBackground()

      TimelineView(.periodic(from: .now, by: 1)) { context in
        let remaining = sessionRemaining(now: context.date)
        let isActive = remaining != nil

        ScrollView(showsIndicators: false) {
          VStack(spacing: DeepSpacing.rhythm) {
            if let remaining {
              ActiveSessionHero(
                remaining: remaining,
                participantCount: liveParticipantCount,
                hasJoined: $hasJoinedSession
              )
              .padding(.horizontal, DeepSpacing.edge)
              .padding(.top, 32)

              LiveAroundWorldSection(pauses: pauses)
            } else {
              NextPauseCard(
                scheduleLine: scheduleLine(for: nextSessionStart),
                target: nextSessionStart,
                rsvpCount: rsvpCount,
                isNotifyEnabled: $isNotifyEnabled
              )
              .padding(.horizontal, DeepSpacing.edge)
              .padding(.top, 56)
            }

            Color.clear.frame(height: 32)
          }
          .padding(.top, 16)
          .animation(DeepMotion.bloom, value: isActive)
        }
        .scrollBounceBehavior(.basedOnSize)
      }
    }
    .preferredColorScheme(.light)
  }

  private func sessionRemaining(now: Date) -> TimeInterval? {
    let elapsed = now.timeIntervalSince(nextSessionStart)
    guard elapsed >= 0, elapsed < sessionDuration else { return nil }
    return sessionDuration - elapsed
  }

  private func scheduleLine(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "H:mm"
    let timeStr = formatter.string(from: date)
    let prefix = Calendar.current.isDateInToday(date) ? "Today" : "Tomorrow"
    return "\(prefix) · \(timeStr) Thailand Time"
  }
}

private struct ActiveSessionHero: View {
  let remaining: TimeInterval
  let participantCount: Int
  @Binding var hasJoined: Bool

  var body: some View {
    VStack(spacing: 22) {
      VStack(spacing: 6) {
        Text("Session in progress")
          .font(DeepType.caption)
          .tracking(0.4)
          .foregroundStyle(DeepColor.driftGrey)

        Text(remainingLabel)
          .font(DeepType.micro)
          .tracking(1.2)
          .foregroundStyle(DeepColor.lavenderMist)
      }

      ParticipantsCounter(count: participantCount)

      joinButton
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 30)
    .padding(.horizontal, 24)
    .frostedCard()
  }

  private var remainingLabel: String {
    let minutes = max(1, Int((remaining / 60).rounded(.up)))
    return "\(minutes) MIN LEFT"
  }

  private var joinButton: some View {
    Button {
      withAnimation(DeepMotion.settle) { hasJoined.toggle() }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: hasJoined ? "checkmark" : "heart.fill")
          .font(.system(.footnote, design: .rounded, weight: .semibold))
        Text(hasJoined ? "You're in" : "Join now")
          .font(DeepType.body.weight(.medium))
      }
      .foregroundStyle(.white)
      .padding(.horizontal, 22)
      .padding(.vertical, 11)
      .background(
        Capsule().fill(
          LinearGradient(
            colors: [DeepColor.lavenderMist, DeepColor.blushPowder],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
      )
      .shadow(color: DeepColor.lavenderMist.opacity(0.4), radius: 10, x: 0, y: 5)
    }
    .buttonStyle(.softPress)
    .accessibilityLabel(hasJoined
      ? "You have joined this session"
      : "Join the global pause now")
  }
}

#Preview("Global Pause — Pre-session") {
  GlobalPauseView(
    nextSessionStart: Date().addingTimeInterval(60 * 90)
  )
}

#Preview("Global Pause — In-session") {
  GlobalPauseView(
    nextSessionStart: Date().addingTimeInterval(-5 * 60)
  )
}

#Preview("Global Pause • Dynamic Type XL") {
  GlobalPauseView(
    nextSessionStart: Date().addingTimeInterval(60 * 90)
  )
  .environment(\.dynamicTypeSize, .xLarge)
}
