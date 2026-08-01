import SwiftUI

/// Deep's full-screen loading beat: an opaque, calm scene with a centered
/// breathing line of serif text. Shown during whole-app waits — launch,
/// log-in, sign-up. Content-level waits use breathing skeletons instead.
struct BreatheLoadingView: View {
  var line: String = "Breathe calmly.\nWe're preparing your space."

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var breathing = false

  var body: some View {
    ZStack {
      // Opaque base under the atmosphere's translucent stops: nothing beneath
      // this screen may ever show through.
      Color.moonCream.ignoresSafeArea()
      AtmosphereBackground()

      Text(line)
        .font(DeepType.displayTitle)
        .foregroundStyle(.deepPlum)
        .multilineTextAlignment(.center)
        .padding(.horizontal, .edge * 2)
        .opacity(reduceMotion ? 1.0 : (breathing ? 1.0 : 0.55))
    }
    .onAppear {
      AccessibilityNotification.Announcement(line).post()
      guard !reduceMotion else { return }
      withAnimation(.breath(over: 5).repeatForever(autoreverses: true)) {
        breathing = true
      }
    }
  }
}

#Preview("Breathe loading") {
  BreatheLoadingView()
}

#Preview("Breathe loading — custom line") {
  BreatheLoadingView(line: "Almost there. Settle in.")
}
