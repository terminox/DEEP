import SwiftUI

/// The "from the field" feed — recent real-world outcomes reported back to the
/// app, so members see what their hearts set in motion.
struct FieldReportsSection: View {
  let reports: [FieldReport]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HomeSectionHeader(title: "From the field")

      VStack(spacing: 12) {
        ForEach(reports) { report in
          FieldReportCard(report: report)
        }
      }
      .padding(.horizontal, .edge)
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
