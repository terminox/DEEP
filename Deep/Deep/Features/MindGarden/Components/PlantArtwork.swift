import SwiftUI

/// A generated plant illustration for a garden growth stage.
struct PlantArtwork: View {
  let kind: PlantKind

  var body: some View {
    Image(kind.assetName)
      .resizable()
      .scaledToFit()
  }
}

private extension PlantKind {
  var assetName: String {
    switch self {
    case .seedling: return "MindGardenPlantSeedling"
    case .sprout: return "MindGardenPlantSprout"
    case .bloom: return "MindGardenPlantBloom"
    case .tree: return "MindGardenPlantTree"
    }
  }
}

#Preview("Plant stages") {
  HStack(spacing: 12) {
    ForEach(PlantKind.allCases, id: \.self) { kind in
      PlantArtwork(kind: kind)
        .frame(width: 80, height: 100)
        .background(DeepColor.moonCream, in: RoundedRectangle(cornerRadius: 16))
    }
  }
  .padding()
  .background(DeepColor.softLilac.opacity(0.3))
}
