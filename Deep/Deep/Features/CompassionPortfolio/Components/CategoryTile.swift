import SwiftUI

/// A single cause in the portfolio's "where your hearts go" shelf. The card
/// wears a full-bleed motif banner of the cause's own palette, so five causes
/// read as five warmths rather than five identical boxes.
///
/// The tile is where giving happens now: the cause detail is no longer routed
/// to, so this card carries the whole act — what the cause is, what has flowed
/// to it, the share of Deep's giving that follows, and the donate button that
/// opens the amount sheet through the coordinator's injected `openDonation`
/// action. The card body itself is not a button; only the capsule acts.
struct CategoryTile: View {
  @Environment(\.heartLedger) private var ledger
  @Environment(\.openDonation) private var openDonation
  let category: CompassionCategory
  var width: CGFloat = 224

  private let bannerHeight: CGFloat = 132

  /// The live snapshot of this cause — its pooled total climbs as hearts are
  /// sent, and the share underneath has to move with it.
  private var live: CompassionCategory {
    ledger.category(category.id) ?? category
  }

  /// This cause's slice of the pool, and so of the money Deep gives. Read from
  /// the model's single definition, which the community pool legend above the
  /// shelf reads too — the two say the same number by construction.
  private var share: Double {
    ledger.categories.shareOfGiving(live)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      banner

      VStack(alignment: .leading, spacing: 4) {
        Text(live.name)
          .font(DeepType.sectionTitle)
          .foregroundStyle(.deepPlum)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
        // `reservesSpace` is mandatory, not decorative: it is what levels the
        // five cards' heights, since "Protecting nature for future
        // generations" wraps to two lines while "Calmer minds, a kinder
        // world" does not.
        Text(live.tagline)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .lineLimit(2, reservesSpace: true)
          .fixedSize(horizontal: false, vertical: true)

        facts
          .padding(.top, 8)

        // Holds the capsule to the card's floor, so the five buttons line up
        // even when a name scales down or a fact wraps.
        Spacer(minLength: 12)

        action
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
    .accessibilityElement(children: .contain)
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
      symbol: live.symbol,
      palette: live.palette,
      cornerRadius: 0,
      symbolScale: 0.46,
      symbolOpacity: 0.90,
      bordered: false
    )
    .frame(height: bannerHeight)
    .clipShape(shape)
  }

  /// Two figures on one tonal panel, told as labelled rows rather than two
  /// chips side by side: a bare "22%" beside a hearts count could be read as a
  /// share of anything, and at this width a second chip would crowd the first.
  private var facts: some View {
    VStack(alignment: .leading, spacing: 6) {
      fact(symbol: "heart.fill", tint: .blushPowder) {
        Text("\(live.heartsShared.formatted(.number.notation(.compactName))) hearts")
          .contentTransition(.numericText(value: Double(live.heartsShared)))
      }
      fact(symbol: "chart.pie.fill", tint: .lavenderMist) {
        HStack(spacing: 4) {
          Text(share, format: .percent.precision(.fractionLength(0)))
            .contentTransition(.numericText(value: share))
          Text("of giving")
        }
      }
    }
    .font(DeepType.caption.weight(.medium))
    .foregroundStyle(.deepPlum)
    .monospacedDigit()
    .lineLimit(1)
    .minimumScaleFactor(0.8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .pebble(cornerRadius: .tile)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "\(live.heartsShared.formatted()) hearts pooled, "
        + "\(Int((share * 100).rounded())) percent of giving"
    )
  }

  private func fact<Label: View>(
    symbol: String,
    tint: Color,
    @ViewBuilder label: () -> Label
  ) -> some View {
    HStack(spacing: 6) {
      Image(systemName: symbol)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(tint)
        // A fixed glyph column, so the two labels start on the same edge
        // however wide the symbols are.
        .frame(width: 12)
      label()
    }
  }

  /// Once the balance is spent the capsule becomes a quiet note rather than a
  /// dimmed button — `SendAHeartBar`'s doctrine: Deep would rather say "come
  /// back after a practice" than "you can't".
  @ViewBuilder
  private var action: some View {
    Group {
      if ledger.canGive {
        donateButton
      } else {
        spentNote
      }
    }
    .animation(.exhale, value: ledger.canGive)
  }

  /// The house gradient CTA (`SendAHeartBar.sendButton`), minus its shadow: the
  /// frosted card is already blooming, and a second bloom inside a 224pt card
  /// gathers into a smudge instead of lifting the button.
  private var donateButton: some View {
    Button {
      openDonation(live)
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "heart.fill")
          .font(.system(size: 14, weight: .semibold))
        Text("Donate hearts")
      }
      .font(DeepType.sectionTitle)
      .foregroundStyle(.white)
      .lineLimit(1)
      .minimumScaleFactor(0.75)
      .padding(.horizontal, 16)
      .padding(.vertical, 13)
      .frame(maxWidth: .infinity)
      .background {
        Capsule().fill(
          LinearGradient(colors: [.lavenderMist, .blushPowder], startPoint: .leading, endPoint: .trailing)
        )
      }
    }
    .buttonStyle(.softPress)
    .accessibilityLabel("Donate hearts to \(live.name)")
  }

  private var spentNote: some View {
    Text("Practice earns more")
      .font(DeepType.sectionTitle)
      .foregroundStyle(.driftGrey)
      .lineLimit(1)
      .minimumScaleFactor(0.75)
      .padding(.horizontal, 16)
      .padding(.vertical, 13)
      .frame(maxWidth: .infinity)
      .pebble(cornerRadius: .chip)
      .accessibilityLabel("No hearts left. Practice earns more.")
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
      .padding(.vertical, 38)
    }
  }
  .environment(\.heartLedger, .sample)
  .environment(\.openDonation, { _ in })
}

#Preview("Category tile — no hearts left") {
  ZStack {
    AtmosphereBackground()
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(alignment: .top, spacing: 16) {
        ForEach(CompassionLibrary.categories) { category in
          CategoryTile(category: category)
        }
      }
      .padding(.edge)
      .padding(.vertical, 38)
    }
  }
  .environment(\.heartLedger, .spent)
  .environment(\.openDonation, { _ in })
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
      .padding(.vertical, 38)
    }
  }
  .environment(\.heartLedger, .sample)
  .environment(\.openDonation, { _ in })
  .environment(\.dynamicTypeSize, .accessibility1)
}
