#if DEBUG
import SwiftUI

// PROTOTYPE — throwaway. The floating bar that flips variants and journeys.
// Deliberately dark and loud so nobody mistakes it for part of the design.

struct PrototypeVariantSwitcher: View {
  @Binding var variant: PassportPrototypeVariant
  @Binding var journey: PassportJourney
  var onClose: (() -> Void)? = nil

  private let variants = PassportPrototypeVariant.allCases
  private let journeys = PassportJourney.allCases

  var body: some View {
    VStack(spacing: 6) {
      HStack(spacing: 4) {
        ForEach(journeys) { option in
          Button {
            journey = option
          } label: {
            Text(option.label)
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(option == journey ? .black : .white.opacity(0.7))
              .padding(.horizontal, 10)
              .padding(.vertical, 5)
              .background(option == journey ? .white : .clear, in: Capsule())
          }
          .accessibilityIdentifier("prototype.journey.\(option.rawValue)")
        }
      }
      .padding(3)
      .background(.black.opacity(0.82), in: Capsule())

      HStack(spacing: 0) {
        if let onClose {
          Button(action: onClose) {
            Image(systemName: "xmark")
              .frame(width: 40, height: 40)
          }
          .accessibilityIdentifier("prototype.close")
        }
        Button { step(-1) } label: {
          Image(systemName: "chevron.left").frame(width: 40, height: 40)
        }
        .accessibilityIdentifier("prototype.previous")

        Text("\(variant.rawValue.uppercased())  \(variant.title)")
          .font(.system(size: 13, weight: .semibold))
          .monospacedDigit()
          .frame(minWidth: 170)
          .contentTransition(.opacity)

        Button { step(1) } label: {
          Image(systemName: "chevron.right").frame(width: 40, height: 40)
        }
        .accessibilityIdentifier("prototype.next")
      }
      .font(.system(size: 14, weight: .bold))
      .foregroundStyle(.white)
      .padding(.horizontal, 6)
      .background(.black.opacity(0.82), in: Capsule())
    }
    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
  }

  private func step(_ delta: Int) {
    let index = variants.firstIndex(of: variant) ?? 0
    variant = variants[(index + delta + variants.count) % variants.count]
  }
}

#Preview("Switcher") {
  @Previewable @State var variant = PassportPrototypeVariant.b
  @Previewable @State var journey = PassportJourney.sixMonths
  ZStack {
    AtmosphereBackground()
    PrototypeVariantSwitcher(variant: $variant, journey: $journey, onClose: {})
  }
}
#endif
