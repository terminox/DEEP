import SwiftUI

/// A section title with an optional trailing "See all" affordance. Shared by the
/// home's carousels and stacked sections so headers read identically everywhere.
struct HomeSectionHeader: View {
  private let title: Text
  var seeAll: (() -> Void)? = nil

  /// For a literal title, which resolves through the String Catalog against the
  /// view's locale.
  init(title: LocalizedStringKey, seeAll: (() -> Void)? = nil) {
    self.title = Text(title)
    self.seeAll = seeAll
  }

  /// For a title that arrives already in the reading language — a shelf the
  /// server named. Labelled apart so a literal can never land here by
  /// overload resolution and skip the catalog.
  init(verbatim title: String, seeAll: (() -> Void)? = nil) {
    self.title = Text(verbatim: title)
    self.seeAll = seeAll
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      title
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
