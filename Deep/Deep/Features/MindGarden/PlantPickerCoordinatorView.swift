import SwiftUI

/// Coordinator view for the plant picker sheet — the composition root of the
/// one flow that lives inside it: choosing a plant, and, when the plant tapped
/// is DEEP Premium, the invitation.
///
/// The picker is a sheet, so the paywall can't be pushed on the Garden's own
/// stack — it would open *under* the sheet. It is pushed on this one instead,
/// inside the sheet, so it appears over the picker and "Not right now" steps
/// straight back to the plants. The sheet rises to full height for it: the
/// paywall is a screen, not a card.
///
/// Per the project's SwiftUI rules this carries no styling; the picker and the
/// paywall each draw their own atmosphere.
struct PlantPickerCoordinatorView: View {
  @State private var path = NavigationPath()
  @State private var detent: PresentationDetent = .height(560)

  var body: some View {
    NavigationStack(path: $path) {
      PlantPickerSheet()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: PaywallSource.self) { source in
          PaywallView(source: source) { pop() }
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
    }
    .presentationDetents([.height(560), .large], selection: $detent)
    .environment(\.openPaywall, { source in
      detent = .large
      path.append(source)
    })
  }

  private func pop() {
    guard !path.isEmpty else { return }
    path.removeLast()
  }
}

#if DEBUG
#Preview("Plant picker — a premium plant, locked") {
  @Previewable @State var open = true
  Color.clear
    .background { AtmosphereBackground() }
    .sheet(isPresented: $open) { PlantPickerCoordinatorView() }
    .environment(\.gardenStore, .pickerWithPremium)
    .environment(\.premiumAccess, .free)
    .environment(\.subscriptionStore, MockSubscriptionStore.free)
    .environment(\.imageLoader, FixtureImageLoader())
}

#Preview("Plant picker — a member, premium plant open") {
  @Previewable @State var open = true
  Color.clear
    .background { AtmosphereBackground() }
    .sheet(isPresented: $open) { PlantPickerCoordinatorView() }
    .environment(\.gardenStore, .pickerWithPremium)
    .environment(\.premiumAccess, .member)
    .environment(\.imageLoader, FixtureImageLoader())
}

#Preview("Plant picker — lapsed, growing the premium plant") {
  @Previewable @State var open = true
  Color.clear
    .background { AtmosphereBackground() }
    .sheet(isPresented: $open) { PlantPickerCoordinatorView() }
    .environment(\.gardenStore, .lapsedGrowingPremium)
    .environment(\.premiumAccess, .free)
    .environment(\.imageLoader, FixtureImageLoader())
}
#endif
