import SwiftUI

/// Loading placeholder for the Global Pause home feed — mirrors the shape of
/// `RecommendationsSection` and `FeatureCarousel` so the skeleton settles into
/// real content without a layout jump.
struct PauseFeedSkeleton: View {
  var body: some View {
    VStack(alignment: .leading, spacing: .rhythm) {
      recommendationsSection
      carouselSection
    }
    .skeletonBreath()
  }

  private var recommendationsSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      SkeletonTextLine(width: 140)
        .padding(.horizontal, .edge)

      HStack(alignment: .top, spacing: 16) {
        ForEach(0..<3, id: \.self) { _ in
          VStack(alignment: .leading, spacing: 8) {
            SkeletonBlock()
              .frame(width: 150, height: 150)

            VStack(alignment: .leading, spacing: 2) {
              SkeletonTextLine(width: 110)
              SkeletonTextLine(width: 70)
            }
          }
        }
      }
      .padding(.horizontal, .edge)
    }
  }

  private var carouselSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      SkeletonTextLine(width: 160)
        .padding(.horizontal, .edge)

      HStack(alignment: .top, spacing: 16) {
        ForEach(0..<2, id: \.self) { _ in
          VStack(alignment: .leading, spacing: 10) {
            SkeletonBlock(cornerRadius: .card)
              .frame(width: 300, height: 200)

            VStack(alignment: .leading, spacing: 1) {
              SkeletonTextLine(width: 160)
              SkeletonTextLine(width: 110)
            }
          }
        }
      }
      .padding(.horizontal, .edge)
    }
  }
}

#Preview("Pause Feed Skeleton") {
  ScrollView {
    PauseFeedSkeleton()
      .padding(.vertical, 24)
  }
  .background(.moonCream)
}
