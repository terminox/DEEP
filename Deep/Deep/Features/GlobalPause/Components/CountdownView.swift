import SwiftUI

struct CountdownView: View {
    let target: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let parts = remaining(until: target, now: context.date)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                unit(value: parts.hours, label: "HR")
                separator
                unit(value: parts.minutes, label: "MIN")
                separator
                unit(value: parts.seconds, label: "SEC")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(parts.hours) hours \(parts.minutes) minutes \(parts.seconds) seconds remaining"
            )
        }
    }

    private var separator: some View {
        Text(":")
            .font(.system(size: 18, weight: .light, design: .rounded))
            .foregroundStyle(DeepColor.driftGrey.opacity(0.5))
            .padding(.bottom, 10)
    }

    private func unit(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(DeepColor.deepPlum)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(DeepMotion.exhale, value: value)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(1.0)
                .foregroundStyle(DeepColor.driftGrey)
        }
        .frame(minWidth: 28)
    }

    private struct Remaining {
        let hours: Int
        let minutes: Int
        let seconds: Int
    }

    private func remaining(until target: Date, now: Date) -> Remaining {
        let interval = max(0, Int(target.timeIntervalSince(now)))
        let h = interval / 3600
        let m = (interval % 3600) / 60
        let s = interval % 60
        return Remaining(hours: h, minutes: m, seconds: s)
    }
}

#Preview {
    CountdownPreview()
}

private struct CountdownPreview: View {
    var body: some View {
        let seconds: TimeInterval = 3600 + 18 * 60 + 42
        CountdownView(target: Date().addingTimeInterval(seconds))
            .padding()
            .background(DeepColor.moonCream)
    }
}
