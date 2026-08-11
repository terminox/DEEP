import SwiftUI

/// The gentle beat after a finished Deep Session — the same sky, one breath
/// later. The orb stays where the session left it, growth is spoken as a single
/// line rather than counted on tiles, and the garden's own plant stands at
/// ground level to receive the practice. Never a score; no streaks, no goals,
/// no numbers to chase.
///
/// Leaf screen, so it owns its screen-level styling (per the coordinator
/// rules). Third and final stage of the presented flow, arrived at on its own
/// once the engine finishes; Return dismisses it.
struct DeepSessionCompletionView: View {
  let session: DeepSession
  var onReturn: () -> Void = {}

  @Environment(\.practiceStore) private var practiceStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// The content blooms in from rest once, on arrival — reflection first, then
  /// the plant, then the way back. The orb itself never blooms: it rides the
  /// screen crossfade so it reads as the session's orb continuing.
  @State private var hasArrived = false
  /// One-shot trigger for the heart the garden gives back.
  @State private var heartFlourish = 0
  /// The settled orb keeps a slow idle drift, like the intro's — the session
  /// hands it over at its resting fullness.
  @State private var idleSwell: CGFloat = 0.6
  /// Flips once the minutes have settled into today's total, rolling the
  /// digits up from the pre-session count.
  @State private var minutesGrown = false

  var body: some View {
    ZStack {
      // Opaque base under the atmosphere's translucent stops, continuous with
      // the session screen so the crossfade lands on the same sky.
      Color.moonCream.ignoresSafeArea()
      AtmosphereBackground()

      VStack(spacing: 0) {
        Spacer()

        BreathingOrb(swell: idleSwell)
          .frame(width: 280)
          .accessibilityHidden(true)

        bloomsIn(reflection, after: 0)
          .padding(.top, .rhythm * 1.5)

        Spacer()

        plant

        bloomsIn(returnButton, after: 0.5)
          .padding(.top, .rhythm)
          .padding(.bottom, .rhythm)
      }
      .padding(.horizontal, .edge)
    }
    .onAppear {
      hasArrived = true
      if reduceMotion {
        idleSwell = 0.6
        minutesGrown = true
      } else {
        withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
          idleSwell = 0.7
        }
      }
      Task {
        if !reduceMotion {
          try? await Task.sleep(for: .seconds(1.2))
          withAnimation(.exhale) { minutesGrown = true }
        }
        // The heart rises from the plant once everything has settled.
        try? await Task.sleep(for: .seconds(0.8))
        heartFlourish += 1
      }
      AccessibilityNotification.Announcement(
        "Session complete. \(practiceStore.minutesToday) minutes in your garden today. A heart ready to give."
      ).post()
    }
  }

  /// Today's total including this session — the store records the completion
  /// before the crossfade, so the digits roll from the pre-session count up to
  /// the grown one: growth witnessed, not a score displayed.
  private var minutesShown: Int {
    minutesGrown
      ? practiceStore.minutesToday
      : max(0, practiceStore.minutesToday - session.durationMinutes)
  }

  /// The oak's current form, derived the same way the garden home screen
  /// derives it — one shared path, so once growth points persist this screen
  /// follows automatically.
  private var grownOak: OakStage {
    GardenState(practice: practiceStore).growth.stage
  }

  /// One step of the staggered arrival — rises softly into place, each group
  /// a beat after the one before. Opacity only under Reduce Motion.
  private func bloomsIn(_ view: some View, after delay: Double) -> some View {
    view
      .opacity(hasArrived ? 1 : 0)
      .offset(y: reduceMotion || hasArrived ? 0 : 14)
      .animation(.bloom.delay(delay), value: hasArrived)
  }

  // MARK: - Reflection

  private var reflection: some View {
    VStack(spacing: 8) {
      VStack(spacing: 6) {
        Text("Session complete")
          .textCase(.uppercase)
          .font(DeepType.micro)
          .tracking(1.4)
          .foregroundStyle(.driftGrey)
        Text("Softly grown")
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
      }
      Text("\(minutesShown) min in your garden today · a heart ready to give")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .multilineTextAlignment(.center)
        .contentTransition(.numericText(value: Double(minutesShown)))
    }
    .accessibilityElement(children: .combine)
  }

  // MARK: - Plant

  /// The garden made real — the oak in its current form, blooming up from its
  /// roots on arrival. The artwork ships on an opaque white square, so it sits
  /// in the same rounded, lavender-veiled frame the garden's growth card uses
  /// rather than standing bare on the atmosphere.
  private var plant: some View {
    Image(grownOak.imageName)
      .resizable()
      .scaledToFit()
      .padding(6)
      .frame(width: 84, height: 84)
      .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(.lavenderMist.opacity(0.08))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
      )
      .heartBurst(trigger: heartFlourish)
      .opacity(hasArrived ? 1 : 0)
      .scaleEffect(reduceMotion || hasArrived ? 1 : 0.92, anchor: .bottom)
      .animation(.bloom.delay(0.35), value: hasArrived)
      .accessibilityHidden(true)
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
    .environment(\.practiceStore, MockPracticeStore(
      minutesToday: DeepSessionLibrary.balancingBreath.durationMinutes,
      currentStreakDays: 1,
      longestStreakDays: 1
    ))
}

#Preview("Deep session — deep roots") {
  DeepSessionCompletionView(session: DeepSessionLibrary.balancingBreath)
    .environment(\.practiceStore, MockPracticeStore(
      minutesToday: 16,
      currentStreakDays: 30,
      longestStreakDays: 45
    ))
}
