import SwiftUI

/// The garden's opening card — a compact greeting beside the growth-point
/// balance, over the oak itself: only the current form, held in a halo that
/// closes as points bank. The next form is named, never shown — evolving stays
/// something to look forward to — and beneath the name sit the two facts that
/// matter: how far the next form is, and how many days in a row the garden has
/// been tended.
struct GardenGrowthCard: View {
  let greeting: GardenGreeting
  let growth: GardenGrowth
  /// Consecutive practice days; 0 hides the streak line entirely — a fresh
  /// garden shouldn't open with a zero.
  var streakDays: Int = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
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

        GrowthPointsChip(points: growth.points)
      }

      OakGrowthRow(growth: growth, streakDays: streakDays)
    }
    .padding(20)
    .frostedCard()
  }
}

/// The banked growth balance as a soft pill — what the oak has drunk so far.
/// Silent to VoiceOver: the growth row's summary carries the figure instead.
private struct GrowthPointsChip: View {
  let points: Int

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "leaf.fill")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(GardenColor.fern)
      Text(points.formatted())
        .font(DeepType.caption.weight(.semibold))
        .foregroundStyle(.deepPlum)
        .contentTransition(.numericText(value: Double(points)))
        .monospacedDigit()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background {
      Capsule()
        .fill(.white.opacity(0.65))
        .overlay(Capsule().strokeBorder(.white.opacity(0.4), lineWidth: 0.5))
    }
    .accessibilityHidden(true)
  }
}

/// The oak as it stands today: its portrait inside the growth halo, beside its
/// name and, in one quiet line, the two facts that matter — number-forward
/// tokens for the distance to the next form and the tending streak. One
/// element to VoiceOver — the summary tells the whole story in a sentence.
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

        // Both facts share a line where the width allows — the sun glyph is
        // all the separation they need — and stack on narrow widths or
        // large type.
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 14) { facts }
          VStack(alignment: .leading, spacing: 5) { facts }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .animation(.exhale, value: growth.evolutionProgress)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(summary)
  }

  @ViewBuilder private var facts: some View {
    distanceFact
    if streakDays > 0 { streakFact }
  }

  /// How far the next form is — always the points still to grow, never a
  /// banked-of-goal fraction; growth is a journey, not a scoreboard.
  private var distanceFact: some View {
    Group {
      if let next = growth.nextStage, let remaining = growth.pointsRemaining {
        Text("\(remaining)")
          .font(DeepType.caption.weight(.semibold))
          .foregroundStyle(.deepPlum)
        + Text(" to \(next.displayName)")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      } else {
        Text("Fully grown")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      }
    }
    .contentTransition(.numericText())
    .monospacedDigit()
  }

  private var streakFact: some View {
    HStack(spacing: 5) {
      Image(systemName: "sun.max.fill")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.duskRose.opacity(0.75))
      (
        Text("\(streakDays)")
          .font(DeepType.caption.weight(.semibold))
          .foregroundStyle(.deepPlum)
        + Text(streakDays == 1 ? " day" : " days")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      )
      .contentTransition(.numericText(value: Double(streakDays)))
      .monospacedDigit()
    }
  }

  private var summary: String {
    var parts = [growth.stage.displayName]
    if let next = growth.nextStage, let remaining = growth.pointsRemaining {
      parts.append("\(growth.points) growth points, \(remaining) more to \(next.displayName)")
    } else {
      parts.append("fully grown, \(growth.points) growth points")
    }
    if streakDays > 0 {
      parts.append(streakDays == 1 ? "1 day streak" : "\(streakDays) day streak")
    }
    return parts.joined(separator: ", ")
  }
}

/// The oak's current form inside a slow ring of growth. The artwork ships on an
/// opaque white square, so a circle crop turns it into a soft orb — a rim
/// vignette melts the white edge into the frost so it doesn't sit like a
/// sticker. The halo fills with the `.exhale` motion as growth points bank,
/// and once the ring closes it settles into a gentle glow.
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
        .stroke(GardenColor.sage.opacity(0.18), lineWidth: ringWidth)
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
        .shadow(color: isComplete ? GardenColor.fern.opacity(0.3) : .clear, radius: 6)
    }
    .padding(ringWidth / 2)
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
