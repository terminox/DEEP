import SwiftUI

/// The causes the community's hearts flow to, stacked as tiles. The header
/// carries the honest community-level reach figure — a fact about the causes,
/// never dressed up as one member's impact.
struct CausesSection: View {
  let categories: [CompassionCategory]
  let peopleReached: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 3) {
        HomeSectionHeader(title: "Where your hearts go")
        Text("\(peopleReached.formatted(.number.notation(.compactName))) people reached across \(categories.count) causes")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .padding(.horizontal, .edge)
      }

      VStack(spacing: 12) {
        ForEach(categories) { category in
          CategoryTile(category: category)
        }
      }
      .padding(.horizontal, .edge)
    }
  }
}

#Preview("Causes section") {
  ScrollView {
    CausesSection(
      categories: CompassionLibrary.categories,
      peopleReached: HeartLedger.sample.peopleReached
    )
    .padding(.vertical)
  }
  .background { AtmosphereBackground() }
  .environment(\.openCategory, { _ in })
}
