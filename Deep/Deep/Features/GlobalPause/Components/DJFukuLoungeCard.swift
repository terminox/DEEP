import SwiftUI

/// The lobby-state doorway on the Global Pause home — DJ Fuku on air while the
/// world gathers to pause. Full-bleed artwork with a progressive-blur + scrim
/// footer in the `BreatheHeroCard` family; tapping pushes `GlobalPauseLobbyView`
/// through the coordinator's `openFukuLounge` action.
///
/// Under Reduce Transparency the blur strip is dropped and the scrim deepens
/// so the white text keeps its contrast without any live blur.
struct DJFukuLoungeCard: View {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.openFukuLounge) private var openFukuLounge

  private let cardHeight: CGFloat = 220

  var body: some View {
    Button {
      openFukuLounge()
    } label: {
      ZStack(alignment: .bottomLeading) {
        artwork

        HStack(alignment: .bottom) {
          VStack(alignment: .leading, spacing: 4) {
            Text("DJ FUKU")
              .font(DeepType.micro)
              .tracking(1.4)
              .foregroundStyle(.white.opacity(0.9))
            Text("Fuku's Lounge")
              .font(DeepType.displayTitle)
              .foregroundStyle(.white)
              .lineLimit(2)
            Text("Lo-fi while the world gathers to pause")
              .font(DeepType.caption)
              .foregroundStyle(.white.opacity(0.85))
          }
          Spacer()
          chevronButton
        }
        .padding(18)
      }
      .overlay(alignment: .topTrailing) {
        OnAirPill()
          .padding(18)
      }
    }
    .buttonStyle(.softPress)
    .shadow(color: Color.lavenderMist.opacity(0.28), radius: 22, x: 0, y: 12)
    .accessibilityLabel("Fuku's Lounge, on air — lo-fi while the world gathers to pause")
  }

  private var artwork: some View {
    Color.clear
      .frame(height: cardHeight)
      .overlay {
        Image("DJFukuHero")
          .resizable()
          .scaledToFill()
      }
      .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
      // Progressive blur so the text stays readable over the bright desk:
      // strongest at the bottom edge, dissolving to nothing mid-card.
      .overlay(alignment: .bottom) {
        if !reduceTransparency {
          VariableBlurView(maxBlurRadius: 4, direction: .blurredBottomClearTop)
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
        }
      }
      .overlay(
        scrim
          .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
      )
  }

  /// The image's lower third is bright cream (desk, mug), so the scrim runs
  /// deeper than `BreatheHeroCard`'s; without the blur strip it deepens again.
  private var scrim: LinearGradient {
    LinearGradient(
      colors: [.clear, Color.deepPlum.opacity(reduceTransparency ? 0.75 : 0.55)],
      startPoint: reduceTransparency ? .top : .center,
      endPoint: .bottom
    )
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

#Preview("Fuku's Lounge card") {
  ZStack {
    AtmosphereBackground()
    DJFukuLoungeCard()
      .padding(.edge)
  }
}

#Preview("Accessibility type") {
  ZStack {
    AtmosphereBackground()
    DJFukuLoungeCard()
      .padding(.edge)
  }
  .environment(\.dynamicTypeSize, .accessibility2)
}
