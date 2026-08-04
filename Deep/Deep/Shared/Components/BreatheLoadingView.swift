import SwiftUI

/// Deep's full-screen loading beat: an opaque, calm scene with a centered
/// breathing line of serif text. Shown during whole-app waits — launch,
/// log-in, sign-up. Content-level waits use breathing skeletons instead.
struct BreatheLoadingView: View {
  var line: String = "Take a deep breath.\nWe're preparing your space."
  /// Set false where the host already keeps a persistent moonCream + atmosphere
  /// backdrop beneath this view (`AppRootView`), so only the breathing text
  /// renders — and a transition's veil blur can never touch the atmosphere's
  /// soft orbs. The host then owns the nothing-shows-through invariant.
  var drawsBackdrop = true
  /// Flip to true (inside `withAnimation`) to send the breathing line away: it
  /// drifts up, veils, and fades — the soft-drift language, drawn by hand.
  /// Hosts drive this *before* unmounting the view because SwiftUI skips exit
  /// transitions on subtrees with continuously self-updating content (the
  /// breath timeline here) — a removal would cut to nothing in a single frame.
  /// Once faded, the view can be removed without ceremony.
  var exhaled = false

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  /// Anchors the breath cycle so the text always wakes at its dimmed rest and
  /// rises, like a first inhale.
  @State private var breathBegan = Date()

  var body: some View {
    ZStack {
      if drawsBackdrop {
        // Opaque base under the atmosphere's translucent stops: nothing beneath
        // this screen may ever show through.
        Color.moonCream.ignoresSafeArea()
        AtmosphereBackground()
      }

      // The breath is sampled from a timeline and pauses during the exhale,
      // so the send-off animates over still content.
      TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || exhaled)) { context in
        Text(line)
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
          .multilineTextAlignment(.center)
          .padding(.horizontal, .edge * 2)
          .opacity(breathOpacity(at: context.date))
      }
      .opacity(exhaled ? 0 : 1)
      .offset(y: exhaled && !reduceMotion ? -SoftDrift.drop : 0)
      .blur(radius: exhaled && !reduceMotion ? SoftDrift.veil : 0)
    }
    .onAppear {
      AccessibilityNotification.Announcement(line).post()
    }
  }

  /// One breath, computed statelessly: rise over a half-cycle on the breath
  /// curve, settle back over the next — the same motion the animation token
  /// `.breath(over:)` would draw when autoreversed.
  private func breathOpacity(at date: Date) -> Double {
    guard !reduceMotion else { return 1.0 }
    let cycle = max(0, date.timeIntervalSince(breathBegan))
      .truncatingRemainder(dividingBy: Breath.halfCycle * 2)
    let fraction = cycle < Breath.halfCycle
      ? cycle / Breath.halfCycle
      : 2 - cycle / Breath.halfCycle
    return Breath.rest + (1.0 - Breath.rest) * UnitCurve.breath.value(at: fraction)
  }
}

/// The breath's single source of truth. Private — these values shape only
/// this screen's breathing line.
private enum Breath {
  /// Seconds per half-breath (rise, then settle) — the tempo the old
  /// `.breath(over: 5)` autoreversing animation kept.
  static let halfCycle: TimeInterval = 5
  /// The dimmed opacity the text rests at between breaths.
  static let rest: Double = 0.55
}

#Preview("Breathe loading") {
  BreatheLoadingView()
}

#Preview("Breathe loading — custom line") {
  BreatheLoadingView(line: "Almost there. Settle in.")
}

#Preview("Breathe loading — over host backdrop") {
  ZStack {
    Color.moonCream.ignoresSafeArea()
    AtmosphereBackground()
    BreatheLoadingView(drawsBackdrop: false)
  }
}

#Preview("Breathe loading — exhale") {
  @Previewable @State var exhaled = false

  ZStack {
    Color.moonCream.ignoresSafeArea()
    AtmosphereBackground()
    BreatheLoadingView(drawsBackdrop: false, exhaled: exhaled)

    VStack {
      Spacer()
      Button(exhaled ? "Breathe in" : "Exhale") {
        withAnimation(.exhale) { exhaled.toggle() }
      }
      .padding(.bottom, .rhythm)
    }
  }
}
