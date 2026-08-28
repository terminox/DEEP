import SwiftUI

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
    // Report the PROPOSED width (when there is one), not the longest row's:
    // otherwise placement runs in a narrower box than sizing measured and
    // wraps one row more than was counted — the extra row then overflows
    // onto whatever sits below.
    return CGSize(width: proposal.width ?? max(0, width), height: y + rowHeight)
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

#Preview("Flow layout") {
  FlowLayout(spacing: 8, runSpacing: 8) {
    ForEach(["Peace", "Healing", "Gratitude", "Someone I love", "Other"], id: \.self) { label in
      Text(label)
        .font(DeepType.body)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(.white.opacity(0.75)))
    }
  }
  .padding(.edge)
  .background(.moonCream)
}
