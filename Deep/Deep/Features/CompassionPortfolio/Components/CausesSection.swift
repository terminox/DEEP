import SwiftUI

/// The list of causes a user can send hearts to. The header reuses the shared
/// `HomeSectionHeader` so it reads identically to sections elsewhere in the app.
struct CausesSection: View {
  let categories: [CompassionCategory]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HomeSectionHeader(title: "Where your hearts go")

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
    CausesSection(categories: CompassionLibrary.categories)
      .padding(.vertical)
  }
  .background { AtmosphereBackground() }
  .environment(\.openCategory, { _ in })
}
