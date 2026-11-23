#if EXPERIMENTS
import SwiftUI

/// Step 3: how long to sit. The art spreads itself over whichever length is chosen.
struct SitLengthView: View {
  let art: EEGArt
  let onClose: () -> Void
  let onStart: (SitLength) -> Void

  var body: some View {
    SitStepScaffold(title: "How long will you sit?", onClose: onClose) {
      VStack(alignment: .leading, spacing: .rhythm) {
        Label(art.promise, systemImage: art.icon)
          .font(DeepType.body)
          .foregroundStyle(.deepPlum.opacity(0.8))
        VStack(spacing: 12) {
          ForEach(SitLength.allCases) { length in
            Button { onStart(length) } label: {
              HStack {
                Text(length.label)
                  .font(DeepType.sectionTitle)
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                  .font(.system(size: 14, weight: .semibold))
              }
              .foregroundStyle(.deepPlum)
              .padding(.horizontal, 20)
              .padding(.vertical, 18)
              .frostedCard()
            }
            .buttonStyle(.softPress)
            .accessibilityIdentifier("sit.length.\(length.rawValue)")
          }
        }
        Text("Sit comfortably, close your eyes if you like, and breathe. You can end early; the art keeps what you've painted.")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      }
    }
  }
}

#Preview("Length") {
  SitLengthView(art: .lantern, onClose: {}, onStart: { _ in })
}
#endif
