import SwiftUI

/// One dispatch from the field, as a full-width list row — something that came
/// *back* from a cause the member already gave to, not something to go into.
/// Non-interactive: no button, no chevron, nothing waits behind a report.
struct FieldReportRow: View {
  let report: FieldReport

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      CompassionMotif(symbol: report.symbol, palette: report.palette)
        .frame(width: 60, height: 60)

      VStack(alignment: .leading, spacing: 4) {
        Text(report.categoryName.uppercased())
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)

        Text(report.title)
          .font(DeepType.body.weight(.semibold))
          .foregroundStyle(.deepPlum)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)

        Text(report.blurb)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)

        // Place at one end, time at the other — held apart by the gap between
        // them rather than by a mark.
        HStack(spacing: 8) {
          Label(report.location, systemImage: "mappin.and.ellipse")
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
          Spacer(minLength: 8)
          Text(report.date, format: .relative(presentation: .named))
            .lineLimit(1)
        }
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .padding(.top, 3)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(14)
    // Plain, untinted card: `.frostedCard(tint:)`'s warmth is a
    // `RadialGradient` centred at the leading edge, which reads as an even
    // wash on a ~210pt carousel card but concentrates entirely under this
    // row's 60pt motif thumb at full width, leaving the trailing half plain.
    // The thumb already carries the cause's colour; a second tinted surface
    // here would also repeat palettes already worn by the causes above.
    .frostedCard()
    .accessibilityElement(children: .combine)
  }
}

#Preview("Field reports") {
  ScrollView {
    VStack(spacing: 12) {
      ForEach(CompassionLibrary.reports) { report in
        FieldReportRow(report: report)
      }
    }
    .padding(.edge)
  }
  .background { AtmosphereBackground() }
}
