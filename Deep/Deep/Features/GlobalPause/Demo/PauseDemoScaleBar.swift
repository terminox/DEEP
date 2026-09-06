#if DEBUG
import SwiftUI

/// The participant-scale scrubber: the three tiers as chips, plus a logarithmic
/// slider for everything between and beyond them. Revealed over the live globe
/// by a two-finger tap.
///
/// It sets one number and nothing else — no renderer tuning, no glow ceiling.
/// What the globe makes of that number is entirely the shipping behaviour,
/// which is the whole point: the honest answer is that past a few hundred
/// people it makes very little of it.
struct PauseDemoScaleBar: View {
  var director: PauseDemoDirector = .shared

  /// Pumps the session's live poll while a scrub is in flight. The poll loop
  /// runs on a 5 s beat, which is a long time to stand in front of someone
  /// waiting for a number to move.
  var onScrub: () -> Void = {}

  /// 1 … `PauseDemoDirector.maxParticipants`. It spans the same range the typed
  /// field in Settings accepts, so revealing this bar and brushing the slider
  /// can never silently shrink a figure someone entered there.
  private static let exponentRange: ClosedRange<Double> =
    0...log10(Double(PauseDemoDirector.maxParticipants))

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      readout
      tierChips
      Slider(value: exponentBinding, in: Self.exponentRange)
        .tint(.lavenderMist)
    }
    .padding(18)
    .background(
      .ultraThinMaterial,
      in: RoundedRectangle(cornerRadius: .card, style: .continuous)
    )
  }

  // MARK: - Parts

  private var readout: some View {
    HStack(alignment: .firstTextBaseline) {
      Text("IN THE ROOM")
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.moonCream.opacity(0.7))
      Spacer(minLength: 8)
      Text(director.target.formatted(.number.locale(.app)))
        .font(DeepType.counter)
        .monospacedDigit()
        .foregroundStyle(.moonCream)
        .contentTransition(.numericText(value: Double(director.target)))
    }
  }

  private var tierChips: some View {
    HStack(spacing: 8) {
      ForEach(PauseDemoDirector.tiers, id: \.self) { tier in
        let isShowing = director.target == tier
        Button {
          director.scrub(to: tier)
          onScrub()
        } label: {
          Text(Self.label(for: tier))
            .font(DeepType.caption)
            .foregroundStyle(isShowing ? Color.deepPlum : .moonCream)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background {
              if isShowing {
                Capsule().fill(.lavenderMist)
              } else {
                Capsule().fill(.moonCream.opacity(0.12))
              }
            }
        }
        .buttonStyle(.plain)
      }
    }
  }

  // MARK: - Scale

  /// Reads and writes the director directly rather than mirroring it in local
  /// state — a chip tap and a drag then move the same one number, and the thumb
  /// can never drift out of step with the count above it.
  private var exponentBinding: Binding<Double> {
    Binding(
      get: { Self.exponent(for: director.target) },
      set: { exponent in
        director.jump(to: Self.count(at: exponent))
        onScrub()
      }
    )
  }

  private static func count(at exponent: Double) -> Int {
    Int(pow(10, exponent).rounded())
  }

  private static func exponent(for count: Int) -> Double {
    guard count > 1 else { return exponentRange.lowerBound }
    return min(exponentRange.upperBound, log10(Double(count)))
  }

  /// "1K" / "10K" / "300K" — the chips name the tier, the readout above carries
  /// the exact figure.
  private static func label(for count: Int) -> String {
    count.formatted(.number.notation(.compactName).locale(.app))
  }
}

#Preview("Scale bar") {
  // Hermetic: its own director, never the shared one, so opening this preview
  // cannot arm the demo for the running app.
  ZStack {
    NightSkyBackground(tuning: NightSkyTuning())
      .ignoresSafeArea()
    VStack {
      Spacer()
      PauseDemoScaleBar(director: PauseDemoDirector.previewInstance())
        .padding(.horizontal, .edge)
    }
  }
}
#endif
