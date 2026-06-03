import SwiftUI

/// A draggable 0...1 track used for both the scrubber and the volume slider.
/// Matches Apple Music's behaviour: the track thickens while you drag and the
/// fill follows your finger. Timing is softened to fit Deep's motion.
struct SoundSlider: View {
  @Binding var value: Double
  var activeColor: Color = DeepColor.lavenderMist
  var trackHeight: CGFloat = 6
  var onEditingChanged: (Bool) -> Void = { _ in }

  @State private var isDragging = false

  var body: some View {
    GeometryReader { geo in
      let width = geo.size.width
      let clamped = min(1, max(0, value))

      ZStack(alignment: .leading) {
        Capsule()
          .fill(DeepColor.lavenderMist.opacity(0.22))
        Capsule()
          .fill(activeColor)
          .frame(width: clamped * width)
      }
      .frame(height: isDragging ? trackHeight + 4 : trackHeight)
      .frame(maxHeight: .infinity)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { gesture in
            if !isDragging {
              isDragging = true
              onEditingChanged(true)
            }
            value = min(1, max(0, gesture.location.x / width))
          }
          .onEnded { _ in
            isDragging = false
            onEditingChanged(false)
          }
      )
      .animation(DeepMotion.settle, value: isDragging)
    }
    .frame(height: 28)
  }
}

#Preview {
  struct Demo: View {
    @State private var v = 0.4
    var body: some View {
      SoundSlider(value: $v)
        .padding()
        .background(DeepColor.moonCream)
    }
  }
  return Demo()
}
