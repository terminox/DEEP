import SwiftUI

struct ParticipantsCounter: View {
  let count: Int

  var body: some View {
    VStack(spacing: 4) {
      Text(formatted)
        .font(DeepType.bigNumber)
        .foregroundStyle(DeepColor.deepPlum)
        .contentTransition(.numericText())
        .monospacedDigit()
      Text("pausing right now")
        .font(DeepType.caption)
        .foregroundStyle(DeepColor.driftGrey)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(count) people pausing right now")
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
