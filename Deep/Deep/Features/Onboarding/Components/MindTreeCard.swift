import SwiftUI

/// One selectable Mind Tree tile: the tree's artwork over its branded
/// gradient, name and tagline beneath, and a selection mark that blooms in
/// when chosen. Speaks the same selection language as `QuizOptionCard`,
/// re-shaped for a grid.
struct MindTreeCard: View {
  let tree: MindTree
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 10) {
        ArtworkImage(url: tree.imageURL, colors: tree.palette.colors, cornerRadius: .tile)
          .aspectRatio(1.2, contentMode: .fit)

        VStack(spacing: 2) {
          Text(tree.name)
            .font(DeepType.body)
            .foregroundStyle(.deepPlum)
          Text(tree.tagline)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
        }
        .padding(.bottom, 6)
        .multilineTextAlignment(.center)
      }
      .padding(10)
      .frame(maxWidth: .infinity)
      .frostedCard(cornerRadius: .card)
      .overlay(
        RoundedRectangle(cornerRadius: .card, style: .continuous)
          .strokeBorder(.lavenderMist, lineWidth: isSelected ? 1.5 : 0)
      )
      .overlay(alignment: .topTrailing) { selectionMark }
      .contentShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
    }
    .buttonStyle(.softPress)
    .animation(.settle, value: isSelected)
    .accessibilityLabel("\(tree.name), \(tree.tagline)")
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }

  @ViewBuilder
  private var selectionMark: some View {
    if isSelected {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 22))
        .foregroundStyle(.lavenderMist)
        .background(Circle().fill(.white).padding(2))
        .padding(16)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }
  }
}

#Preview("Mind Tree cards") {
  ZStack {
    AtmosphereBackground()
    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
      MindTreeCard(
        tree: MindTree(id: "oak", name: "Oak", tagline: "Steady & Strong", imageURL: nil, palette: .tide),
        isSelected: true,
        action: {}
      )
      MindTreeCard(
        tree: MindTree(id: "sakura", name: "Sakura", tagline: "Gentle & Open", imageURL: nil, palette: .bloom),
        isSelected: false,
        action: {}
      )
    }
    .padding(.horizontal, .edge)
  }
}
