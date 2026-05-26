import SwiftUI

struct ParticipantsCounter: View {
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.system(.subheadline, design: .rounded, weight: .regular))
                .foregroundStyle(DeepColor.lavenderMist)
                .padding(9)
                .background(
                    Circle().fill(.white.opacity(0.7))
                        .background(Circle().fill(.ultraThinMaterial))
                )
                .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 0.5))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(formatted)
                    .font(DeepType.bigNumber)
                    .foregroundStyle(DeepColor.deepPlum)
                    .contentTransition(.numericText())
                    .monospacedDigit()
                Text("people pausing with you")
                    .font(DeepType.caption)
                    .foregroundStyle(DeepColor.driftGrey)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(count) people pausing with you")

            Spacer(minLength: 0)
        }
    }

    private var formatted: String {
        count.formatted(.number.grouping(.automatic))
    }
}

#Preview {
    ParticipantsCounter(count: 128_756)
        .padding()
        .background(DeepColor.moonCream)
}
