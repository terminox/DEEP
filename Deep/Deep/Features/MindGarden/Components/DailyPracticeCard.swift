import SwiftUI

/// The primary call to action on the home — a gentle nudge into today's practice,
/// the session that waters the garden and closes the daily goal.
struct DailyPracticeCard: View {
  var minutesRemaining: Int
  var action: () -> Void = {}

  private var headline: String {
    minutesRemaining == 0 ? "Today’s goal complete" : "Tend your garden"
  }

  private var subtitle: String {
    minutesRemaining == 0
      ? "Come back tomorrow to keep the streak"
      : "\(minutesRemaining) min to reach today’s goal"
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 5) {
          Text("TODAY’S PRACTICE")
            .font(DeepType.micro)
            .tracking(1.4)
            .foregroundStyle(DeepColor.driftGrey)
          Text(headline)
            .font(DeepType.displayTitle)
            .foregroundStyle(DeepColor.deepPlum)
          Text(subtitle)
            .font(DeepType.caption)
            .foregroundStyle(DeepColor.driftGrey)
        }
        Spacer(minLength: 8)
        playCircle
      }
      .padding(20)
      .frostedCard()
    }
    .buttonStyle(.softPress)
    .accessibilityLabel("Begin today’s practice")
  }

  private var playCircle: some View {
    Image(systemName: minutesRemaining == 0 ? "checkmark" : "play.fill")
      .font(.system(size: 18, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: 54, height: 54)
      .background(
        Circle().fill(LinearGradient(
          colors: [DeepColor.lavenderMist, DeepColor.softLilac],
          startPoint: .topLeading, endPoint: .bottomTrailing
        ))
      )
      .shadow(color: DeepColor.lavenderMist.opacity(0.4), radius: 12, x: 0, y: 6)
  }
}

#Preview("Daily practice") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: 16) {
      DailyPracticeCard(minutesRemaining: 3)
      DailyPracticeCard(minutesRemaining: 0)
    }
    .padding(DeepSpacing.edge)
  }
}
