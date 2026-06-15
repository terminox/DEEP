import SwiftUI

/// One dispatch from the field — a real-world outcome made possible by hearts.
/// Closes the loop so giving feels tangible: a place, a date, a result.
struct FieldReportCard: View {
  let report: FieldReport

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      CompassionMotif(symbol: report.symbol, palette: report.palette, cornerRadius: 14)
        .frame(width: 52, height: 52)

      VStack(alignment: .leading, spacing: 4) {
        Text(report.categoryName.uppercased())
          .font(DeepType.micro)
          .tracking(1.2)
          .foregroundStyle(.lavenderMist)
        Text(report.title)
          .font(DeepType.body.weight(.semibold))
          .foregroundStyle(.deepPlum)
          .fixedSize(horizontal: false, vertical: true)
        Text(report.blurb)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 6) {
          Image(systemName: "mappin.and.ellipse")
          Text(report.location)
          Text("·")
          Text(report.date, format: .relative(presentation: .named))
        }
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey.opacity(0.85))
      }
    }
    .padding(16)
    .frostedCard()
    .accessibilityElement(children: .combine)
  }
}

#Preview("Field report card") {
  ZStack {
    AtmosphereBackground()
    FieldReportCard(report: CompassionLibrary.reports[0])
      .padding(.edge)
  }
}
