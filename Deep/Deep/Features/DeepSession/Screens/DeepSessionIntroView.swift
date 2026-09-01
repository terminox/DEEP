import SwiftUI

/// The threshold before a Deep Session — a quiet page where you set how long
/// the practice runs, see what it holds (pattern, rounds), and step in. Pushed
/// onto the launching tab's navigation (so the tab bar and mini player stay),
/// where Begin lifts the practice up over the whole shell.
///
/// The length is the screen's subject, so the chosen numeral stands where an
/// idle orb used to breathe — on the screen's own centre line, with its unit
/// tucked underneath. Everything the practice says about itself follows, and
/// the one control that sets the length closes the column, next to the Begin
/// it feeds.
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

        lengthReadout

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

        lengthSlider
          .padding(.top, .rhythm * 1.5)

        // The track now ends the column, so at the largest text sizes it is
        // the thing Begin closes on: keep a gap between them however little
        // room is left, and let the space above take the squeeze.
        Spacer(minLength: .rhythm)

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

  /// The length being chosen. The numeral carries the screen, so it sits on the
  /// centre line itself and the unit goes underneath — set beside it, the unit's
  /// own width would push the numeral off centre by half of it, which is
  /// exactly what an eye reading a single big number notices.
  private var lengthReadout: some View {
    // Negative, because the numeral's line box reserves a descender the digits
    // never use: it is the gap under the glyph that is being closed, not the
    // gap under the text.
    VStack(spacing: -10) {
      Text(minutes.formatted())
        .font(DeepType.heroNumber)
        .foregroundStyle(.deepPlum)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .contentTransition(.numericText(value: Double(minutes)))
      Text("MIN")
        .font(DeepType.micro)
        .tracking(.microTracking)
        // Tracking is added after the last letter too, so the word would sit
        // half a space left of the numeral above it without this.
        .padding(.leading, .microTracking)
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
    // The slider below speaks for both: it announces this value and is the
    // thing that can change it.
    .accessibilityHidden(true)
  }

  /// The one control that sets the length, closing the column under everything
  /// the practice says about itself.
  ///
  /// The system slider, for the thumb: a value being placed by hand should show
  /// what the hand is holding. Deep's own `SoundSlider` is a bare fill made for
  /// scrubbing audio, where the fill *is* the position — here the fill alone
  /// leaves nothing to grab, and at one minute it empties out and reads as a
  /// rule drawn across the screen.
  private var lengthSlider: some View {
    Slider(
      value: lengthValue,
      in: Double(DeepSessionLength.range.lowerBound)...Double(DeepSessionLength.range.upperBound),
      step: 1
    )
    .tint(.lavenderMist)
    .padding(.horizontal, .edge)
    .accessibilityLabel("Session length")
    .accessibilityValue("\(minutes) minutes")
    // A tick at each minute, so the length can be set by feel.
    .sensoryFeedback(.selection, trigger: minutes)
  }

  /// The slider's value: whole minutes, as the readout above states them. The
  /// step keeps it on the detents, and the clamp keeps a stored value from an
  /// older range inside the offer.
  private var lengthValue: Binding<Double> {
    let range = DeepSessionLength.range
    return Binding(
      get: { Double(min(range.upperBound, max(range.lowerBound, minutes))) },
      set: { minutes = min(range.upperBound, max(range.lowerBound, Int($0.rounded()))) }
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
