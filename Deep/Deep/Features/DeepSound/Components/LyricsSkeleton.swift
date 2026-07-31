import SwiftUI

/// A breathing skeleton mirroring a paragraph of lyrics, shown in
/// `LyricsSheet` while the track's lyrics are fetched.
struct LyricsSkeleton: View {
  private let widths: [CGFloat?] = [nil, nil, 300, 190]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(0..<12, id: \.self) { index in
        SkeletonTextLine(width: widths[index % widths.count])
      }
    }
    .skeletonBreath()
  }
}

#Preview("Lyrics Skeleton") {
  ZStack {
    Color.moonCream.ignoresSafeArea()
    LyricsSkeleton()
      .padding(.edge)
  }
}
