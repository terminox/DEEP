import SwiftUI

/// The little live badge for Fuku's Lounge — a softly pulsing dot beside
/// "ON AIR" in the `FeatureCard` duration-pill recipe. The pulse breathes on
/// the `.exhale` curve and holds still under Reduce Motion.
///
/// Given an `onTap` it becomes the lounge's mute control: the badge is already
/// the thing that means "Fuku is playing", so tapping it to stop the sound
/// needs no chrome of its own. Silenced, the dot dims and stops breathing —
/// the set is still on air, you are simply not listening to it. Without an
/// `onTap` it stays a plain, non-interactive badge, which is what
/// `DJFukuLoungeCard` needs: that whole card is already a button.
struct OnAirPill: View {
  var isMuted = false
  var onTap: (() -> Void)? = nil

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var dotDimmed = false

  var body: some View {
    if let onTap {
      Button(action: onTap) { pill }
        .buttonStyle(.plain)
        .accessibilityLabel(isMuted ? "On air, muted" : "On air")
        .accessibilityHint(isMuted ? "Unmutes Fuku's set" : "Mutes Fuku's set")
    } else {
      pill.accessibilityLabel("On air")
    }
  }

  private var pill: some View {
    HStack(spacing: 4) {
      Circle()
        .fill(.blushPowder)
        .frame(width: 6, height: 6)
        .opacity(isMuted ? 0.25 : (dotDimmed ? 0.4 : 1))
        .accessibilityHidden(true)

      Text("ON AIR")
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.deepPlum)
        .opacity(isMuted ? 0.5 : 1)

      if isMuted {
        Image(systemName: "speaker.slash.fill")
          .font(.system(size: 8, weight: .semibold))
          .foregroundStyle(.deepPlum.opacity(0.5))
          .accessibilityHidden(true)
      }
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 5)
    .background(.white.opacity(0.5), in: Capsule())
    .animation(.exhale, value: isMuted)
    .onAppear { breathe() }
    .onChange(of: isMuted) { _, _ in breathe() }
  }

  /// The dot only breathes while the set is audible; silenced, it holds still
  /// so the badge reads as dormant at a glance.
  private func breathe() {
    guard !reduceMotion, !isMuted else {
      withAnimation(.exhale) { dotDimmed = false }
      return
    }
    withAnimation(.exhale.repeatForever(autoreverses: true)) {
      dotDimmed = true
    }
  }
}

#Preview("On air pill") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: .rhythm) {
      OnAirPill()
      OnAirPill(onTap: {})
      OnAirPill(isMuted: true, onTap: {})
    }
  }
}
