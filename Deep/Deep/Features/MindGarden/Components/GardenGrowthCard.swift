import SwiftUI

/// The garden's opening card — a greeting over the oak itself: only the current
/// form, held in a halo that closes as points bank. The next form is named,
/// never shown — evolving stays something to look forward to — and beside the
/// name sit the two facts that matter, each on ground of its own colour: how
/// far the next form is, and how many days in a row the garden has been tended.
struct GardenGrowthCard: View {
  let greeting: GardenGreeting
  let growth: GardenGrowth
  /// Consecutive practice days; 0 hides the streak entirely — a fresh garden
  /// shouldn't open with a zero.
  var streakDays: Int = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      salutation

      OakGrowthRow(growth: growth, streakDays: streakDays)
    }
    .padding(20)
    .frostedCard()
  }

  /// The greeting takes the whole card width — nothing shares its line, so the
  /// day's quote breaks where the sentence wants to rather than where a chip
  /// in the corner forces it.
  private var salutation: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(greeting.salutation)
        .font(DeepType.sectionTitle)
        .foregroundStyle(.deepPlum)
      Text(greeting.quote)
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// The oak as it stands today: its portrait inside the growth halo, beside its
/// name and the two facts that matter, stacked one per line.
///
/// Each figure is tinted to the world it comes from — foliage green for what
/// the oak has drunk, sunlight rose for the days that fed it — so it carries
/// the colour of its own glyph. Only the numeral takes the tint; the words
/// around it stay grey, which keeps the colour to a mark rather than a wash.
///
/// One element to VoiceOver — the summary tells the whole story in a sentence.
private struct OakGrowthRow: View {
  let growth: GardenGrowth
  let streakDays: Int

  var body: some View {
    HStack(spacing: 16) {
      OakGrowthHalo(stage: growth.stage, progress: growth.evolutionProgress)

      VStack(alignment: .leading, spacing: 5) {
        Text(growth.stage.displayName)
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)

        growthFact
        if streakDays > 0 { streakFact }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .animation(.exhale, value: growth.evolutionProgress)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(summary)
  }

  /// How far the next form is, as banked over goal — the figure the halo shows
  /// as an arc, said precisely. The next form is named but never pictured.
  private var growthFact: some View {
    fact(symbol: "leaf.fill", tint: GardenColor.fern) {
      figures
        .contentTransition(.numericText())
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var figures: Text {
    guard let next = growth.nextStage, let goal = growth.pointsToEvolve else {
      return Text("Fully grown")
        .font(DeepType.caption)
        .foregroundStyle(GardenColor.fern)
    }
    return Text(growth.points.formatted())
      .font(DeepType.caption.weight(.semibold))
      .foregroundStyle(GardenColor.fern)
      + Text("/\(goal.formatted()) to \(next.displayName)")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
  }

  private var streakFact: some View {
    fact(symbol: "sun.max.fill", tint: .duskRose.opacity(0.8)) {
      (
        Text(streakDays.formatted())
          .font(DeepType.caption.weight(.semibold))
          .foregroundStyle(.duskRose)
        + Text(streakDays == 1 ? " day in a row" : " days in a row")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      )
      .contentTransition(.numericText(value: Double(streakDays)))
      .monospacedDigit()
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  /// The app's glyph-and-numeral fact, bare on the frost. The glyph and the
  /// figure it introduces share a colour, so the pair reads as one mark.
  private func fact<Label: View>(
    symbol: String,
    tint: Color,
    @ViewBuilder label: () -> Label
  ) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 5) {
      Image(systemName: symbol)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(tint)
      label()
    }
  }

  private var summary: String {
    var parts = [growth.stage.displayName]
    if let next = growth.nextStage, let goal = growth.pointsToEvolve {
      parts.append("\(growth.points) of \(goal) growth points to \(next.displayName)")
    } else {
      parts.append("fully grown")
    }
    if streakDays > 0 {
      parts.append(streakDays == 1 ? "1 day in a row" : "\(streakDays) days in a row")
    }
    return parts.joined(separator: ", ")
  }
}

/// The oak's current form inside a slow ring of growth. The artwork ships on an
/// opaque white square, so a circle crop turns it into a soft orb — a rim
/// vignette melts the white edge into the frost so it doesn't sit like a
/// sticker. The halo fills with the `.exhale` motion as growth points bank,
/// and once the ring closes it settles into a gentle glow.
///
/// The arc glows into the card rather than sitting on it — a blurred, dimmed
/// copy of itself underneath, the same bloom `CompassionRing` gives every other
/// ring in the app — and the track it rides is `meadow`, so the distance still
/// to go reads as green rather than as an absence.
private struct OakGrowthHalo: View {
  let stage: OakStage
  /// 0...1 fraction toward the next form; 1 once fully grown.
  let progress: Double

  var portraitDiameter: CGFloat = 84
  var ringGap: CGFloat = 5
  var ringWidth: CGFloat = 3.5

  private var isComplete: Bool { progress >= 1 }
  private var totalDiameter: CGFloat { portraitDiameter + 2 * (ringGap + ringWidth) }

  var body: some View {
    ZStack {
      halo
      portrait
    }
    .frame(width: totalDiameter, height: totalDiameter)
    .animation(.exhale, value: progress)
  }

  private var halo: some View {
    ZStack {
      Circle()
        .stroke(GardenColor.meadow.opacity(0.55), lineWidth: ringWidth)
      arc
        .blur(radius: ringWidth * 0.6)
        .opacity(0.5)
      arc
        .shadow(color: isComplete ? GardenColor.fern.opacity(0.3) : .clear, radius: 6)
    }
    .padding(ringWidth / 2)
  }

  private var arc: some View {
    Circle()
      .trim(from: 0, to: min(1, max(0, progress)))
      .stroke(
        LinearGradient(
          colors: [GardenColor.sage, GardenColor.fern],
          startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
      )
      .rotationEffect(.degrees(-90))
  }

  private var portrait: some View {
    Image(stage.imageName)
      .resizable()
      .scaledToFill()
      .frame(width: portraitDiameter, height: portraitDiameter)
      .clipShape(Circle())
      .overlay {
        Circle().fill(
          RadialGradient(
            colors: [.clear, Color.softLilac.opacity(0.22)],
            center: .center,
            startRadius: portraitDiameter * 0.3,
            endRadius: portraitDiameter / 2
          )
        )
      }
      .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
  }
}

#Preview("Growth — sample") {
  ZStack {
    AtmosphereBackground()
    GardenGrowthCard(greeting: .sample, growth: .sample, streakDays: 12)
      .padding(.edge)
  }
}

#Preview("Growth — fresh") {
  ZStack {
    AtmosphereBackground()
    GardenGrowthCard(greeting: .sample, growth: .sprouting, streakDays: 0)
      .padding(.edge)
  }
}

#Preview("Growth — first day") {
  ZStack {
    AtmosphereBackground()
    GardenGrowthCard(greeting: .sample, growth: .sprouting, streakDays: 1)
      .padding(.edge)
  }
}

#Preview("Growth — fully grown") {
  ZStack {
    AtmosphereBackground()
    GardenGrowthCard(greeting: .evening, growth: .fullyGrown, streakDays: 30)
      .padding(.edge)
  }
}

#Preview("Growth — narrow") {
  ZStack {
    AtmosphereBackground()
    GardenGrowthCard(greeting: .sample, growth: .sample, streakDays: 365)
      .frame(width: 335)
  }
}

#Preview("Growth — large type") {
  ZStack {
    AtmosphereBackground()
    GardenGrowthCard(greeting: .sample, growth: .sample, streakDays: 12)
      .padding(.edge)
  }
  .environment(\.dynamicTypeSize, .accessibility2)
}
