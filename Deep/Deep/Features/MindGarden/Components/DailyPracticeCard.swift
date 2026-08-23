import SwiftUI

/// The primary call to action on the home — a gentle nudge into today's
/// practice. Today's progress rides the play button itself as a soft ring,
/// with the minutes resting beneath it, so the card stays a single quiet row.
struct DailyPracticeCard: View {
  var state: GardenState
  /// The selected plant's display name ("Sakura"); nil while the garden is
  /// still loading, when the copy falls back to the plant-agnostic "garden".
  var plantName: String? = nil
  var action: () -> Void = {}

  private var headline: String {
    state.minutesRemaining == 0 ? "Today’s goal complete" : "Tend your garden"
  }

  private var subtitle: String {
    state.minutesRemaining == 0
      ? "Return tomorrow for new growth"
      : "Each session feeds your \(plantName?.lowercased() ?? "garden")"
  }

  private var accessibilitySummary: String {
    state.minutesRemaining == 0
      ? "Today’s goal complete, \(state.minutesToday) of \(state.dailyGoalMinutes) minutes"
      : "Begin today’s practice, \(state.minutesToday) of \(state.dailyGoalMinutes) minutes complete"
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 5) {
          Text("TODAY’S PRACTICE")
            .font(DeepType.micro)
            .tracking(.microTracking)
            .foregroundStyle(.driftGrey)
          Text(headline)
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
          Text(subtitle)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        progressDial
      }
      .padding(20)
      .frostedCard()
    }
    .buttonStyle(.softPress)
    .accessibilityLabel(accessibilitySummary)
  }

  /// The play button inside today's ring, minutes beneath — one column that
  /// tells the whole progress story without a separate meter row.
  private var progressDial: some View {
    VStack(spacing: 6) {
      ZStack {
        CompassionRing(
          segments: [RingSegment(share: state.progress, colors: [.lavenderMist, .blushPowder])],
          lineWidth: 3.5,
          gap: 0
        )
        .frame(width: 69, height: 69)

        playCircle
      }
      Text("\(state.minutesToday) of \(state.dailyGoalMinutes) min")
        .font(DeepType.micro)
        .foregroundStyle(.driftGrey)
        .contentTransition(.numericText())
        .monospacedDigit()
    }
  }

  private var playCircle: some View {
    Image(systemName: state.minutesRemaining == 0 ? "checkmark" : "play.fill")
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
      DailyPracticeCard(state: .sample, plantName: "Oak")
      DailyPracticeCard(state: .fresh, plantName: "Sakura")
      // No plant yet (garden still loading) — the copy falls back to "garden".
      DailyPracticeCard(state: .fresh)
      DailyPracticeCard(state: .flourishing, plantName: "Oak")
    }
    .padding(.edge)
  }
}
