import SwiftUI

/// The open lobby (20:30–20:39:50): theme music plays, the counter breathes
/// upward as the world arrives, and the carousel shows where from.
struct GlobalPauseLiveLobbyView: View {
  @Environment(\.globalPauseSession) private var session

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 14) {
        ParticipantsCounter(count: session.participantCount)
          .animation(.exhale, value: session.participantCount)

        if let meditationStart = session.schedule?.window(for: .meditation)?.startsAt {
          VStack(spacing: 4) {
            Text("MEDITATION BEGINS IN")
              .font(DeepType.micro)
              .tracking(1.4)
              .foregroundStyle(.driftGrey)
            CountdownView(target: meditationStart, clockOffset: session.clock.effectiveOffset)
              .scaleEffect(0.72)
          }
        }
      }
      .padding(.top, 68)

      Spacer(minLength: 0)

      if !session.participantsByCountry.isEmpty {
        LiveAroundWorldSection(pauses: countryPauses)
          .padding(.bottom, .rhythm)
      }
    }
  }

  private var countryPauses: [CountryPause] {
    session.participantsByCountry
      .sorted { $0.value > $1.value }
      .prefix(8)
      .compactMap { CountryPause(iso: $0.key, count: $0.value, now: session.clock.now) }
  }
}

#Preview("Live lobby") {
  ZStack {
    Color.moonCream.ignoresSafeArea()
    GlobalPauseLiveLobbyView()
      .environment(\.globalPauseSession, .preview(phase: .lobby))
  }
}
