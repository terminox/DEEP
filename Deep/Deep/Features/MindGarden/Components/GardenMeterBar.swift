import SwiftUI

/// A slim capsule meter shared by the garden's cards — evolution progress and
/// today's minutes both read through it. Fills with the signature slow
/// `.exhale` motion. Silent to VoiceOver: the row that hosts it owns the story.
struct GardenMeterBar: View {
  /// 0...1 fraction complete.
  let progress: Double
  /// Leading→trailing gradient for the filled portion.
  var fill: [Color] = [.lavenderMist, .blushPowder]

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule(style: .continuous)
          .fill(.lavenderMist.opacity(0.18))
        Capsule(style: .continuous)
          .fill(LinearGradient(colors: fill, startPoint: .leading, endPoint: .trailing))
          .frame(width: max(0, min(1, progress)) * geo.size.width)
      }
    }
    .frame(height: 6)
    .animation(.exhale, value: progress)
    .accessibilityHidden(true)
  }
}

#Preview("Garden meter") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: .rhythm) {
      GardenMeterBar(progress: 0)
      GardenMeterBar(progress: 0.48, fill: [GardenColor.meadow, GardenColor.sage])
      GardenMeterBar(progress: 1)
    }
    .padding(.horizontal, .edge)
  }
}
