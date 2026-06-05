import SwiftUI

/// A gentle "coming soon" screen for features that aren't built yet. Keeps the
/// Deep atmosphere so an empty tab still feels like part of the app.
struct FeaturePlaceholderView: View {
  let title: String
  let message: String
  let systemImage: String

  var body: some View {
    ZStack {
      AtmosphereBackground()

      VStack(spacing: 20) {
        Image(systemName: systemImage)
          .font(.system(size: 34, weight: .light))
          .foregroundStyle(.lavenderMist)
          .frame(width: 96, height: 96)
          .background(
            Circle()
              .fill(.white.opacity(0.5))
              .background(Circle().fill(.ultraThinMaterial))
          )
          .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
          .shadow(color: Color.lavenderMist.opacity(0.25), radius: 20, x: 0, y: 10)

        VStack(spacing: 8) {
          Text(title)
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
          Text(message)
            .font(DeepType.body)
            .foregroundStyle(.driftGrey)
            .multilineTextAlignment(.center)
        }

        Text("Coming soon")
          .font(DeepType.micro)
          .tracking(1.4)
          .foregroundStyle(.lavenderMist)
          .padding(.horizontal, 16)
          .padding(.vertical, 7)
          .background(Capsule().fill(.white.opacity(0.45)))
      }
      .padding(.horizontal, 40)
    }
    .preferredColorScheme(.light)
  }
}

#Preview {
  FeaturePlaceholderView(
    title: "Mind Garden",
    message: "A quiet place to tend to your thoughts as they grow.",
    systemImage: "leaf.fill"
  )
}
