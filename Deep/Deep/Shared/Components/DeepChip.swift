import SwiftUI

/// A selectable word — the app's one chip. Unselected it is a soft white
/// capsule on the atmosphere; selected it fills with the lavender→blush
/// gradient and lifts on its own bloom.
///
/// One implementation on purpose: the reflection's intention row and the
/// mood row used to be two copies of this, and had already drifted apart
/// (one carried the selected shadow, the other had lost it).
struct DeepChip: View {
  let label: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(DeepType.body.weight(isSelected ? .medium : .regular))
        .foregroundStyle(isSelected ? .white : Color.deepPlum.opacity(0.85))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
          Capsule().fill(
            isSelected
              ? AnyShapeStyle(
                LinearGradient(
                  colors: [.lavenderMist, .blushPowder],
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              : AnyShapeStyle(Color.white.opacity(0.75))
          )
        )
        .overlay(
          Capsule()
            .strokeBorder(.white.opacity(isSelected ? 0 : 0.6), lineWidth: 0.5)
        )
        .shadow(
          color: isSelected ? Color.lavenderMist.opacity(0.32) : .clear,
          radius: 10, x: 0, y: 4
        )
    }
    .buttonStyle(.softPress)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

/// The same word at rest — how a chosen tag reads once it is no longer a
/// control, on a peace-message card in the feed.
struct DeepTagLabel: View {
  let label: String

  var body: some View {
    Text(label)
      .font(DeepType.micro)
      .foregroundStyle(Color.deepPlum.opacity(0.6))
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(Capsule().fill(.white.opacity(0.6)))
      .overlay(Capsule().strokeBorder(.white.opacity(0.7), lineWidth: 0.5))
  }
}

#Preview("Chips") {
  @Previewable @State var selected: String? = "Healing"

  ZStack {
    AtmosphereBackground()
    VStack(spacing: .rhythm) {
      FlowLayout(spacing: 8, runSpacing: 8) {
        ForEach(["Peace", "Healing", "Gratitude", "Someone I love", "Other"], id: \.self) { label in
          DeepChip(label: label, isSelected: selected == label) {
            withAnimation(.settle) { selected = (selected == label) ? nil : label }
          }
        }
      }
      DeepTagLabel(label: "Gratitude")
    }
    .padding(.edge)
  }
}
