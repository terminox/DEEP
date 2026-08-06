import SwiftUI

/// The "from the field" feed — recent real-world outcomes reported back to the
/// app, so members see what their hearts set in motion. Runs horizontally, like
/// the app's other shelves, so the dispatches read as their own kind of content
/// rather than a fourth stack of rows.
struct FieldReportsSection: View {
  let reports: [FieldReport]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HomeSectionHeader(title: "From the field")

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(reports) { report in
            FieldReportBannerCard(report: report)
          }
        }
        .padding(.horizontal, .edge)
      }
    }
  }
}

#Preview("Field reports section") {
  ScrollView {
    FieldReportsSection(reports: CompassionLibrary.reports)
      .padding(.vertical)
  }
  .background { AtmosphereBackground() }
}
