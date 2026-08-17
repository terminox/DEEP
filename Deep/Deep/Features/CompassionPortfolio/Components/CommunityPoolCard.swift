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
      CompassionRing(segments: .allocation(of: categories), lineWidth: 14)
      // A heart crowning the count, where the word "POOLED" used to sit: the
      // card is already titled, so the glyph says what kind of number this is
      // without spelling it. Blush, at the app's usual heart weight.
      VStack(spacing: 4) {
        Image(systemName: "heart.fill")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.blushPowder)
        Text(pooled.formatted(.number.notation(.compactName)))
          .font(DeepType.counter)
          .foregroundStyle(.deepPlum)
          .monospacedDigit()
          .contentTransition(.numericText(value: Double(pooled)))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
    }
    // 140, not 116: the taller centre stack needs the room, and wider arcs give
    // each cause's colour enough area to be told apart at a glance.
    .frame(width: 140, height: 140)
    // The arcs stay decorative — `CompassionRing` hides itself, and the legend
    // below is the accessible chart. But the total is spoken nowhere else, and
    // the heart that replaced "POOLED" can't be read aloud, so name it here.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Hearts pooled")
    .accessibilityValue(pooled.formatted())
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
      // The marker carries both readings. Its colour maps the row to an arc —
      // honestly, now that each cause wears a single-hue palette: `CompassionRing`
      // resolves an arc's gradient across the *full circle's* bounds, so an arc
      // shows only the slice beneath it, and only a one-colour palette survives
      // that. Its glyph maps the row to the *cause*, and thence to that cause's
      // card in the carousel below — the mapping a member actually needs.
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
