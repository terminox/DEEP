import SwiftUI

/// Where the world is pausing, named beneath the globe.
///
/// One row, west to east, each continent a count over its name. There is no
/// glyph, no panel and no rule: on this screen the numbers *are* the lights,
/// and anything drawn around them would be the loudest thing in the room.
///
/// The order is fixed, never ranked — the row is a map, not a leaderboard, and
/// columns that reorder while someone is meditating are movement for nothing.
/// Only the count ever changes in place.
///
/// Columns take their natural width (`layoutPriority`) and the space left over
/// is shared out between them, so "AMERICAS" never has to fight an equal-fifths
/// grid, and a two-continent early session centres itself instead of stretching
/// to the margins.
struct ContinentLights: View {
  let presences: [ContinentPresence]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      ForEach(presences) { presence in
        Spacer(minLength: 8)
        column(for: presence)
      }
      Spacer(minLength: 8)
    }
    .animation(.exhale, value: presences)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  private func column(for presence: ContinentPresence) -> some View {
    VStack(spacing: 3) {
      Text(presence.count.formatted())
        .font(DeepType.caption)
        // Dimmer than the headline count above the globe — this row answers
        // a question the headline has already asked.
        .foregroundStyle(.moonCream.opacity(0.62))
        .monospacedDigit()
        .contentTransition(.numericText(value: Double(presence.count)))

      Text(presence.continent.name.uppercased())
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.moonCream.opacity(0.38))
    }
    .lineLimit(1)
    .minimumScaleFactor(0.75)
    .layoutPriority(1)
    // In on a bloom, out on an exhale — the same asymmetry the globe's
    // country reveal uses. Reduce Motion keeps the fade, drops the swell.
    .transition(
      .asymmetric(
        insertion: reduceMotion
          ? .opacity.animation(.bloom)
          : .opacity.combined(with: .scale(scale: 0.92)).animation(.bloom),
        removal: .opacity.animation(.exhale)
      )
    )
  }

  private var accessibilityLabel: String {
    guard !presences.isEmpty else { return "" }
    let places = presences
      .map { "\($0.count.formatted()) in \($0.continent.spokenName)" }
      .formatted(.list(type: .and))
    return "Pausing now: \(places)"
  }
}

#Preview("The world") {
  ZStack {
    // The row only ever ships over the session's night sky.
    NightSkyBackground(tuning: NightSkyTuning())
      .ignoresSafeArea()
    ContinentLights(
      presences: ContinentPresence.row(
        from: ["AS": 1842, "EU": 1106, "NA": 604, "SA": 199, "AF": 291, "OC": 176]
      )
    )
    .padding(.horizontal, 12)
  }
}

#Preview("Early — two continents lit") {
  ZStack {
    NightSkyBackground(tuning: NightSkyTuning())
      .ignoresSafeArea()
    ContinentLights(presences: ContinentPresence.row(from: ["AS": 12, "EU": 3]))
      .padding(.horizontal, 12)
  }
}

#Preview("A continent lights up") {
  @Previewable @State var tally = ["AS": 1842, "EU": 1106]

  ZStack {
    NightSkyBackground(tuning: NightSkyTuning())
      .ignoresSafeArea()
    ContinentLights(presences: ContinentPresence.row(from: tally))
      .padding(.horizontal, 12)
  }
  // Stands in for a poll landing the first arrival from somewhere new.
  .task {
    try? await Task.sleep(for: .seconds(1.5))
    tally["AF"] = 1
    try? await Task.sleep(for: .seconds(1.5))
    tally["NA"] = 604
    tally["AS"] = 1_868
  }
}
