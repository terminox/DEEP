import SwiftUI

/// The garden's opening card — a time-of-day greeting with the day's line of
/// encouragement, then the oak's evolution: where it stands now, what it grows
/// into next, and the meter of growth points connecting the two.
struct GardenGrowthCard: View {
  let greeting: GardenGreeting
  let growth: GardenGrowth

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 5) {
        Text(greeting.salutation)
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
        Text(greeting.quote)
          .font(DeepType.body)
          .foregroundStyle(.driftGrey)
          .fixedSize(horizontal: false, vertical: true)
      }

      VStack(alignment: .leading, spacing: 10) {
        evolutionRow
        Text(pointsCaption)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .monospacedDigit()
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(evolutionSummary)
    }
    .padding(20)
    .frostedCard()
  }

  private var evolutionRow: some View {
    HStack(alignment: .top, spacing: 12) {
      OakStageThumb(stage: growth.stage)
      GardenMeterBar(
        progress: growth.evolutionProgress,
        fill: [GardenColor.meadow, GardenColor.sage]
      )
      .frame(maxWidth: .infinity)
      .padding(.top, 35)
      if let next = growth.nextStage {
        OakStageThumb(stage: next, isVeiled: true)
      } else {
        fullyGrownBadge
          .padding(.top, 23)
      }
    }
  }

  private var fullyGrownBadge: some View {
    Image(systemName: "sparkles")
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(GardenColor.fern)
      .frame(width: 30, height: 30)
      .background(.white.opacity(0.6), in: Circle())
  }

  private var pointsCaption: String {
    if let next = growth.nextStage, let goal = growth.pointsToEvolve {
      "\(growth.points) / \(goal) · grows into \(next.displayName)"
    } else {
      "Fully grown · your oak stands tall"
    }
  }

  private var evolutionSummary: String {
    if let next = growth.nextStage, let goal = growth.pointsToEvolve {
      "\(growth.stage.displayName), \(growth.points) of \(goal) points toward \(next.displayName)"
    } else {
      "\(growth.stage.displayName), fully grown"
    }
  }
}

/// A small framed tile of one oak form. The artwork ships on an opaque white
/// square, so it always sits in a rounded frame with a faint lavender veil that
/// settles it into the frosted card. The next, not-yet-reached form is veiled a
/// touch further.
private struct OakStageThumb: View {
  let stage: OakStage
  var isVeiled = false

  private let size: CGFloat = 76

  var body: some View {
    VStack(spacing: 8) {
      Image(stage.imageName)
        .resizable()
        .scaledToFit()
        .padding(6)
        .frame(width: size, height: size)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.lavenderMist.opacity(0.08))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
        )
        .opacity(isVeiled ? 0.72 : 1)
        .grayscale(isVeiled ? 0.3 : 0)
      Text(stage.displayName)
        .font(DeepType.caption)
        .foregroundStyle(isVeiled ? Color.driftGrey : Color.deepPlum)
        .multilineTextAlignment(.center)
    }
    .frame(width: size)
  }
}

#Preview("Growth — sample") {
  ZStack {
    AtmosphereBackground()
    GardenGrowthCard(greeting: .sample, growth: .sample)
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
