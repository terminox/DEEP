#if DEBUG
import SwiftUI

/// One tuning knob: micro label + live numeric readout over a system slider.
/// Debug-harness styling on purpose (plain `Slider`, lavender tint) — this is
/// tooling, not product UI.
struct TuningSliderRow: View {
  let label: String
  @Binding var value: Float
  let range: ClosedRange<Float>
  /// Log-scale the slider travel — for radii and other values whose useful
  /// range spans an order of magnitude. Requires a strictly positive range.
  var logScale = false

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text(label)
          .font(DeepType.micro).tracking(1.2)
          .foregroundStyle(.driftGrey)
        Spacer()
        Text(String(format: "%.3g", value))
          .font(DeepType.counter)
          .foregroundStyle(.deepPlum)
      }
      Slider(value: sliderValue, in: sliderRange)
        .tint(.lavenderMist)
    }
  }

  private var sliderRange: ClosedRange<Double> {
    logScale
      ? Double(log10(range.lowerBound))...Double(log10(range.upperBound))
      : Double(range.lowerBound)...Double(range.upperBound)
  }

  private var sliderValue: Binding<Double> {
    Binding {
      logScale ? Double(log10(max(value, range.lowerBound))) : Double(value)
    } set: { newValue in
      value = logScale ? Float(pow(10, newValue)) : Float(newValue)
    }
  }
}

/// Integer variant — steps of 1, for caps and counts.
struct TuningIntSliderRow: View {
  let label: String
  @Binding var value: Int
  let range: ClosedRange<Int>

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text(label)
          .font(DeepType.micro).tracking(1.2)
          .foregroundStyle(.driftGrey)
        Spacer()
        Text("\(value)")
          .font(DeepType.counter)
          .foregroundStyle(.deepPlum)
      }
      Slider(
        value: Binding { Double(value) } set: { value = Int($0.rounded()) },
        in: Double(range.lowerBound)...Double(range.upperBound),
        step: 1
      )
      .tint(.lavenderMist)
    }
  }
}

/// Bridges a `Double`/`TimeInterval` property into the Float row.
func tuningFloatBinding(_ source: Binding<Double>) -> Binding<Float> {
  Binding { Float(source.wrappedValue) } set: { source.wrappedValue = Double($0) }
}

#Preview {
  @Previewable @State var value: Float = 0.45
  @Previewable @State var radius: Float = 0.034
  @Previewable @State var cap = 12

  VStack(spacing: 16) {
    TuningSliderRow(label: "bloom strength", value: $value, range: 0...1.5)
    TuningSliderRow(label: "point radius", value: $radius, range: 0.005...0.2, logScale: true)
    TuningIntSliderRow(label: "spark cap", value: $cap, range: 1...32)
  }
  .padding(20)
  .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  .padding()
  .background(Color.moonCream)
}
#endif
