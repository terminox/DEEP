import SwiftUI

/// The threshold before a Deep Session — a quiet page where you set how long
/// the practice runs, see what it holds (pattern, rounds), and step in. Pushed
/// onto the launching tab's navigation (so the tab bar and mini player stay),
/// where Begin lifts the practice up over the whole shell.
///
/// The length is the screen's subject, so the chosen numeral stands where an
/// idle orb used to breathe, with its one control directly beneath it.
///
/// Navigation chrome is the system's: a back chevron over a hidden bar
/// background, and the edge-swipe pop that comes with it. A custom close
/// control would cost the gesture — UIKit ties the interactive pop to the
/// system back button, and no delegate trick restores it once that button is
/// gone (verified on both a SwiftUI `NavigationStack` and a UIKit one).
///
/// Leaf screen, so it owns its screen-level styling (per the coordinator
/// rules).
struct DeepSessionIntroView: View {
  let session: DeepSession

  /// The chosen length in whole minutes, remembered between visits — someone
  /// who settled on six minutes shouldn't have to say so again tomorrow.
  @AppStorage("deep.session.minutes") private var minutes = DeepSessionLength.opening
  /// True from Begin until the practice closes — the beat this screen answers
  /// with its own half of the lift.
  @State private var isRunning = false

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// The practice at the length now chosen — what Begin actually runs.
  private var chosen: DeepSession { session.lasting(minutes: minutes) }

  var body: some View {
    ZStack {
      // Opaque base under the atmosphere's translucent stops: nothing beneath
      // this screen may ever show through.
      Color.moonCream.ignoresSafeArea()
      AtmosphereBackground()

      VStack(spacing: 0) {
        Spacer()

        lengthControl

        VStack(spacing: 8) {
          Text(session.title)
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
          Text(session.tagline)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .multilineTextAlignment(.center)
        }
        .padding(.top, .rhythm * 1.5)

        Text("\(Int(session.inhale))s in · \(Int(session.exhale))s out · \(chosen.cycles) rounds")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey.opacity(0.8))
          // A quiet crossfade as the rounds follow the slider — the numeral
          // above is the one thing on this screen allowed to roll.
          .contentTransition(.opacity)
          .animation(.bloom, value: chosen.cycles)
          .padding(.top, .rhythm)

        Spacer()

        beginButton
          .padding(.bottom, .rhythm)
      }
      .padding(.horizontal, .edge)
      .offset(y: contentLift)
    }
    // This screen's half of the lift: the content rises as the practice fades
    // up over it. Only the content — the `moonCream` base and the atmosphere
    // stay anchored, so no gap can open at an edge — and no opacity, since the
    // practice's own opaque base already fades this out at exactly the right
    // rate.
    .animation(.hush, value: isRunning)
    .deepSessionRun(session: chosen, isPresented: $isRunning)
    // The bar stays but disappears: no title (the practice already names itself
    // in the middle of the screen) and no background, so the atmosphere runs
    // under the chevron.
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
  }

  /// Matches `SoftDrift.drop`, the travel the practice's own stages use.
  private var contentLift: CGFloat {
    isRunning && !reduceMotion ? -16 : 0
  }

  // MARK: - Length

  /// The length being chosen, and the one control that sets it.
  private var lengthControl: some View {
    VStack(spacing: 18) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        // The widest value the range holds, drawn but unseen: it owns the
        // layout so the unit beside it can't jump sideways when the numeral
        // gains its second digit, and it carries the baseline the row aligns on.
        Text(verbatim: "00")
          .font(DeepType.heroNumber)
          .hidden()
          .overlay(alignment: .trailing) {
            Text(minutes.formatted())
              .font(DeepType.heroNumber)
              .foregroundStyle(.deepPlum)
              .lineLimit(1)
              .minimumScaleFactor(0.6)
              .contentTransition(.numericText(value: Double(minutes)))
          }
        Text("MIN")
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)
      }
      // Stated here rather than left to the drag: the value changes inside a
      // gesture callback, which carries no transaction of its own, and a
      // spring keeps up with a finger where a long curve would pile up.
      .animation(.settle, value: minutes)
      // The warmth a chosen numeral sits on elsewhere in the app, re-centred
      // under this one and carried in the session's lavender.
      .background {
        RadialGradient(
          colors: [Color.lavenderMist.opacity(0.32), Color.lavenderMist.opacity(0)],
          center: .center,
          startRadius: 8,
          endRadius: 190
        )
        .frame(width: 380, height: 260)
        .allowsHitTesting(false)
      }

      SoundSlider(value: lengthTrack)
        .padding(.horizontal, .edge)
    }
    // The track carries no accessibility of its own, so the pair is presented
    // as the single adjustable value it really is.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Session length")
    .accessibilityValue("\(minutes) minutes")
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment:
        minutes = min(DeepSessionLength.range.upperBound, minutes + 1)
      case .decrement:
        minutes = max(DeepSessionLength.range.lowerBound, minutes - 1)
      @unknown default:
        break
      }
    }
    // A tick at each minute, so the length can be set by feel.
    .sensoryFeedback(.selection, trigger: minutes)
  }

  /// `SoundSlider`'s 0…1 track, read and written in whole minutes so the fill
  /// settles on a detent instead of following the finger between them.
  ///
  /// The fill is the chosen minutes out of the ten on offer, not the distance
  /// travelled from the first — at one minute an offset track would empty out
  /// completely and read as a rule drawn across the screen.
  private var lengthTrack: Binding<Double> {
    let range = DeepSessionLength.range
    let highest = Double(range.upperBound)
    return Binding(
      get: { Double(minutes) / highest },
      set: { minutes = min(range.upperBound, max(range.lowerBound, Int(($0 * highest).rounded()))) }
    )
  }

  // MARK: - Begin

  private var beginButton: some View {
    Button {
      isRunning = true
    } label: {
      Text("Begin")
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
    .accessibilityLabel("Begin \(session.title), \(minutes) minutes")
  }
}

#if DEBUG
#Preview("Deep session intro") {
  // Inside a stack, the way it is really reached — pushed from an entry card.
  NavigationStack {
    DeepSessionIntroView(session: DeepSessionLibrary.balancingBreath)
  }
  .environment(\.soundPlayer, MockSoundPlayer.idle)
  .environment(\.practiceStore, MockPracticeStore())
  .environment(\.heartLedger, .sample)
}
#endif
