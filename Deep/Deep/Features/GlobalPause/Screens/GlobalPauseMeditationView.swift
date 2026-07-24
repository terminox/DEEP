import SwiftUI

/// The live meditation (20:40–20:50). Deliberately near-empty: a LIVE mark, a
/// gentle count of company, a thin progress line. No transport — the absence
/// of controls is how "cannot be paused" looks; leaving the lobby is the only
/// exit, and the close button stays.
struct GlobalPauseMeditationView: View {
  @Environment(\.globalPauseSession) private var session

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 12) {
        liveCapsule

        Text("\(session.participantCount.formatted()) meditating with you")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .contentTransition(.numericText())
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

  /// Clock-driven, not player-driven: the stream follows the shared timeline,
  /// so the timeline is the honest source for progress.
  private var progressLine: some View {
    TimelineView(.periodic(from: .now, by: 1)) { _ in
      let progress = session.meditationDuration > 0
        ? min(1, session.meditationElapsed / session.meditationDuration)
        : 0
      Capsule()
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
    .frame(height: 3)
  }
}

#Preview("Meditation") {
  ZStack {
    Color.moonCream.ignoresSafeArea()
    GlobalPauseMeditationView()
      .environment(\.globalPauseSession, .preview(phase: .meditation))
  }
}
