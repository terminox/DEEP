import SwiftUI

/// The "from the field" feed — recent real-world outcomes reported back to the
/// app, so members see what their hearts set in motion. Unlike the causes
/// carousel above it, this is a chronology read top to bottom rather than a
/// shelf of parallel choices, so each dispatch gets its own full-width row.
struct FieldReportsSection: View {
  let reports: [FieldReport]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "From the field")

      VStack(spacing: 12) {
        ForEach(reports) { report in
          FieldReportRow(report: report)
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
