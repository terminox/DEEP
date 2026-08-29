import SwiftUI

/// Home-feed doorway into a guided Deep Session. Hosts only say *which*
/// session to offer; tapping pushes the session's threshold through the tab
/// coordinator's `openDeepSession` action.
struct DeepSessionEntryCard: View {
  var session: DeepSession

  @Environment(\.openDeepSession) private var openDeepSession

  var body: some View {
    Button {
      openDeepSession(session)
    } label: {
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 5) {
          Text("DEEP SESSION")
            .font(DeepType.micro)
            .tracking(.microTracking)
            .foregroundStyle(.driftGrey)
          Text(session.title)
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
          // The practice's own line rather than a length: how long is chosen
          // on the threshold now, so no card can promise a number for it.
          Text(session.tagline)
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
    .accessibilityLabel("Begin \(session.title), a guided breathing session")
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
