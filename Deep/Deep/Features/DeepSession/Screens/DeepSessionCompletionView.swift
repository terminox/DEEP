import SwiftUI

/// The gentle beat after a finished Deep Session — what softly grew from the
/// practice: minutes into the garden, a heart earned. Growth reflected back,
/// never a score; no streaks, no goals, no numbers to chase.
///
/// Leaf screen, so it owns its screen-level styling (per the coordinator
/// rules). Third and final stage of the presented flow, arrived at on its own
/// once the engine finishes; Return dismisses it.
struct DeepSessionCompletionView: View {
  let session: DeepSession
  var onReturn: () -> Void = {}

  @Environment(\.practiceStore) private var practiceStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// The content blooms in from rest once, on arrival — hero first, then the
  /// grown tiles, then the way back.
  @State private var hasArrived = false
  /// One-shot trigger for the earned heart's little flourish.
  @State private var heartFlourish = 0
  /// The settled orb keeps a slow idle drift, like the intro's — the session
  /// hands it over at its resting fullness.
  @State private var idleSwell: CGFloat = 0.6

  var body: some View {
    ZStack {
      // Opaque base under the atmosphere's translucent stops, continuous with
      // the session screen so the crossfade lands on the same sky.
      Color.moonCream.ignoresSafeArea()
      AtmosphereBackground()

      VStack(spacing: 0) {
        Spacer()

        bloomsIn(hero, after: 0)

        bloomsIn(grownTiles, after: 0.15)
          .padding(.top, .rhythm)

        Spacer()

        bloomsIn(returnButton, after: 0.3)
          .padding(.bottom, .rhythm)
      }
      .padding(.horizontal, .edge)
    }
    .onAppear {
      hasArrived = true
      if reduceMotion {
        idleSwell = 0.6
      } else {
        withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
          idleSwell = 0.7
        }
      }
      // The heart floats off its tile once the tile has landed.
      Task {
        try? await Task.sleep(for: .seconds(0.7))
        heartFlourish += 1
      }
      AccessibilityNotification.Announcement("Session complete. A heart earned.").post()
    }
  }

  /// One step of the staggered arrival — rises softly into place, each group
  /// a beat after the one before. Opacity only under Reduce Motion.
  private func bloomsIn(_ view: some View, after delay: Double) -> some View {
    view
      .opacity(hasArrived ? 1 : 0)
      .offset(y: reduceMotion || hasArrived ? 0 : 14)
      .animation(.bloom.delay(delay), value: hasArrived)
  }

  // MARK: - Hero

  private var hero: some View {
    VStack(spacing: 0) {
      BreathingOrb(swell: idleSwell)
        .frame(width: 180)

      VStack(spacing: 8) {
        Text("Softly grown")
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
        Text("\(session.title) · \(session.durationMinutes) min settled into your garden")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .multilineTextAlignment(.center)
      }
      .padding(.top, .rhythm * 1.5)
    }
    .accessibilityElement(children: .combine)
  }

  // MARK: - What grew

  private var grownTiles: some View {
    HStack(spacing: 12) {
      grownTile(
        systemImage: "leaf.fill",
        iconStyle: GardenColor.sage,
        value: "\(practiceStore.minutesToday)",
        label: "min in your garden today"
      )

      grownTile(
        systemImage: "heart.fill",
        iconStyle: Color.blushPowder,
        value: "+1",
        label: "heart ready to give"
      )
      .heartBurst(trigger: heartFlourish)
    }
    // Both tiles stretch to the taller one, so the pair reads as one shelf.
    .fixedSize(horizontal: false, vertical: true)
  }

  private func grownTile(
    systemImage: String,
    iconStyle: Color,
    value: String,
    label: String
  ) -> some View {
    VStack(spacing: 8) {
      Image(systemName: systemImage)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(iconStyle)
        .frame(width: 40, height: 40)
        .background(.white.opacity(0.6), in: Circle())
      Text(value)
        .font(DeepType.bigNumber)
        .monospacedDigit()
        .foregroundStyle(.deepPlum)
      Text(label)
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.vertical, 18)
    .padding(.horizontal, 12)
    .frostedCard(cornerRadius: .tile)
    .accessibilityElement(children: .combine)
  }

  // MARK: - Return

  private var returnButton: some View {
    Button {
      onReturn()
    } label: {
      Text("Return")
        .font(DeepType.body.weight(.semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
          Capsule().fill(LinearGradient(
            colors: [.lavenderMist, .softLilac],
            startPoint: .topLeading, endPoint: .bottomTrailing
          ))
        )
        .shadow(color: .lavenderMist.opacity(0.4), radius: 12, x: 0, y: 6)
    }
    .buttonStyle(.softPress)
    .accessibilityLabel("Return from your session")
  }
}

#Preview("Deep session — softly grown") {
  DeepSessionCompletionView(session: DeepSessionLibrary.balancingBreath)
    .environment(\.practiceStore, MockPracticeStore())
}

#Preview("Deep session — first practice") {
  DeepSessionCompletionView(session: DeepSessionLibrary.balancingBreath)
    .environment(\.practiceStore, MockPracticeStore.fresh)
}
