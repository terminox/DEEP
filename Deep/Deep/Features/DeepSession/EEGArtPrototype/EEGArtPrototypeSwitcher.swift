#if DEBUG
import SwiftUI

// PROTOTYPE — throwaway. The floating bar that flips variants, people and
// Live / After. Deliberately dark and loud so nobody mistakes it for design.
// Adapted from the Growth Passport prototype's switcher.

struct EEGArtPrototypeSwitcher: View {
  @Binding var variant: EEGArtVariant
  @Binding var person: EEGPerson
  @Binding var stage: EEGArtStage
  @Binding var speed: EEGSessionPlayer.Speed
  var progress: Double
  var onRestart: () -> Void

  @State private var isCollapsed = false

  private let variants = EEGArtVariant.allCases

  var body: some View {
    VStack(spacing: 6) {
      if !isCollapsed {
        HStack(spacing: 6) {
          pills(EEGPerson.allCases, selection: $person, label: \.label, id: "person")
        }

        HStack(spacing: 6) {
          pills(EEGArtStage.allCases, selection: $stage, label: \.label, id: "stage")
          if stage == .live {
            pills(EEGSessionPlayer.Speed.allCases, selection: $speed, label: \.label, id: "speed")
            Button(action: onRestart) {
              HStack(spacing: 5) {
                Image(systemName: "arrow.counterclockwise")
                Text("\(Int(progress * 10)):\(String(format: "%02d", Int(progress * 600) % 60))")
                  .monospacedDigit()
              }
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(.white)
              .padding(.horizontal, 10)
              .frame(height: 28)
              .background(.black.opacity(0.82), in: Capsule())
            }
            .accessibilityIdentifier("prototype.restart")
          }
        }
      }

      HStack(spacing: 0) {
        Button { withAnimation(.exhale) { isCollapsed.toggle() } } label: {
          Image(systemName: isCollapsed ? "chevron.up" : "chevron.down")
            .frame(width: 34, height: 40)
        }
        .accessibilityIdentifier("prototype.collapse")
        Button { step(-1) } label: {
          Image(systemName: "chevron.left").frame(width: 40, height: 40)
        }
        .accessibilityIdentifier("prototype.previous")

        Text("\(variant.rawValue.uppercased())  \(variant.title)")
          .font(.system(size: 13, weight: .semibold))
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

  private func pills<Option: Identifiable & Equatable>(
    _ options: [Option],
    selection: Binding<Option>,
    label: KeyPath<Option, String>,
    id: String
  ) -> some View {
    HStack(spacing: 2) {
      ForEach(options) { option in
        Button {
          selection.wrappedValue = option
        } label: {
          Text(option[keyPath: label])
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(option == selection.wrappedValue ? .black : .white.opacity(0.75))
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(option == selection.wrappedValue ? .white : .clear, in: Capsule())
        }
        .accessibilityIdentifier("prototype.\(id).\(option.id)")
      }
    }
    .padding(2)
    .background(.black.opacity(0.82), in: Capsule())
  }

  private func step(_ delta: Int) {
    let index = variants.firstIndex(of: variant) ?? 0
    variant = variants[(index + delta + variants.count) % variants.count]
  }
}

#Preview("Switcher") {
  @Previewable @State var variant = EEGArtVariant.b
  @Previewable @State var person = EEGPerson.regular
  @Previewable @State var stage = EEGArtStage.live
  @Previewable @State var speed = EEGSessionPlayer.Speed.calm
  ZStack(alignment: .bottom) {
    Color.moonCream.ignoresSafeArea()
    EEGArtPrototypeSwitcher(
      variant: $variant, person: $person, stage: $stage, speed: $speed,
      progress: 0.42, onRestart: {}
    )
  }
}
#endif
