import SwiftUI

struct NextPauseCard: View {
    let target: Date
    let scheduleLines: [String]
    let durationDescription: String
    @Binding var hasJoined: Bool

    @State private var pressed = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            GlobeOrb()
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Next Global Pause")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DeepColor.deepPlum)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(DeepColor.lavenderMist)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 6)
                    CountdownView(target: target)
                        .fixedSize()
                }

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(scheduleLines, id: \.self) { line in
                            Text(line)
                                .font(.system(size: 12))
                                .foregroundStyle(DeepColor.driftGrey)
                        }
                        Text(durationDescription)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DeepColor.deepPlum.opacity(0.85))
                            .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 6) {
                        joinButton
                        Text("You will be notified once we begin")
                            .font(.system(size: 9))
                            .foregroundStyle(DeepColor.driftGrey)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120, alignment: .trailing)
                    }
                }
            }
        }
        .padding(18)
        .frostedCard()
    }

    private var joinButton: some View {
        Button {
            withAnimation(DeepMotion.settle) { hasJoined.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: hasJoined ? "checkmark" : "heart.fill")
                    .font(.system(size: 11, weight: .regular))
                Text(hasJoined ? "Joined" : "I'll join")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
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
            .scaleEffect(pressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hasJoined ? "You have joined the next global pause" : "Join the next global pause")
        ._onPressGesture { isPressing in
            withAnimation(DeepMotion.settle) { pressed = isPressing }
        }
    }
}

private struct GlobeOrb: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.9), DeepColor.softLilac.opacity(0.55), DeepColor.lavenderMist.opacity(0.7)],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: 56
                    )
                )
            Image(systemName: "globe.europe.africa.fill")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(
                    LinearGradient(colors: [DeepColor.lavenderMist, DeepColor.blushPowder], startPoint: .top, endPoint: .bottom)
                )
                .opacity(0.85)
        }
        .overlay(
            Circle().stroke(.white.opacity(0.6), lineWidth: 0.6)
        )
        .shadow(color: DeepColor.lavenderMist.opacity(0.35), radius: 8, x: 0, y: 4)
    }
}

private extension View {
    func _onPressGesture(perform action: @escaping (Bool) -> Void) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in action(true) }
                .onEnded { _ in action(false) }
        )
    }
}

#Preview {
    NextPauseCardPreview()
}

private struct NextPauseCardPreview: View {
    @State private var joined = false
    var body: some View {
        let seconds: TimeInterval = 3600 + 18 * 60 + 42
        NextPauseCard(
            target: Date().addingTimeInterval(seconds),
            scheduleLines: ["Every day, at the same time.", "21:00 Thailand Time"],
            durationDescription: "10 minute together",
            hasJoined: $joined
        )
        .padding()
        .background(DeepColor.moonCream)
    }
}
