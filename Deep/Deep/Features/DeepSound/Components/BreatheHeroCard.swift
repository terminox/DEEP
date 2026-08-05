import SwiftUI

/// The large editorial doorway at the top of the home screen — Deep Sound's
/// bridge into Deep Session. The whole card pushes the session's threshold onto
/// the tab's stack; unlike a collection card there is nothing to play in place,
/// so a quiet halo ring (echoing the breathing orb) stands where a play button
/// would.
struct BreatheHeroCard: View {
  let session: DeepSession

  @Environment(\.openDeepSession) private var openDeepSession

  private let imageURL = URL(string: "https://images.unsplash.com/photo-1499346030926-9a72daac6c63?w=600&q=80")

  var body: some View {
    Button {
      openDeepSession(session)
    } label: {
      ZStack(alignment: .bottomLeading) {
        SoundArtwork(palette: .mist, imageURL: imageURL, cornerRadius: .card)
          .frame(height: 220)
          // Progressive blur so the text stays readable over bright clouds:
          // strongest at the bottom edge, dissolving to nothing mid-card.
          .overlay(alignment: .bottom) {
            VariableBlurView(maxBlurRadius: 4, direction: .blurredBottomClearTop)
              .frame(height: 80)
              .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
          }
          .overlay(
            LinearGradient(
              colors: [.clear, Color.deepPlum.opacity(0.28)],
              startPoint: .center,
              endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
          )

        HStack(alignment: .bottom) {
          VStack(alignment: .leading, spacing: 4) {
            Text("DEEP SESSION")
              .font(DeepType.micro)
              .tracking(1.4)
              .foregroundStyle(.white.opacity(0.9))
            Text("Breathe")
              .font(DeepType.displayTitle)
              .foregroundStyle(.white)
            Text("\(Int(session.inhale))s in · \(Int(session.exhale))s out · \(session.durationMinutes) min")
              .font(DeepType.caption)
              .foregroundStyle(.white.opacity(0.85))
          }
          Spacer()
          chevronButton
        }
        .padding(18)
      }
    }
    .buttonStyle(.softPress)
    .shadow(color: Color.lavenderMist.opacity(0.28), radius: 22, x: 0, y: 12)
    .accessibilityLabel("Breathe, a \(session.durationMinutes) minute guided breathing session")
  }

  /// Reads like the collection cards' play button, but the whole card already
  /// navigates — so this stays decorative, and a chevron says "go" not "play".
  private var chevronButton: some View {
    Image(systemName: "chevron.right")
      .font(.system(size: 18, weight: .semibold))
      .foregroundStyle(.deepPlum)
      .frame(width: 48, height: 48)
      .background(Circle().fill(.white.opacity(0.85)))
      .shadow(color: Color.deepPlum.opacity(0.2), radius: 8, x: 0, y: 4)
  }
}

#Preview("Breathe hero card") {
  BreatheHeroCard(session: DeepSessionLibrary.balancingBreath)
    .padding(.edge)
}
