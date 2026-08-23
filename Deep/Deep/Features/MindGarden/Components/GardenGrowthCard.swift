import SwiftUI

/// The garden's opening card — a greeting over the plant itself: only the
/// current form, held in a halo that closes as sunlight banks. The next form is
/// named, never shown — evolving stays something to look forward to — and
/// beside the name sits the one fact that matters: how much sunlight still
/// stands between this plant and what it becomes next.
struct GardenGrowthCard: View {
  let greeting: GardenGreeting
  let growth: GardenGrowth
  /// When set, a whisper of a "Change" affordance sits under the plant's name
  /// — the way into the plant picker. Nil (previews, fixtures) hides it.
  var onChangePlant: (() -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      salutation

      PlantGrowthRow(growth: growth, onChangePlant: onChangePlant)
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

/// The plant as it stands today: its portrait inside the growth halo, beside
/// its name and the sunlight it still owes its next form.
///
/// The fact is tinted to what it counts — `sunbeam` gold for sunlight, the
/// thing the plant drinks — so its glyph and its figure read as one mark. Green
/// stays the plant's own colour, kept for the halo. Only the numeral takes the
/// tint; the words around it stay grey, which keeps the colour to a mark rather
/// than a wash.
///
/// One element to VoiceOver — the summary tells the whole story in a sentence.
private struct PlantGrowthRow: View {
  let growth: GardenGrowth
  var onChangePlant: (() -> Void)? = nil

  var body: some View {
    HStack(spacing: 16) {
      PlantGrowthHalo(
        stage: growth.stage,
        palette: growth.plant.palette,
        progress: growth.evolutionProgress
      )

      VStack(alignment: .leading, spacing: 5) {
        Text(growth.stage.name)
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)

        sunlightFact
        if onChangePlant != nil { changeAffordance }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .animation(.exhale, value: growth.evolutionProgress)
    // One element to VoiceOver — hit testing is untouched, so the quiet
    // change button still taps; VoiceOver reaches it via the named action.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(summary)
    .accessibilityActions {
      if let onChangePlant {
        Button("Change plant", action: onChangePlant)
      }
    }
  }

  /// A whisper into the plant picker — caption-weight, `driftGrey`, no chrome
  /// of its own; the card stays the card.
  @ViewBuilder
  private var changeAffordance: some View {
    if let onChangePlant {
      Button(action: onChangePlant) {
        HStack(spacing: 3) {
          Text("Change")
            .font(DeepType.caption)
          Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.driftGrey)
      }
      .buttonStyle(.softPress)
      .padding(.top, 2)
    }
  }

  /// How far the next form is, as sunlight banked over goal — the figure the
  /// halo shows as an arc, said precisely. The next form is named but never
  /// pictured.
  private var sunlightFact: some View {
    fact(symbol: "sun.max.fill", tint: GardenColor.sunbeam) {
      sunlightFigures
        .contentTransition(.numericText())
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var sunlightFigures: Text {
    guard let next = growth.nextStage, let goal = growth.sunlightToEvolve else {
      return Text("Fully grown")
        .font(DeepType.caption)
        .foregroundStyle(GardenColor.sunbeam)
    }
    return Text(growth.sunlight.formatted())
      .font(DeepType.caption.weight(.semibold))
      .foregroundStyle(GardenColor.sunbeam)
      + Text("/\(goal.formatted()) to \(next.name)")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
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
    guard let next = growth.nextStage, let goal = growth.sunlightToEvolve else {
      return "\(growth.stage.name), fully grown"
    }
    return "\(growth.stage.name), \(growth.sunlight) of \(goal) sunlight to \(next.name)"
  }
}

/// The plant's current form inside a slow ring of growth. The portrait is the
/// stage's mascot via `ArtworkImage` — falling back gracefully to the plant's
/// gradient while art loads or none exists — cropped to a soft orb, with a rim
/// vignette melting the edge into the frost so it doesn't sit like a sticker.
/// The halo fills with the `.exhale` motion as sunlight banks, and once the
/// ring closes it settles into a gentle glow.
///
/// The arc glows into the card rather than sitting on it — a blurred, dimmed
/// copy of itself underneath, the same bloom `CompassionRing` gives every other
/// ring in the app — and the track it rides is `meadow`, so the distance still
/// to go reads as green rather than as an absence. The ring is the plant, so it
/// stays green; the gold beside it belongs to the sunlight that fills it.
private struct PlantGrowthHalo: View {
  let stage: PlantStage
  let palette: ArtworkPalette
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
    ArtworkImage(
      url: stage.mascotURL,
      colors: palette.colors,
      cornerRadius: portraitDiameter / 2,
      placeholderSystemImage: "leaf.fill",
      bordered: false
    )
    .frame(width: portraitDiameter, height: portraitDiameter)
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
    GardenGrowthCard(greeting: .sample, growth: .sample)
      .padding(.edge)
  }
}

#Preview("Growth — change affordance") {
  ZStack {
    AtmosphereBackground()
    GardenGrowthCard(greeting: .sample, growth: .sample, onChangePlant: {})
      .padding(.edge)
  }
}

#Preview("Growth — fresh") {
  ZStack {
    AtmosphereBackground()
    GardenGrowthCard(greeting: .sample, growth: .sprouting)
      .padding(.edge)
  }
}

#Preview("Growth — fully grown") {
  ZStack {
    AtmosphereBackground()
    GardenGrowthCard(greeting: .evening, growth: .fullyGrown)
      .padding(.edge)
  }
}

#Preview("Growth — narrow") {
  ZStack {
    AtmosphereBackground()
    GardenGrowthCard(greeting: .sample, growth: .sample)
      .frame(width: 335)
  }
}

#Preview("Growth — large type") {
  ZStack {
    AtmosphereBackground()
    GardenGrowthCard(greeting: .sample, growth: .sample)
      .padding(.edge)
  }
  .environment(\.dynamicTypeSize, .accessibility2)
}
