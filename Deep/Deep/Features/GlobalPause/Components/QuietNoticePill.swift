import SwiftUI

/// A short line that settles over the bottom of a screen and leaves on its own,
/// such as the thank-you after a report. It sits on the frosted surface the
/// cards use, shaped as a pill, so it reads as part of the screen rather than
/// an interruption. The owner decides when it leaves (see
/// `GlobalPauseLobbyView`).
struct QuietNoticePill: View {
  let text: LocalizedStringKey
  var systemImage: String? = nil

  var body: some View {
    HStack(spacing: 8) {
      if let systemImage {
        Image(systemName: systemImage)
          .font(DeepType.caption)
          .foregroundStyle(.lavenderMist)
          .accessibilityHidden(true)
      }
      Text(text)
        .font(DeepType.caption)
        .foregroundStyle(.deepPlum)
        .multilineTextAlignment(.center)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 12)
    .frostedCard(cornerRadius: .chip)
    .accessibilityElement(children: .combine)
  }
}

#Preview("Quiet notice") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: .rhythm) {
      QuietNoticePill(text: "Thanks for telling us. We'll take a look.", systemImage: "checkmark")
      QuietNoticePill(text: "Something went wrong. Please try again.")
    }
    .padding(.edge)
  }
}
