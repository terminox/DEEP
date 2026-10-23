#if DEBUG
import SwiftUI

// PROTOTYPE — throwaway, DEBUG only.
// Four structurally different Growth Passport variants on one screen, switched
// from a floating bar. Opened from the Mind Garden home's prototype pill, or
// straight from launch with `-growthPassportPrototype`.
// Plan: ~/.claude/plans/my-client-wants-to-drifting-boot.md

enum PassportPrototypeVariant: String, CaseIterable, Identifiable {
  case a, b, c, d

  var id: String { rawValue }

  var title: String {
    switch self {
    case .a: "The Passport"
    case .b: "Growth Journal"
    case .c: "Chapters"
    case .d: "Keepsake & Portfolio"
    }
  }
}

extension EnvironmentValues {
  /// Opens the shared export sheet (printable PDF). Each variant calls it from
  /// its own export action.
  @Entry var exportPassport: () -> Void = {}
}

/// Hosts the variant being judged plus the switcher. Variant and journey
/// survive relaunch, the iOS stand-in for a `?variant=` URL.
struct GrowthPassportPrototypeView: View {
  @AppStorage("prototype.passport.variant") private var variant = PassportPrototypeVariant.a
  @AppStorage("prototype.passport.journey") private var journey = PassportJourney.sixMonths
  @State private var isExporting = false
  @Environment(\.dismiss) private var dismiss

  /// Nil when booted straight into the prototype: there is nothing to close to.
  var canClose = true

  private var sample: PassportSample { .sample(journey) }

  var body: some View {
    ZStack(alignment: .bottom) {
      Group {
        switch variant {
        case .a: PassportBookPrototypeView(sample: sample)
        case .b: GrowthJournalPrototypeView(sample: sample)
        case .c: ChaptersPrototypeView(sample: sample)
        case .d: KeepsakePrototypeView(sample: sample)
        }
      }
      // A fresh identity per variant and journey, so each one starts from its
      // own first moment instead of inheriting the last one's state.
      .id("\(variant.rawValue)-\(journey.rawValue)")
      .transition(.opacity)

      // `-hidePrototypeSwitcher` keeps the bar out of demo recordings.
      if !ProcessInfo.processInfo.arguments.contains("-hidePrototypeSwitcher") {
        PrototypeVariantSwitcher(
          variant: $variant,
          journey: $journey,
          onClose: canClose ? { dismiss() } : nil
        )
        .padding(.bottom, 8)
      }
    }
    .animation(.exhale, value: variant)
    .animation(.exhale, value: journey)
    .environment(\.exportPassport, { isExporting = true })
    .sheet(isPresented: $isExporting) {
      PassportExportSheet(sample: sample)
    }
    .preferredColorScheme(.light)
  }
}

#Preview("Growth Passport prototype") {
  GrowthPassportPrototypeView()
}
#endif
