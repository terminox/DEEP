#if EXPERIMENTS
import SwiftUI

/// Step 2: the four sensors, turning green as the headband settles, with a tip for
/// whichever still isn't touching. Start unlocks once all four have read good for two
/// seconds; after twenty seconds "Start anyway" appears for the stubborn ones.
struct SensorFitView: View {
  let headband: any MuseConnecting
  let onClose: () -> Void
  let onReady: () -> Void

  @State private var shownAt = Date()
  @State private var goodSince: Date?

  static let steadyFor = 2.0
  static let startAnywayAfter = 20.0

  var body: some View {
    SitStepScaffold(title: "Settle the headband", onClose: onClose) {
      TimelineView(.periodic(from: .now, by: 0.5)) { context in
        let fit = headband.fit
        let ready = goodSince.map { context.date.timeIntervalSince($0) >= Self.steadyFor } ?? false
        let patient = context.date.timeIntervalSince(shownAt) >= Self.startAnywayAfter
        VStack(spacing: .rhythm) {
          HeadDiagram(fit: fit)
            .frame(maxWidth: 260)
            .frame(maxWidth: .infinity)
          Text(ready ? "All four sensors are touching. You're ready." : advice(for: fit))
            .font(DeepType.body)
            .foregroundStyle(.deepPlum.opacity(0.85))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .contentTransition(.opacity)
          Spacer(minLength: 0)
          OnboardingPrimaryButton(title: "Start", systemImage: "play.fill", isEnabled: ready, action: onReady)
            .accessibilityIdentifier("sit.start")
          if patient, !ready {
            Button("Start anyway", action: onReady)
              .font(DeepType.caption.weight(.semibold))
              .foregroundStyle(.driftGrey)
              .accessibilityIdentifier("sit.startAnyway")
          }
        }
        .padding(.bottom, 12)
        .animation(.exhale, value: ready)
        .animation(.exhale, value: patient)
      }
    }
    .onChange(of: headband.fit.isGood, initial: true) { _, good in
      goodSince = good ? Date() : nil
    }
  }

  /// One thing to fix, starting with the sensors that matter most for the art.
  private func advice(for fit: SensorFit) -> LocalizedStringKey {
    if !fit.headbandOn { return "Put the headband on: the band across your forehead, the arms behind your ears." }
    let channels = fit.channels
    if channels[1] != .good || channels[2] != .good {
      return "Rest the forehead band flat, just above your eyebrows. Brush hair out of the way."
    }
    if channels[0] != .good || channels[3] != .good {
      return "Tuck the ear sensors snugly behind your ears, on skin. A little water helps dry skin."
    }
    return "Hold still for a moment and relax your jaw."
  }
}

/// A head seen from above, nose up, with the Muse 2's four sensors coloured by fit.
private struct HeadDiagram: View {
  let fit: SensorFit

  var body: some View {
    Canvas { context, size in
      let side = min(size.width, size.height)
      let rect = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side)
      let head = rect.insetBy(dx: side * 0.16, dy: side * 0.1)
      context.fill(Path(ellipseIn: head), with: .color(.white.opacity(0.55)))
      context.stroke(Path(ellipseIn: head), with: .color(.lavenderMist), lineWidth: 1.5)
      // Nose and ears, so it reads as a head.
      var nose = Path()
      nose.move(to: CGPoint(x: head.midX - side * 0.05, y: head.minY + 2))
      nose.addLine(to: CGPoint(x: head.midX, y: head.minY - side * 0.06))
      nose.addLine(to: CGPoint(x: head.midX + side * 0.05, y: head.minY + 2))
      context.stroke(nose, with: .color(.lavenderMist), lineWidth: 1.5)
      for direction in [-1.0, 1.0] {
        let ear = CGRect(x: head.midX + direction * head.width / 2 - side * 0.04, y: head.midY - side * 0.08, width: side * 0.08, height: side * 0.16)
        context.stroke(Path(ellipseIn: ear), with: .color(.lavenderMist), lineWidth: 1.5)
      }
      // The headband arc over the forehead and behind the ears.
      var band = Path()
      band.addArc(center: CGPoint(x: head.midX, y: head.midY + side * 0.02), radius: head.width * 0.46, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
      context.stroke(band, with: .color(.driftGrey.opacity(0.6)), style: StrokeStyle(lineWidth: side * 0.035, lineCap: .round))

      let spots: [(MuseChannel, CGPoint)] = [
        (.tp9, CGPoint(x: head.minX + side * 0.02, y: head.midY + side * 0.02)),
        (.af7, CGPoint(x: head.midX - head.width * 0.22, y: head.minY + head.height * 0.1)),
        (.af8, CGPoint(x: head.midX + head.width * 0.22, y: head.minY + head.height * 0.1)),
        (.tp10, CGPoint(x: head.maxX - side * 0.02, y: head.midY + side * 0.02))
      ]
      for (channel, point) in spots {
        let reading = fit.headbandOn ? fit.channels[channel.rawValue] : .bad
        let radius = side * 0.055
        let colour = Self.colour(reading)
        context.fill(Path(ellipseIn: CGRect(x: point.x - radius * 1.8, y: point.y - radius * 1.8, width: radius * 3.6, height: radius * 3.6)), with: .color(colour.opacity(0.25)))
        context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(colour))
      }
    }
    .aspectRatio(1, contentMode: .fit)
    .animation(.exhale, value: fit)
    .accessibilityElement()
    .accessibilityLabel(accessibilityText)
  }

  private static func colour(_ fit: HorseshoeFit) -> Color {
    switch fit {
    case .good: .green
    case .ok: .orange
    case .bad: .driftGrey.opacity(0.5)
    }
  }

  private var accessibilityText: String {
    MuseChannel.allCases.map { "\($0.place): \(fit.channels[$0.rawValue].label)" }.joined(separator: ", ")
  }
}

#Preview("Fit · settling") {
  SensorFitView(headband: SimulatedHeadband(connected: true), onClose: {}, onReady: {})
}
#endif
