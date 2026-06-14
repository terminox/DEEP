import SwiftUI

/// A section title with an optional trailing "See all" affordance. Shared by the
/// home's carousels and stacked sections so headers read identically everywhere.
struct HomeSectionHeader: View {
  let title: String
  var seeAll: (() -> Void)? = nil

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .font(DeepType.sectionTitle)
        .foregroundStyle(.deepPlum)

      Spacer(minLength: 12)

      if let seeAll {
        Button("See all", action: seeAll)
          .font(DeepType.caption.weight(.medium))
          .foregroundStyle(.lavenderMist)
          .buttonStyle(.softPress)
      }
    }
    .padding(.horizontal, .edge)
  }
}

#Preview("Section Header") {
  VStack(spacing: 24) {
    HomeSectionHeader(title: "Popular now", seeAll: {})
    HomeSectionHeader(title: "Explore")
  }
  .padding(.vertical)
  .background(.moonCream)
}
