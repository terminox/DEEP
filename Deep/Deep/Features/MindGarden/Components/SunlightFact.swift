import SwiftUI

/// The garden's sunlight fact: the sun that introduces a sunlight figure, glyph
/// and figure sharing `GardenColor.sunbeam` so the pair reads as one mark.
///
/// Only the figure takes the tint — the words around it stay grey, which keeps
/// the colour to a mark rather than a wash. Green stays the plant's own colour,
/// kept for the halo; the gold belongs to what fills it.
struct SunlightFact<Label: View>: View {
  private let label: Label

  init(@ViewBuilder label: () -> Label) {
    self.label = label()
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 5) {
      Image(systemName: "sun.max.fill")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(GardenColor.sunbeam)
      label
    }
  }
}

#Preview("Sunlight fact") {
  ZStack {
    AtmosphereBackground()
    VStack(alignment: .leading, spacing: 14) {
      // The growth card's reading: how far the next form is.
      SunlightFact {
        Text("240")
          .font(DeepType.caption.weight(.semibold))
          .foregroundStyle(GardenColor.sunbeam)
          + Text("/700 to Mature Oak")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
      }

      // The picker's reading: what this plant has banked, full stop.
      SunlightFact {
        Text("480")
          .font(DeepType.caption.weight(.semibold))
          .foregroundStyle(GardenColor.sunbeam)
          .monospacedDigit()
      }
    }
    .padding(20)
    .frostedCard()
    .padding(.edge)
  }
}
