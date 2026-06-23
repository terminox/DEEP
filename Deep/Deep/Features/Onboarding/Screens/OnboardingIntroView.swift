import SwiftUI

/// The opening of onboarding — a calm welcome that names the few gentle areas
/// Deep will explore together. Adapted from the Calm reference's "Let's start by
/// building your perfect sleep plan" list, re-voiced and re-themed to Deep.
struct OnboardingIntroView: View {
  @Environment(\.onboardingAdvance) private var advance

  private struct Area: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
  }

  private let areas: [Area] = [
    Area(symbol: "cloud.fill", title: "Your inner weather"),
    Area(symbol: "wind", title: "Moments of pause"),
    Area(symbol: "waveform", title: "Sounds that soothe you"),
    Area(symbol: "leaf.fill", title: "A quiet sense of growth"),
    Area(symbol: "heart.fill", title: "Caring, for self and others"),
  ]

  var body: some View {
    ZStack {
      AtmosphereBackground()

      VStack(alignment: .leading, spacing: .rhythm) {
        VStack(alignment: .leading, spacing: 12) {
          Text("Let's shape a little space for you.")
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
          Text("A few soft questions — there are no wrong answers.")
            .font(DeepType.body)
            .foregroundStyle(.driftGrey)
        }
        .padding(.top, 8)

        VStack(spacing: 18) {
          ForEach(areas) { area in
            HStack(spacing: 16) {
              Image(systemName: area.symbol)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.lavenderMist)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white.opacity(0.5)))
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
              Text(area.title)
                .font(DeepType.body)
                .foregroundStyle(.deepPlum)
              Spacer(minLength: 0)
            }
          }
        }

        Spacer()

        OnboardingPrimaryButton(title: "Begin") {
          advance(.quiz(index: 0))
        }
      }
      .padding(.horizontal, .edge)
      .padding(.bottom, .rhythm)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

#Preview("Onboarding — Intro") {
  OnboardingIntroView()
}
