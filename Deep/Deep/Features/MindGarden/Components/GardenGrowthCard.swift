import SwiftUI

/// The garden's opening card — a greeting over the plant itself: only the
/// current form, held in a halo that closes as sunlight banks. The next form is
/// named, never shown — evolving stays something to look forward to — and
/// beside the name sits the one fact that matters: how much sunlight still
/// stands between this plant and what it becomes next.
struct GardenGrowthCard: View {
  let greeting: GardenGreeting
  let growth: GardenGrowth
  /// When set, a quiet "Change" pill hangs under the plant's portrait — the way
  /// into the plant picker. Nil (previews, fixtures) hides it.
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

/// Seats the copy against the *portrait's* centre rather than the whole avatar
/// column's, so the "Change" pill can hang below the halo without pulling the
/// name and the sunlight fact down with it.
private extension VerticalAlignment {
  enum PlantPortrait: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
      context[VerticalAlignment.center]
    }
  }

  static let plantPortrait = VerticalAlignment(PlantPortrait.self)
}

/// The plant as it stands today: its portrait inside the growth halo, with the
/// way to swap plants hanging beneath it, beside its name and the sunlight it
/// still owes its next form.
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
    HStack(alignment: .plantPortrait, spacing: 16) {
      VStack(spacing: 10) {
        PlantGrowthHalo(
          stage: growth.stage,
          palette: growth.plant.palette,
          progress: growth.evolutionProgress
        )
        .alignmentGuide(.plantPortrait) { $0[VerticalAlignment.center] }

        changePill
      }

      VStack(alignment: .leading, spacing: 5) {
        Text(growth.stage.name)
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)

        sunlightFact
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .alignmentGuide(.plantPortrait) { $0[VerticalAlignment.center] }
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

  /// The way into the plant picker, centred under the plant it would swap: the
  /// card's own inset tonal panel drawn as a pill, so it reads as a real
  /// affordance without borrowing a CTA's weight.
  @ViewBuilder
  private var changePill: some View {
    if let onChangePlant {
      Button(action: onChangePlant) {
        HStack(spacing: 5) {
          Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 10, weight: .semibold))
          Text("Change")
            .font(DeepType.caption.weight(.medium))
        }
        .foregroundStyle(.deepPlum)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .pebble(cornerRadius: .chip)
      }
      .buttonStyle(.softPress)
    }
  }

  /// How far the next form is, as sunlight banked over goal — the figure the
  /// halo shows as an arc, said precisely. The next form is named but never
  /// pictured.
  private var sunlightFact: some View {
    SunlightFact {
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

  private var summary: String {
    guard let next = growth.nextStage, let goal = growth.sunlightToEvolve else {
      return "\(growth.stage.name), fully grown"
    }
    return "\(growth.stage.name), \(growth.sunlight) of \(goal) sunlight to \(next.name)"
  }
}

/// The plant's current form inside a slow ring of growth. The portrait is the
/// stage's mascot via `ArtworkImage` — falling back gracefully to the plant's
/// own catalog art, then to its gradient, while art loads or none exists —
/// cropped to a soft orb, with a rim vignette melting the edge into the frost
/// so it doesn't sit like a sticker. The halo fills with the `.exhale` motion as
/// sunlight banks, and once the ring closes it settles into a gentle glow.
///
/// The arc glows into the card rather than sitting on it — a blurred, dimmed
/// copy of itself underneath, the same bloom `CompassionRing` gives every other
/// ring in the app — and the track it rides is `meadow`, so the distance still
/// to go reads as green rather than as an absence. The ring is the plant, so it
/// stays green; the gold beside it belongs to the sunlight that fills it.
struct PlantGrowthHalo: View {
  let stage: PlantStage
  let palette: ArtworkPalette
  /// 0...1 fraction toward the next form; 1 once fully grown.
  let progress: Double
  /// Shown when the stage has no portrait of its own — the plant's catalog art,
  /// so a half-authored ladder still pictures the plant instead of a gradient.
  var fallbackURL: URL? = nil

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
      url: stage.mascotURL ?? stage.mascotBgURL ?? fallbackURL,
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
    GardenGrowthCard(greeting: .sample, growth: .sprouting, onChangePlant: {})
      .padding(.edge)
  }
}

#Preview("Growth — fully grown") {
  ZStack {
    AtmosphereBackground()
    GardenGrowthCard(greeting: .evening, growth: .fullyGrown, onChangePlant: {})
      .padding(.edge)
  }
}

#Preview("Growth — narrow") {
  ZStack {
    AtmosphereBackground()
    GardenGrowthCard(greeting: .sample, growth: .sample, onChangePlant: {})
      .frame(width: 335)
  }
}

#Preview("Growth — large type") {
  ZStack {
    AtmosphereBackground()
    GardenGrowthCard(greeting: .sample, growth: .sample, onChangePlant: {})
      .padding(.edge)
  }
  .environment(\.dynamicTypeSize, .accessibility2)
}
