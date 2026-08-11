import SwiftUI

/// The primary call to action on the home — a gentle nudge into today's
/// practice, carrying today's progress toward the daily goal. Every finished
/// session feeds the oak, so the card ties the two together.
struct DailyPracticeCard: View {
  var minutesToday: Int
  var dailyGoalMinutes: Int
  var action: () -> Void = {}

  private var minutesRemaining: Int {
    max(0, dailyGoalMinutes - minutesToday)
  }

  private var progress: Double {
    guard dailyGoalMinutes > 0 else { return 0 }
    return min(1, Double(minutesToday) / Double(dailyGoalMinutes))
  }

  private var headline: String {
    minutesRemaining == 0 ? "Today’s goal complete" : "Tend your garden"
  }

  private var subtitle: String {
    minutesRemaining == 0
      ? "Your oak drank deep — return tomorrow"
      : "\(minutesRemaining) min more — each session feeds your oak"
  }

  private var accessibilitySummary: String {
    minutesRemaining == 0
      ? "Today’s goal complete, \(minutesToday) of \(dailyGoalMinutes) minutes"
      : "Begin today’s practice, \(minutesToday) of \(dailyGoalMinutes) minutes complete"
  }

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 16) {
          VStack(alignment: .leading, spacing: 5) {
            Text("TODAY’S PRACTICE")
              .font(DeepType.micro)
              .tracking(1.4)
              .foregroundStyle(.driftGrey)
            Text(headline)
              .font(DeepType.displayTitle)
              .foregroundStyle(.deepPlum)
            Text(subtitle)
              .font(DeepType.caption)
              .foregroundStyle(.driftGrey)
          }
          Spacer(minLength: 8)
          playCircle
        }

        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Today’s progress")
              .font(DeepType.caption)
              .foregroundStyle(.driftGrey)
            Spacer()
            Text("\(minutesToday) / \(dailyGoalMinutes) min")
              .font(DeepType.counter)
              .foregroundStyle(.deepPlum)
              .monospacedDigit()
          }
          GardenMeterBar(progress: progress)
        }
      }
      .padding(20)
      .frostedCard()
    }
    .buttonStyle(.softPress)
    .accessibilityLabel(accessibilitySummary)
  }

  private var playCircle: some View {
    Image(systemName: minutesRemaining == 0 ? "checkmark" : "play.fill")
      .font(.system(size: 18, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: 54, height: 54)
      .background(
        Circle().fill(LinearGradient(
          colors: [.lavenderMist, .softLilac],
          startPoint: .topLeading, endPoint: .bottomTrailing
        ))
      )
      .shadow(color: .lavenderMist.opacity(0.4), radius: 12, x: 0, y: 6)
  }
}

#Preview("Daily practice") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: 16) {
      DailyPracticeCard(minutesToday: 7, dailyGoalMinutes: 10)
      DailyPracticeCard(minutesToday: 0, dailyGoalMinutes: 10)
      DailyPracticeCard(minutesToday: 10, dailyGoalMinutes: 10)
    }
    .padding(.edge)
  }
}
