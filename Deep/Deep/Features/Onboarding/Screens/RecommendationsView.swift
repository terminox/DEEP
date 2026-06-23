import SwiftUI

/// A short, reassuring "here's what we'll start with" beat. Editorial gradient
/// cards (never photos, per DESIGN.md) re-cast from the Calm reference's "Expert
/// recommendations" screen. Static for now — it reflects the brand, not a live
/// personalised feed.
struct RecommendationsView: View {
  @Environment(\.onboardingAdvance) private var advance

  private struct Recommendation: Identifiable {
    let id = UUID()
    let label: String
    let title: String
    let palette: ArtworkPalette
  }

  private let recommendations: [Recommendation] = [
    Recommendation(label: "To settle", title: "A breath to land you in the moment", palette: .tide),
    Recommendation(label: "To soften", title: "Sounds to quiet a busy mind", palette: .dusk),
    Recommendation(label: "To connect", title: "A shared pause with others, worldwide", palette: .aurora),
  ]

  var body: some View {
    ZStack {
      AtmosphereBackground()

      VStack(alignment: .leading, spacing: .rhythm) {
        VStack(alignment: .leading, spacing: 10) {
          Text("A few things, chosen for you.")
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
          Text("Gentle places to begin whenever you're ready.")
            .font(DeepType.body)
            .foregroundStyle(.driftGrey)
        }
        .padding(.top, 8)

        ScrollView {
          VStack(spacing: 16) {
            ForEach(recommendations) { item in
              recommendationCard(item)
            }
          }
          .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)

        OnboardingPrimaryButton(title: "Continue") {
          advance(.referral)
        }
      }
      .padding(.horizontal, .edge)
      .padding(.bottom, .rhythm)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .navigationBarBackButtonHidden(true)
  }

  private func recommendationCard(_ item: Recommendation) -> some View {
    ZStack(alignment: .bottomLeading) {
      ArtworkImage(url: nil, colors: item.palette.colors, cornerRadius: .card)
        .frame(height: 132)
        .overlay(
          LinearGradient(
            colors: [.clear, Color.deepPlum.opacity(0.28)],
            startPoint: .center,
            endPoint: .bottom
          )
          .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
        )

      VStack(alignment: .leading, spacing: 4) {
        Text(item.label.uppercased())
          .font(DeepType.micro)
          .tracking(1.4)
          .foregroundStyle(.white.opacity(0.9))
        Text(item.title)
          .font(DeepType.sectionTitle)
          .foregroundStyle(.white)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(16)
    }
  }
}

#Preview("Onboarding — Recommendations") {
  RecommendationsView()
}
