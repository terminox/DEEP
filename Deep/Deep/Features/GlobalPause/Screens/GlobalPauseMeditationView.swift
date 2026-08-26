import SwiftUI

/// The live meditation — the screen's one state — deliberately near-empty:
/// a LIVE mark, a gentle count of company, the world named beneath the globe,
/// a thin progress line. No transport — the absence of controls is how
/// "cannot be paused" looks; the close button is the only exit.
///
/// The screen arrives empty: `revealed` stays false through the card-lift
/// flight, then flips once the zoom has settled, cascading the elements in —
/// pill, then count, then continents, then progress line — each with a small
/// lift.
struct GlobalPauseMeditationView: View {
  let audio: any GlobalPauseAudioPlaying
  let duration: TimeInterval
  let participantCount: Int
  /// Where the room is, west to east. Empty before the first poll lands, and
  /// the row simply isn't there — no placeholders, no dashes.
  var continents: [ContinentPresence] = []
  var revealed: Bool = true

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 12) {
        liveCapsule
          .cascade(revealed, order: 0, reduceMotion: reduceMotion)

        Text("\(participantCount.formatted()) people are pausing with you")
          .font(DeepType.caption)
          // moonCream, not driftGrey — the caption sits on the night sky,
          // anchored to the same cream its stars are drawn from.
          .foregroundStyle(.moonCream.opacity(0.75))
          .contentTransition(.numericText())
          .cascade(revealed, order: 1, reduceMotion: reduceMotion)
      }
      .padding(.top, 68)

      Spacer(minLength: 0)

      if !continents.isEmpty {
        // Seated in the band the globe's own cradle glow already lights,
        // clear of both the orb's edge and the progress line.
        ContinentLights(presences: continents)
          .padding(.horizontal, 12)
          // Sits in the middle of the band, not against the progress line —
          // the row belongs to the globe it names, not to the bar below it.
          .padding(.bottom, 48)
          .cascade(revealed, order: 2, reduceMotion: reduceMotion)
          // The cascade only covers the row when the first poll has already
          // landed by the time the card lift settles — the usual case, since
          // polling starts a beat before the flight. On a slow first poll the
          // row would otherwise arrive after the cascade and simply appear.
          .transition(.opacity)
      }

      progressLine
        .padding(.horizontal, 44)
        .padding(.bottom, 40)
        .cascade(revealed, order: 3, reduceMotion: reduceMotion)
    }
    .animation(.bloom, value: continents.isEmpty)
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
      .fill(Color.moonCream.opacity(0.18))
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

#if DEBUG
#Preview("Meditation") {
  ZStack {
    // The overlay only ever ships over the session's night sky.
    NightSkyBackground(tuning: NightSkyTuning())
      .ignoresSafeArea()
    GlobalPauseMeditationView(
      audio: MockGlobalPauseAudioPlayer.meditating,
      duration: 600,
      participantCount: 4218,
      continents: ContinentPresence.row(
        from: ["AS": 1842, "EU": 1106, "NA": 604, "SA": 199, "AF": 291, "OC": 176]
      )
    )
  }
}

#Preview("Arrival cascade") {
  @Previewable @State var revealed = false

  ZStack {
    NightSkyBackground(tuning: NightSkyTuning())
      .ignoresSafeArea()
    GlobalPauseMeditationView(
      audio: MockGlobalPauseAudioPlayer.meditating,
      duration: 600,
      participantCount: 4218,
      continents: ContinentPresence.row(
        from: ["AS": 1842, "EU": 1106, "NA": 604, "SA": 199, "AF": 291, "OC": 176]
      ),
      revealed: revealed
    )
  }
  // Stands in for the card-lift landing.
  .task {
    try? await Task.sleep(for: .seconds(1))
    revealed = true
  }
}
#endif
