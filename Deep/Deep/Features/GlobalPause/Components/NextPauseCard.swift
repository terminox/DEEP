import SwiftUI

struct NextPauseCard: View {
  let scheduleLine: String
  let target: Date
  let rsvpCount: Int
  @Binding var isNotifyEnabled: Bool

  var body: some View {
    VStack(spacing: 22) {
      VStack(spacing: 6) {
        Text("Next Global Pause")
          .font(DeepType.caption)
          .tracking(0.4)
          .foregroundStyle(DeepColor.driftGrey)

        Text(scheduleLine)
          .font(DeepType.displayTitle)
          .foregroundStyle(DeepColor.deepPlum)
          .multilineTextAlignment(.center)
      }

      CountdownView(target: target)

      VStack(spacing: 10) {
        notifyButton
        Text("\(rsvpCount.formatted()) people will join")
          .font(DeepType.caption)
          .foregroundStyle(DeepColor.driftGrey)
          .contentTransition(.numericText())
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 30)
    .padding(.horizontal, 24)
    .frostedCard()
  }

  private var notifyButton: some View {
    Button {
      withAnimation(DeepMotion.settle) { isNotifyEnabled.toggle() }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: isNotifyEnabled ? "bell.fill" : "bell")
          .font(.system(.footnote, design: .rounded, weight: .semibold))
        Text(isNotifyEnabled ? "Notified" : "Notify me")
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
    .accessibilityLabel(isNotifyEnabled
      ? "Notifications on for the next global pause"
      : "Turn on notifications for the next global pause")
  }
}

#Preview {
  NextPauseCardPreview()
}

private struct NextPauseCardPreview: View {
  @State private var notify = false
  var body: some View {
    let seconds: TimeInterval = 3600 + 18 * 60 + 42
    NextPauseCard(
      scheduleLine: "Today · 21:00 Thailand Time",
      target: Date().addingTimeInterval(seconds),
      rsvpCount: 142,
      isNotifyEnabled: $notify
    )
    .padding()
    .background(DeepColor.moonCream)
  }
}
