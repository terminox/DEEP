import SwiftUI

/// The real-world organisation a cause's donations flow to. Names who does the
/// work and where, so the promise behind a heart is concrete.
struct PartnerOrganizationCard: View {
  let partner: CompassionPartner

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("PARTNER ORGANISATION")
        .font(DeepType.micro)
        .tracking(1.4)
        .foregroundStyle(.lavenderMist)

      HStack(alignment: .top, spacing: 14) {
        Image(systemName: partner.symbol)
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 52, height: 52)
          .background(
            LinearGradient(colors: [.lavenderMist, .blushPowder], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
          )

        VStack(alignment: .leading, spacing: 4) {
          Text(partner.name)
            .font(DeepType.sectionTitle)
            .foregroundStyle(.deepPlum)
          Text(partner.blurb)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      HStack(spacing: 8) {
        metaChip(symbol: "globe", text: partner.scope)
        metaChip(symbol: "calendar", text: "Since \(String(partner.since))")
        Spacer(minLength: 0)
      }

      website
    }
    .padding(18)
    .frostedCard()
  }

  /// Styled as a link, so it has to behave as one.
  @ViewBuilder
  private var website: some View {
    let label = HStack(spacing: 6) {
      Image(systemName: "link")
        .font(.system(size: 10, weight: .semibold))
      Text(partner.website)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .font(DeepType.caption.weight(.medium))
    .foregroundStyle(.lavenderMist)

    if let url = URL(string: "https://\(partner.website)") {
      Link(destination: url) { label }
        .buttonStyle(.softPress)
        .accessibilityLabel("Visit \(partner.name)")
        .accessibilityHint(partner.website)
    } else {
      label
    }
  }

  private func metaChip(symbol: String, text: String) -> some View {
    HStack(spacing: 5) {
      Image(systemName: symbol)
        .font(.system(size: 10, weight: .semibold))
      Text(text)
        .lineLimit(1)
    }
    .fixedSize()
    .font(DeepType.caption.weight(.medium))
    .foregroundStyle(.driftGrey)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(.lavenderMist.opacity(0.12), in: Capsule())
  }
}

#Preview("Partner organisation card") {
  ZStack {
    AtmosphereBackground()
    PartnerOrganizationCard(partner: CompassionLibrary.healthcare.partner)
      .padding(.edge)
  }
}
