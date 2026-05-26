import SwiftUI

struct IntentionPicker: View {
  let intentions: [Intention]
  @Binding var selection: Intention.ID?

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(
        title: "Set your intention",
        subtitle: "What would you like to pause for?"
      )

      FlowLayout(spacing: 8, runSpacing: 8) {
        ForEach(intentions) { intention in
          Chip(
            label: intention.label,
            isSelected: selection == intention.id
          ) {
            withAnimation(DeepMotion.settle) {
              selection = (selection == intention.id) ? nil : intention.id
            }
          }
        }
      }
      .padding(.horizontal, DeepSpacing.edge)
    }
  }
}

private struct Chip: View {
  let label: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(DeepType.body.weight(isSelected ? .medium : .regular))
        .foregroundStyle(isSelected ? .white : DeepColor.deepPlum.opacity(0.85))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
          Capsule().fill(
            isSelected
            ? AnyShapeStyle(
              LinearGradient(
                colors: [DeepColor.lavenderMist, DeepColor.blushPowder],
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
          color: isSelected ? DeepColor.lavenderMist.opacity(0.32) : .clear,
          radius: 10, x: 0, y: 4
        )
    }
    .buttonStyle(.softPress)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

/// Simple flow layout for wrapping chips across lines.
struct FlowLayout: Layout {
  var spacing: CGFloat = 8
  var runSpacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var width: CGFloat = 0
    for sub in subviews {
      let size = sub.sizeThatFits(.unspecified)
      if x + size.width > maxWidth {
        width = max(width, x - spacing)
        x = 0
        y += rowHeight + runSpacing
        rowHeight = 0
      }
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
    width = max(width, x - spacing)
    return CGSize(width: max(0, width), height: y + rowHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var x = bounds.minX
    var y = bounds.minY
    var rowHeight: CGFloat = 0
    for sub in subviews {
      let size = sub.sizeThatFits(.unspecified)
      if x + size.width > bounds.maxX {
        x = bounds.minX
        y += rowHeight + runSpacing
        rowHeight = 0
      }
      sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}

#Preview {
  IntentionPickerPreview()
}

private struct IntentionPickerPreview: View {
  @State private var selected: Intention.ID? = Intention.samples.first?.id
  var body: some View {
    IntentionPicker(intentions: Intention.samples, selection: $selected)
      .padding(.vertical)
      .background(DeepColor.moonCream)
  }
}
