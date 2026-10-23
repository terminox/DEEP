import SwiftUI

/// What the donate sheet becomes once hearts have gone: the cause's own motif
/// with a single halo pulse, the app's thank-you, what was given, and a way
/// out. The member closes it themselves — a thank-you that leaves on a timer
/// reads as a receipt, and this is the one moment in the feature worth
/// staying in.
struct GivingThanksView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let category: CompassionCategory
  /// What was actually given, which may be less than was asked.
  let amount: Int
  let onDone: () -> Void

  @State private var halo = false

  var body: some View {
    VStack(spacing: 22) {
      CompassionMotif(symbol: category.symbol, palette: category.palette, cornerRadius: .tile)
        .frame(width: 88, height: 88)
        .overlay { if halo { HaloPulse() } }

      VStack(spacing: 8) {
        Text("Thank you for giving to \(category.name)")
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 6) {
          Image(systemName: "heart.fill")
            .foregroundStyle(.blushPowder)
          amountLabel
        }
        .font(DeepType.caption.weight(.medium))
        .foregroundStyle(.driftGrey)
        .monospacedDigit()
      }
      .accessibilityElement(children: .combine)

      Button(action: onDone) {
        Text("Done")
          .font(DeepType.sectionTitle)
          .foregroundStyle(.white)
          .padding(.vertical, 16)
          .frame(maxWidth: .infinity)
          .background {
            Capsule().fill(
              LinearGradient(colors: [.lavenderMist, .blushPowder], startPoint: .leading, endPoint: .trailing)
            )
          }
          .shadow(color: Color.lavenderMist.opacity(0.35), radius: 18, y: 10)
      }
      .buttonStyle(.softPress)
      .padding(.top, 12)
    }
    .padding(.horizontal, .edge)
    .task {
      // The halo answers the words, so it waits for them to bloom in.
      guard !reduceMotion else { return }
      try? await Task.sleep(for: .seconds(0.3))
      halo = true
    }
  }

  @ViewBuilder
  private var amountLabel: some View {
    if amount == 1 {
      Text("1 heart")
    } else {
      Text("\(amount) hearts")
    }
  }
}

/// DESIGN.md's halo pulse: one slow ring outward from the motif, once.
private struct HaloPulse: View {
  @State private var spread = false

  var body: some View {
    RoundedRectangle(cornerRadius: .tile, style: .continuous)
      .strokeBorder(Color.blushPowder, lineWidth: 2)
      .scaleEffect(spread ? 1.35 : 1)
      .opacity(spread ? 0 : 0.9)
      .allowsHitTesting(false)
      .accessibilityHidden(true)
      .onAppear {
        withAnimation(.ripple) { spread = true }
      }
  }
}

#Preview("Giving thanks") {
  GivingThanksView(category: CompassionLibrary.healthcare, amount: 10) {}
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { AtmosphereBackground() }
}

#Preview("Giving thanks — one heart") {
  GivingThanksView(category: CompassionLibrary.peace, amount: 1) {}
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { AtmosphereBackground() }
}

#Preview("Giving thanks — accessibility1") {
  GivingThanksView(category: CompassionLibrary.nature, amount: 100) {}
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { AtmosphereBackground() }
    .environment(\.dynamicTypeSize, .accessibility1)
}
