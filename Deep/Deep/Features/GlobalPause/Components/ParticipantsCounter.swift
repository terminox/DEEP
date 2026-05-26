import SwiftUI

struct ParticipantsCounter: View {
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(DeepColor.lavenderMist)
                .padding(8)
                .background(
                    Circle().fill(.white.opacity(0.7))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(formatted)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(DeepColor.deepPlum)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(count) people pausing with you")
                Text("people pausing with you")
                    .font(.system(size: 13))
                    .foregroundStyle(DeepColor.driftGrey)
            }
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
