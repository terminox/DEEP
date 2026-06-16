import SwiftUI

/// The home's "Made for you" section — a header over a vertical stack of frosted
/// rows. Each row is a leaf that routes through the coordinator on tap.
struct RecommendationsSection: View {
  let items: [HomeItem]
  var seeAll: (() -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HomeSectionHeader(title: "Made for you", seeAll: seeAll)

      VStack(spacing: 12) {
        ForEach(items) { item in
          RecommendationRow(item: item)
        }
      }
      .padding(.horizontal, .edge)
    }
  }
}

private struct RecommendationRow: View {
  @Environment(\.openHomeItem) private var openHomeItem
  let item: HomeItem

  var body: some View {
    Button {
      openHomeItem(item)
    } label: {
      HStack(spacing: 14) {
        ZStack {
          HomeArtwork(palette: item.palette, imageURL: item.imageURL, cornerRadius: 16)
          Image(systemName: "play.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
        }
        .frame(width: 64, height: 64)

        VStack(alignment: .leading, spacing: 3) {
          Text(item.kind.label.uppercased())
            .font(DeepType.micro)
            .tracking(1.2)
            .foregroundStyle(.driftGrey)
          Text(item.title)
            .font(DeepType.body.weight(.semibold))
            .foregroundStyle(.deepPlum)
            .lineLimit(1)
          Text(item.author)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .lineLimit(1)
        }

        Spacer(minLength: 8)

        Text(item.durationLabel)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      }
      .padding(12)
      .frostedCard()
    }
    .buttonStyle(.softPress)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(item.title), \(item.kind.label), \(item.durationLabel)")
  }
}

#Preview("Recommendations") {
  ScrollView {
    RecommendationsSection(items: HomeLibrary.recommended, seeAll: {})
      .padding(.vertical, 24)
  }
  .background { AtmosphereBackground() }
}
