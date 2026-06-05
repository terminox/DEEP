import SwiftUI

/// The "Grow your garden" row — a horizontal shelf of growth-stage tiles that
/// shows the journey from the first seedling to the stages still ahead.
struct GrowYourGardenSection: View {
  let stages: [GardenStage]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Grow your garden")
        .font(DeepType.sectionTitle)
        .foregroundStyle(DeepColor.deepPlum)
        .padding(.horizontal, DeepSpacing.edge)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(stages) { stage in
            PlantStageTile(stage: stage)
          }
        }
        .padding(.horizontal, DeepSpacing.edge)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
  }
}

#Preview("Grow your garden") {
  ZStack {
    AtmosphereBackground()
    GrowYourGardenSection(stages: GardenStage.journey)
  }
}
