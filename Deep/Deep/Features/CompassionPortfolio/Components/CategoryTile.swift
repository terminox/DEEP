import SwiftUI

/// A single cause in the portfolio's "where your hearts go" carousel. The card
/// wears a full-bleed motif banner of the cause's own palette, so five causes
/// read as five warmths rather than five identical boxes. Tapping it routes to
/// the cause detail through the coordinator's injected `openCategory` action —
/// never a `NavigationLink`.
struct CategoryTile: View {
  @Environment(\.openCategory) private var openCategory
  let category: CompassionCategory
  var width: CGFloat = 210

  private let bannerHeight: CGFloat = 132

  var body: some View {
    Button {
      openCategory(category)
    } label: {
      VStack(alignment: .leading, spacing: 0) {
        banner

        VStack(alignment: .leading, spacing: 4) {
          Text(category.name)
            .font(DeepType.sectionTitle)
            .foregroundStyle(.deepPlum)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
          // `reservesSpace` is mandatory, not decorative: it is what levels the
          // five cards' heights, since "Protecting nature for future
          // generations" wraps to two lines while "Calmer minds, a kinder
          // world" does not.
          Text(category.tagline)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .lineLimit(2, reservesSpace: true)
            .fixedSize(horizontal: false, vertical: true)

          heartsFact
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Belt-and-braces against Dynamic Type: lets the text column stretch
        // to fill any leftover height instead of the reserved-line math
        // falling short, the `ImpactPebbles.swift:17` idiom. Must sit inside
        // the padding and before `.frame(width:)` / `.frostedCard(...)`, or
        // the background won't stretch with it.
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 14)
      }
      .frame(width: width)
      .frostedCard(tint: category.palette.colors.first)
    }
    .buttonStyle(.softPress)
    .accessibilityElement(children: .combine)
    .accessibilityHint("Opens \(category.name)")
  }

  /// The cause's motif, crisp and centred — not the trailing watermark
  /// treatment — so it reads as the same mark that appears at 20pt in the
  /// pool card's legend and at 60pt in the field-report thumbs.
  private var banner: some View {
    let shape = UnevenRoundedRectangle(
      topLeadingRadius: .card,
      bottomLeadingRadius: 0,
      bottomTrailingRadius: 0,
      topTrailingRadius: .card,
      style: .continuous
    )
    // `bordered: false` isn't cosmetic: a bordered artwork clipped at its
    // lower edge draws a straight 0.5pt white line across the card's waist —
    // exactly the hairline rule this project never draws.
    return CompassionMotif(
      symbol: category.symbol,
      palette: category.palette,
      cornerRadius: 0,
      symbolScale: 0.46,
      symbolOpacity: 0.90,
      bordered: false
    )
    .frame(height: bannerHeight)
    .clipShape(shape)
  }

  private var heartsFact: some View {
    HStack(spacing: 5) {
      Image(systemName: "heart.fill")
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.blushPowder)
      Text("\(category.heartsShared.formatted(.number.notation(.compactName))) hearts")
        .font(DeepType.caption.weight(.medium))
        .foregroundStyle(.deepPlum)
        .monospacedDigit()
        .contentTransition(.numericText(value: Double(category.heartsShared)))
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .pebble(cornerRadius: .chip)
    .fixedSize()
  }
}

#Preview("Category tile") {
  ZStack {
    AtmosphereBackground()
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(alignment: .top, spacing: 16) {
        ForEach(CompassionLibrary.categories) { category in
          CategoryTile(category: category)
        }
      }
      .padding(.edge)
    }
  }
  .environment(\.openCategory, { _ in })
}

#Preview("Category tile — accessibility1") {
  ZStack {
    AtmosphereBackground()
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(alignment: .top, spacing: 16) {
        ForEach(CompassionLibrary.categories) { category in
          CategoryTile(category: category)
        }
      }
      .padding(.edge)
    }
  }
  .environment(\.openCategory, { _ in })
  .environment(\.dynamicTypeSize, .accessibility1)
}
