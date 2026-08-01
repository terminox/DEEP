import SwiftUI

/// The meditation, deliberately near-empty: synced sessions show a LIVE mark
/// and a gentle count of company; a solo pause shows a single quiet caption.
/// A thin progress line, no transport — the absence of controls is how
/// "cannot be paused" looks; the close button is the only exit.
struct GlobalPauseMeditationView: View {
  let audio: any GlobalPauseAudioPlaying
  let duration: TimeInterval
  let isSynced: Bool
  let participantCount: Int

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 12) {
        if isSynced {
          liveCapsule

          Text("\(participantCount.formatted()) meditating with you")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .contentTransition(.numericText())
        } else {
          Text("A quiet pause, just for you")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
        }
      }
      .padding(.top, 68)

      Spacer(minLength: 0)

      progressLine
        .padding(.horizontal, 44)
        .padding(.bottom, 40)
    }
    .allowsHitTesting(false)
  }

  private var liveCapsule: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(.blushPowder)
        .frame(width: 7, height: 7)
      Text("LIVE · meditating together")
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
  /// honest source for both synced and solo passes.
  private var progressLine: some View {
    let progress = duration > 0 ? min(1, audio.meditationElapsed / duration) : 0
    return Capsule()
      .fill(Color.deepPlum.opacity(0.12))
      .frame(height: 3)
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

#Preview("Meditation — synced") {
  ZStack {
    Color.moonCream.ignoresSafeArea()
    GlobalPauseMeditationView(
      audio: MockGlobalPauseAudioPlayer.meditating,
      duration: 600,
      isSynced: true,
      participantCount: 4218
    )
  }
}

#Preview("Meditation — solo") {
  ZStack {
    Color.moonCream.ignoresSafeArea()
    GlobalPauseMeditationView(
      audio: MockGlobalPauseAudioPlayer(mode: .meditation, meditationElapsed: 42),
      duration: 600,
      isSynced: false,
      participantCount: 0
    )
  }
}
