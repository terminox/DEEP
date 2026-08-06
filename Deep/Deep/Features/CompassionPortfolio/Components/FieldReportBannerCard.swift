import SwiftUI

/// One dispatch from the field — a real-world outcome made possible by hearts.
/// Given the shape of a dispatch rather than another list row: the cause's motif
/// runs as a banner across the top with the cause named over it, and the report
/// reads beneath. Closes the loop so giving feels tangible: a place, a date, a
/// result.
struct FieldReportBannerCard: View {
  let report: FieldReport

  var width: CGFloat = 264
  private let bannerHeight: CGFloat = 116

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      banner

      VStack(alignment: .leading, spacing: 6) {
        Text(report.title)
          .font(DeepType.body.weight(.semibold))
          .foregroundStyle(.deepPlum)
          .fixedSize(horizontal: false, vertical: true)
        Text(report.blurb)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .fixedSize(horizontal: false, vertical: true)

        // Place at one end, time at the other — separated by the gap between
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
        .foregroundStyle(.driftGrey.opacity(0.85))
        .padding(.top, 2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
    }
    .frame(width: width)
    .frostedCard()
    .accessibilityElement(children: .combine)
  }

  /// The cause's artwork, wearing the app's standard over-media recipe so white
  /// type stays legible without a hard edge anywhere.
  private var banner: some View {
    let shape = UnevenRoundedRectangle(
      topLeadingRadius: .card,
      bottomLeadingRadius: 0,
      bottomTrailingRadius: 0,
      topTrailingRadius: .card,
      style: .continuous
    )
    return CompassionMotif(
      symbol: report.symbol,
      palette: report.palette,
      cornerRadius: 0,
      symbolScale: 0.5,
      symbolOpacity: 0.34,
      symbolBlur: 1,
      symbolAlignment: .trailing,
      bordered: false
    )
    .frame(height: bannerHeight)
    .overlay(alignment: .bottom) {
      VariableBlurView(maxBlurRadius: 4, direction: .blurredBottomClearTop)
        .frame(height: 56)
    }
    .overlay {
      LinearGradient(
        colors: [.clear, Color.deepPlum.opacity(0.32)],
        startPoint: .center,
        endPoint: .bottom
      )
    }
    .overlay(alignment: .bottomLeading) {
      Text(report.categoryName.uppercased())
        .font(DeepType.micro)
        .tracking(1.4)
        .foregroundStyle(.white)
        .shadow(color: Color.deepPlum.opacity(0.3), radius: 6, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    .clipShape(shape)
  }
}

#Preview("Field report banner") {
  ZStack {
    AtmosphereBackground()
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(alignment: .top, spacing: 16) {
        ForEach(CompassionLibrary.reports) { report in
          FieldReportBannerCard(report: report)
        }
      }
      .padding(.edge)
    }
  }
}
