import SwiftUI

/// Where the community's pooled hearts have gone — the allocation ring given its
/// own card, with a legend that makes it readable rather than merely decorative.
///
/// Paired with `CompassionPortfolioCard` above it: "MY HEARTS" there, "THE
/// COMMUNITY POOL" here — *mine*, then *ours*. That rhyme is the whole reason
/// this is a second card instead of a second row bolted onto the first.
struct CommunityPoolCard: View {
  let categories: [CompassionCategory]
  let peopleReached: Int

  private var pooled: Int {
    categories.heartsPooled
  }

  var body: some View {
    VStack(spacing: 14) {
      Text("THE COMMUNITY POOL")
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.driftGrey)

      ring
        .padding(.bottom, 2)

      legend

      Text("\(peopleReached.formatted(.number.notation(.compactName))) people reached across \(categories.count) causes")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(20)
    .frostedCard()
  }

  private var ring: some View {
    ZStack {
      CompassionRing(segments: .allocation(of: categories), lineWidth: 12)
      VStack(spacing: 2) {
        Text(pooled.formatted(.number.notation(.compactName)))
          .font(DeepType.counter)
          .foregroundStyle(.deepPlum)
          .monospacedDigit()
          .contentTransition(.numericText(value: Double(pooled)))
        Text("POOLED")
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)
      }
    }
    .frame(width: 116, height: 116)
    // The legend below is the accessible chart now; the ring itself is
    // decorative to VoiceOver.
    .accessibilityHidden(true)
  }

  private var legend: some View {
    VStack(spacing: 10) {
      // Iterate `categories` in the given order, never sorted by share — the
      // carousel below renders the same five glyphs in the same order, and
      // that repetition is what makes this legend navigable at a glance.
      ForEach(categories) { category in
        legendRow(for: category)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .pebble()
  }

  private func legendRow(for category: CompassionCategory) -> some View {
    HStack(spacing: 10) {
      // The marker is a glyph, not a colour dot. `CompassionRing` resolves each
      // arc's gradient across the *full circle's* bounds, so an arc shows only
      // the slice of its gradient beneath it — colour can't map a legend row to
      // an arc at any size (two palettes can render nearly the same colour;
      // `.mist` and `.tide` are exact reverses of one another). The glyph maps
      // the row to the *cause* instead, and thence to that cause's card in the
      // carousel below — the mapping a member actually needs.
      CompassionMotif(
        symbol: category.symbol,
        palette: category.palette,
        cornerRadius: .chip,
        symbolScale: 0.46,
        symbolOpacity: 0.95,
        symbolShadow: false,
        bordered: false
      )
      .frame(width: 20, height: 20)

      Text(category.name)
        .font(DeepType.body)
        .foregroundStyle(.deepPlum)
        .lineLimit(1)

      Spacer(minLength: 8)

      Text(share(of: category), format: .percent.precision(.fractionLength(0)))
        .font(DeepType.caption.weight(.semibold))
        .foregroundStyle(.deepPlum)
        .monospacedDigit()
        .contentTransition(.numericText(value: share(of: category)))
        .frame(width: 40, alignment: .trailing)
    }
    .accessibilityElement(children: .combine)
  }

  /// This category's slice of the pool — read from the model's one definition,
  /// so this legend and the cause cards below can't drift apart.
  private func share(of category: CompassionCategory) -> Double {
    categories.shareOfGiving(category)
  }
}

#Preview("Community pool") {
  ZStack {
    AtmosphereBackground()
    CommunityPoolCard(
      categories: CompassionLibrary.categories,
      peopleReached: HeartLedger.sample.peopleReached
    )
    .padding(.edge)
  }
}

#Preview("Community pool — large type") {
  ZStack {
    AtmosphereBackground()
    CommunityPoolCard(
      categories: CompassionLibrary.categories,
      peopleReached: HeartLedger.sample.peopleReached
    )
    .padding(.edge)
  }
  .environment(\.dynamicTypeSize, .accessibility2)
}
