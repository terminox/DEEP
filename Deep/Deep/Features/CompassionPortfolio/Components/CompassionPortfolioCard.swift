import SwiftUI

/// What you hold, held in the day that gave it — the Compassion tab's opening
/// card, built as the sibling of `GardenGrowthCard`'s oak row: a portrait inside
/// a halo, beside its name and the two facts that matter.
///
/// The halo is today. A day hands over at most `HeartLedger.dailyEarnCeiling`
/// hearts, and the ring closes as they arrive — the same dial `DailyPracticeCard`
/// wears for the daily minute goal, one size up. That repetition is deliberate:
/// the halo is this app's way of showing a proportion, so the card carrying the
/// member's own balance should wear it too.
///
/// The pooled allocation ring lives in `CommunityPoolCard` below — *mine*, then
/// *ours*.
struct CompassionPortfolioCard: View {
  let ledger: HeartLedger

  var body: some View {
    HStack(spacing: 16) {
      HeartDayHalo(
        progress: todayProgress,
        isFull: ledger.isTodayFull
      )

      VStack(alignment: .leading, spacing: 5) {
        Text("MY HEARTS")
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)

        Text(headline)
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
          .fixedSize(horizontal: false, vertical: true)
          .contentTransition(.numericText(value: Double(ledger.balance)))

        // One fact per line rather than `GardenGrowthCard`'s `ViewThatFits` row:
        // these two run ~3pt short of the column at default type, and a layout
        // that decides differently between launches is worse than one that
        // always stacks. Stacked, the column also sits level with the halo.
        //
        // Nothing given yet stays unsaid; a first day shouldn't open with a zero.
        if ledger.heartsGiven > 0 { givenFact }
        todayFact
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(20)
    .frostedCard()
    .animation(.exhale, value: todayProgress)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(summary)
  }

  /// How much of today's ceiling has arrived, `0...1`.
  private var todayProgress: Double {
    Double(ledger.heartsEarnedToday) / Double(HeartLedger.dailyEarnCeiling)
  }

  /// The balance as the card's name. A spent balance is told as what it means —
  /// everything went to a cause — rather than as a zero.
  private var headline: String {
    if ledger.canGive {
      return String(
        localized: "\(ledger.balance.formatted(.number.locale(.app))) to give",
        bundle: .app,
        locale: .app
      )
    }
    return ledger.heartsGiven > 0
      ? String(localized: "All given away", bundle: .app, locale: .app)
      : String(localized: "No hearts yet", bundle: .app, locale: .app)
  }

  /// The lifetime figure — hearts that have left for a cause.
  private var givenFact: some View {
    fact(symbol: "heart.fill", size: 10, tint: .blushPowder) {
      (
        Text(ledger.heartsGiven.formatted())
          .font(DeepType.caption.weight(.semibold))
          .foregroundStyle(.deepPlum)
        + Text(" given")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      )
      .contentTransition(.numericText(value: Double(ledger.heartsGiven)))
      .monospacedDigit()
    }
  }

  /// What today has handed over so far. Once the day is full it stops counting
  /// and names the state — a full day is somewhere to rest, not a score to read.
  private var todayFact: some View {
    fact(symbol: "heart.fill", size: 11, tint: .duskRose.opacity(0.75)) {
      if ledger.isTodayFull {
        Text("today is full")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      } else {
        (
          Text(ledger.heartsEarnedToday.formatted())
            .font(DeepType.caption.weight(.semibold))
            .foregroundStyle(.deepPlum)
          + Text(" of \(HeartLedger.dailyEarnCeiling) today")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
        )
        .contentTransition(.numericText(value: Double(ledger.heartsEarnedToday)))
        .monospacedDigit()
      }
    }
  }

  private func fact<Label: View>(
    symbol: String,
    size: CGFloat,
    tint: Color,
    @ViewBuilder label: () -> Label
  ) -> some View {
    HStack(spacing: 5) {
      Image(systemName: symbol)
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(tint)
      label()
    }
    .fixedSize()
  }

  /// One sentence for VoiceOver — the figures the halo shows visually.
  private var summary: String {
    var parts: [String] = []
    parts.append(
      ledger.canGive
        ? "\(ledger.balance) hearts to give"
        : "No hearts left to give"
    )
    if ledger.heartsGiven > 0 {
      parts.append("\(ledger.heartsGiven) given")
    }
    parts.append(
      ledger.isTodayFull
        ? "Today is full, \(HeartLedger.dailyEarnCeiling) hearts earned"
        : "\(ledger.heartsEarnedToday) of \(HeartLedger.dailyEarnCeiling) hearts earned today"
    )
    return parts.joined(separator: ". ")
  }
}

/// The member's hearts as a portrait inside the day's halo — the same
/// construction as the oak in its growth ring, and the same ring `DailyPracticeCard`
/// wraps around today's practice.
///
/// A gradient motif rather than a filled gradient disc: the disc is this app's
/// primary-action button (`playCircle`, the cause send button), and this card
/// isn't tappable.
private struct HeartDayHalo: View {
  /// Today's fill, `0...1`.
  let progress: Double
  /// Whether the day has given everything it has.
  let isFull: Bool

  var portraitDiameter: CGFloat = 80
  /// Wider than the garden's halo: there the ring reads against a green arc on a
  /// brown portrait, while here ring and portrait share the same warmth, so the
  /// day needs both weight and a little more frost around it to stay legible.
  var ringGap: CGFloat = 7
  var ringWidth: CGFloat = 5

  private var totalDiameter: CGFloat { portraitDiameter + 2 * (ringGap + ringWidth) }

  var body: some View {
    ZStack {
      CompassionRing(
        segments: [
          RingSegment(share: min(1, max(0, progress)), colors: [.lavenderMist, .blushPowder])
        ],
        lineWidth: ringWidth,
        gap: 0
      )
      // A closed day settles into a glow rather than announcing itself.
      .shadow(color: isFull ? Color.blushPowder.opacity(0.55) : .clear, radius: 7)

      // `.dusk` rather than `.bloom`: the artwork lays a plum vignette across its
      // bottom-trailing corner, and blush-into-lilac greys out under it. Lavender
      // into blush stays chromatic, and its mid-tone leading edge is what lets the
      // white glyph read.
      CompassionMotif(
        symbol: "heart.fill",
        palette: .dusk,
        cornerRadius: .chip,
        symbolScale: 0.4
      )
      .padding(ringGap + ringWidth)
    }
    .frame(width: totalDiameter, height: totalDiameter)
    .animation(.exhale, value: progress)
    .accessibilityHidden(true)
  }
}

#Preview("Portfolio card") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: .rhythm) {
      CompassionPortfolioCard(ledger: .sample)
      CompassionPortfolioCard(ledger: .fresh)
      CompassionPortfolioCard(ledger: .spent)
    }
    .padding(.edge)
  }
}

#Preview("Portfolio card — large type") {
  ZStack {
    AtmosphereBackground()
    CompassionPortfolioCard(ledger: .sample)
      .padding(.edge)
  }
  .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Portfolio card — narrow") {
  ZStack {
    AtmosphereBackground()
    CompassionPortfolioCard(ledger: .sample)
      .frame(width: 335)
  }
}
