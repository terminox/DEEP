import SwiftUI

/// A breathing skeleton mirroring the loaded home shelves — two carousels of
/// three placeholder tiles each, shown while `DeepSoundHomeView` fetches.
struct SoundShelvesSkeleton: View {
  var body: some View {
    VStack(alignment: .leading, spacing: .rhythm) {
      shelf
      shelf
    }
    .skeletonBreath()
  }

  private var shelf: some View {
    VStack(alignment: .leading, spacing: 14) {
      SkeletonTextLine(width: 120)
        .padding(.horizontal, .edge)

      HStack(alignment: .top, spacing: 16) {
        tile
        tile
        tile
      }
      .padding(.horizontal, .edge)
    }
  }

  private var tile: some View {
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

#Preview("Sound Shelves Skeleton") {
  ZStack {
    Color.moonCream.ignoresSafeArea()
    SoundShelvesSkeleton()
  }
}
