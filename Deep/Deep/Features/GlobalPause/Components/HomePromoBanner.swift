import SwiftUI

/// A full-width frosted banner promoting the next Global Pause — the home's
/// equivalent of Calm's "Special Offer" row. Tapping it is a stubbed CTA.
struct HomePromoBanner: View {
  let banner: HomeBanner
  var action: () -> Void = {}

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Image(systemName: banner.systemImage)
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 48, height: 48)
          .background(
            LinearGradient(
              colors: [.lavenderMist, .blushPowder],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
          )

        VStack(alignment: .leading, spacing: 3) {
          Text(banner.title)
            .font(DeepType.body.weight(.semibold))
            .foregroundStyle(.deepPlum)
          Text(banner.message)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .lineLimit(2)
        }

        Spacer(minLength: 8)

        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.driftGrey)
      }
      .padding(16)
      .frostedCard()
    }
    .buttonStyle(.softPress)
    .padding(.horizontal, .edge)
    .accessibilityHint("Opens the next Global Pause")
  }
}

#Preview("Promo Banner") {
  ZStack {
    AtmosphereBackground()
    HomePromoBanner(banner: HomeLibrary.banner)
  }
}
