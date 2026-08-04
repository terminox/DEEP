import SwiftUI

/// The live meditation — the screen's one state — deliberately near-empty:
/// a LIVE mark, a gentle count of company, a thin progress line. No transport
/// — the absence of controls is how "cannot be paused" looks; the close
/// button is the only exit.
///
/// The screen arrives empty: `revealed` stays false through the card-lift
/// flight, then flips once the zoom has settled, cascading the elements in —
/// pill, then count, then progress line — each with a small lift.
struct GlobalPauseMeditationView: View {
  let audio: any GlobalPauseAudioPlaying
  let duration: TimeInterval
  let participantCount: Int
  var revealed: Bool = true

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 12) {
        liveCapsule
          .cascade(revealed, order: 0, reduceMotion: reduceMotion)

        Text("\(participantCount.formatted()) people are pausing with you")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .contentTransition(.numericText())
          .cascade(revealed, order: 1, reduceMotion: reduceMotion)
      }
      .padding(.top, 68)

      Spacer(minLength: 0)

      progressLine
        .padding(.horizontal, 44)
        .padding(.bottom, 40)
        .cascade(revealed, order: 2, reduceMotion: reduceMotion)
    }
    .allowsHitTesting(false)
  }

  private var liveCapsule: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(.blushPowder)
        .frame(width: 7, height: 7)
      Text("LIVE · Worldwide")
        .font(DeepType.micro)
        .tracking(1.2)
        .foregroundStyle(.deepPlum)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .frostedCard(cornerRadius: .chip)
    .accessibilityLabel("Live meditation in progress")
  }

  /// Player-driven: the audio clock publishes ~every 0.5 s, and it is the
  /// honest source for how far the shared stream has actually played.
  private var progressLine: some View {
    let progress = duration > 0 ? min(1, audio.meditationElapsed / duration) : 0
    return Capsule()
      .fill(Color.deepPlum.opacity(0.12))
      .frame(height: 8)
      .overlay(alignment: .leading) {
        GeometryReader { proxy in
          Capsule()
            .fill(
              LinearGradient(
                colors: [.lavenderMist, .blushPowder],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(width: proxy.size.width * progress)
        }
      }
      .accessibilityLabel("Meditation \(Int(progress * 100)) percent through")
  }
}

private extension View {
  /// One step of the arrival cascade: fade + a small rise, staggered by
  /// `order`. Reduce Motion keeps the fade and drops the movement.
  func cascade(_ revealed: Bool, order: Int, reduceMotion: Bool) -> some View {
    self
      .opacity(revealed ? 1 : 0)
      .offset(y: revealed || reduceMotion ? 0 : 12)
      .animation(.bloom.delay(Double(order) * 0.12), value: revealed)
  }
}

#Preview("Meditation") {
  ZStack {
    Color.moonCream.ignoresSafeArea()
    GlobalPauseMeditationView(
      audio: MockGlobalPauseAudioPlayer.meditating,
      duration: 600,
      participantCount: 4218
    )
  }
}

#Preview("Arrival cascade") {
  @Previewable @State var revealed = false

  ZStack {
    Color.moonCream.ignoresSafeArea()
    GlobalPauseMeditationView(
      audio: MockGlobalPauseAudioPlayer.meditating,
      duration: 600,
      participantCount: 4218,
      revealed: revealed
    )
  }
  // Stands in for the card-lift landing.
  .task {
    try? await Task.sleep(for: .seconds(1))
    revealed = true
  }
}
