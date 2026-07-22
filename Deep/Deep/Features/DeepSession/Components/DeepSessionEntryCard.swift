import SwiftUI

/// Home-feed doorway into a guided Deep Session. The card stays a dumb button:
/// it reads the shell-provided `startDeepSession` action from the environment
/// and hands it the session, so hosts only say *which* session to offer.
struct DeepSessionEntryCard: View {
  var session: DeepSession

  @Environment(\.startDeepSession) private var startDeepSession

  /// The card's UIKit backing — the frame the session zooms out of.
  @State private var zoomAnchor: UIView?

  var body: some View {
    Button {
      startDeepSession(session, from: zoomAnchor)
    } label: {
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 5) {
          Text("DEEP SESSION")
            .font(DeepType.micro)
            .tracking(1.4)
            .foregroundStyle(.driftGrey)
          Text(session.title)
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
          Text("\(session.durationMinutes) min · guided breathing")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
        }
        Spacer(minLength: 8)
        playCircle
      }
      .padding(20)
      .frostedCard()
    }
    .buttonStyle(.softPress)
    .zoomTransitionAnchor($zoomAnchor)
    .accessibilityLabel("Begin \(session.title), a \(session.durationMinutes) minute guided breathing session")
  }

  private var playCircle: some View {
    Image(systemName: "play.fill")
      .font(.system(size: 18, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: 54, height: 54)
      .background(
        Circle().fill(LinearGradient(
          colors: [.lavenderMist, .softLilac],
          startPoint: .topLeading, endPoint: .bottomTrailing
        ))
      )
      .shadow(color: .lavenderMist.opacity(0.4), radius: 12, x: 0, y: 6)
  }
}

#Preview("Deep session entry") {
  ZStack {
    AtmosphereBackground()
    DeepSessionEntryCard(session: DeepSessionLibrary.balancingBreath)
      .padding(.edge)
  }
}
