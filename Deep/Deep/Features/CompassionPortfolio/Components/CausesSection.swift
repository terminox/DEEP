import SwiftUI

/// The causes the community's hearts flow to, as a horizontal shelf. The
/// community-level reach figure now lives on `CommunityPoolCard` instead — if
/// it stayed here too, the identical sentence would appear twice within ~60pt
/// of scroll.
struct CausesSection: View {
  let categories: [CompassionCategory]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      SectionHeader(
        title: "Where your hearts go",
        subtitle: "Send them to a cause and we give, for real, on your behalf."
      )

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(categories) { CategoryTile(category: $0) }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, .edge)
        // The room each tile's bloom needs, given in full: `frostedCard`'s
        // shadow is `lavenderMist 0.18, radius 24, y 12`, so it reaches 12pt
        // above a card and 36pt below it. Anything less clips the plume off
        // square along the scroll's edge.
        //
        // Still deliberately no `.scrollClipDisabled()`: that doesn't give the
        // shadow room, it just lets it escape — the plume then rides over the
        // header and the next section, and drifts across both as you scroll.
        // Real space is the only honest way to show a shadow. (The shelf's
        // outer `VStack` spacing drops to 6 to pay for the top padding, and the
        // wider gap this leaves before "From the field" is the plume's, not
        // waste.) This is the only shelf in the app whose tiles carry
        // `frostedCard`, so it's the only one that needs this.
        .padding(.top, 14)
        .padding(.bottom, 38)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
  }
}

#Preview("Causes section") {
  ScrollView {
    CausesSection(categories: CompassionLibrary.categories)
      .padding(.vertical)
  }
  .background { AtmosphereBackground() }
  .environment(\.heartLedger, .sample)
  .environment(\.openDonation, { _ in })
}
