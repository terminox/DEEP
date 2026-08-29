import SwiftUI

/// A breathing skeleton mirroring the loaded playlist — the action pair and
/// four placeholder rows — shown while the saved sounds are fetched. Never a
/// spinner and never a shimmer sweep; the whole subtree breathes as one.
struct PlaylistSkeleton: View {
  var body: some View {
    VStack(spacing: .rhythm) {
      HStack(spacing: 12) {
        SkeletonBlock(cornerRadius: 16)
          .frame(height: 46)
        SkeletonBlock(cornerRadius: 16)
          .frame(height: 46)
      }

      VStack(spacing: 14) {
        row
        row
        row
        row
      }
    }
    .padding(.horizontal, .edge)
    .skeletonBreath()
  }

  private var row: some View {
    HStack(spacing: 14) {
      SkeletonBlock(cornerRadius: 14)
        .frame(width: 56, height: 56)

      VStack(alignment: .leading, spacing: 6) {
        SkeletonTextLine(width: 150)
        SkeletonTextLine(width: 96)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(12)
    .frostedCard()
  }
}

#Preview("Playlist skeleton") {
  ZStack {
    AtmosphereBackground()
    PlaylistSkeleton()
  }
}
