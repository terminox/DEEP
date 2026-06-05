import SwiftUI

/// A single growth-stage tile in the "Grow your garden" row. Unlocked stages
/// show their plant in full colour; future stages are dimmed and locked with the
/// day they bloom.
struct PlantStageTile: View {
  let stage: GardenStage
  var size: CGFloat = 132

  var body: some View {
    VStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: DeepRadius.tile, style: .continuous)
          .fill(LinearGradient(
            colors: stage.tint,
            startPoint: .topLeading, endPoint: .bottomTrailing
          ))
          .overlay(
            // Clip the sheen to the rounded shape — an unclipped RadialGradient
            // would paint its bright top-leading corner into the square corner
            // beyond the rounded arc.
            RoundedRectangle(cornerRadius: DeepRadius.tile, style: .continuous)
              .fill(RadialGradient(
                colors: [.white.opacity(0.4), .clear],
                center: .topLeading, startRadius: 2, endRadius: size
              ))
          )
          .overlay(
            RoundedRectangle(cornerRadius: DeepRadius.tile, style: .continuous)
              .strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
          )

        PlantArtwork(kind: stage.kind)
          .padding(size * 0.14)
          .opacity(stage.isUnlocked ? 1 : 0.45)
          .grayscale(stage.isUnlocked ? 0 : 0.55)

        if !stage.isUnlocked {
          Image(systemName: "lock.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DeepColor.deepPlum.opacity(0.5))
            .frame(width: 30, height: 30)
            .background(.white.opacity(0.7), in: Circle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(10)
        }
      }
      .frame(width: size, height: size)
      .shadow(color: DeepColor.lavenderMist.opacity(0.18), radius: 14, x: 0, y: 8)

      VStack(spacing: 2) {
        Text(stage.name)
          .font(DeepType.sectionTitle)
          .foregroundStyle(DeepColor.deepPlum)
        Text(stage.isUnlocked ? "Growing" : "Day \(stage.dayThreshold)")
          .font(DeepType.caption)
          .foregroundStyle(DeepColor.driftGrey)
      }
    }
    .frame(width: size)
  }
}

#Preview("Plant tiles") {
  ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 16) {
      ForEach(GardenStage.journey) { PlantStageTile(stage: $0) }
    }
    .padding()
  }
  .background(DeepColor.moonCream)
}
