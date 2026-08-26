import SwiftUI

/// Coordinator view for the Mind Garden flow — the business-specific composition
/// root. It owns navigation (home → Deep Session threshold) and the one
/// presentation this flow raises (the plant picker sheet), and hosts the home
/// screen — nothing else.
///
/// Per the project's SwiftUI rules, a coordinator keeps styling to a minimum:
/// screen-level styling such as `AtmosphereBackground` and the full-bleed hero
/// live in the leaf screen (`MindGardenHomeView`) so they render in front of the
/// `NavigationStack` rather than being hidden behind it.
struct MindGardenCoordinatorView: View {
  @Environment(\.practiceStore) private var practice
  @Environment(\.gardenStore) private var gardenStore
  @State private var path = NavigationPath()
  /// The plant picker is raised, not pushed — a choice made beside the garden
  /// rather than a place you travel to.
  @State private var isPickingPlant = false

  var body: some View {
    NavigationStack(path: $path) {
      // Derived in body, so reading the journal's observable aggregates keeps
      // the garden live: a session finished anywhere regrows this screen.
      MindGardenHomeView(state: GardenState(practice: practice))
        .toolbar(.hidden, for: .navigationBar)
        .heroRefreshable {
          // One pull refreshes both truths — the journal and the garden.
          async let garden: Void = gardenStore.refresh()
          await practice.refresh()
          await garden
        }
        .navigationDestination(for: DeepSession.self) { session in
          DeepSessionIntroView(session: session)
        }
    }
    .sheet(isPresented: $isPickingPlant) { PlantPickerSheet() }
    .environment(\.openDeepSession, { session in path.append(session) })
    .environment(\.openPlantPicker, { isPickingPlant = true })
    .preferredColorScheme(.light)
  }
}

extension EnvironmentValues {
  /// Raises the plant picker sheet. The coordinator injects the real
  /// presentation (mirroring `openDeepSession`); the growth card's quiet
  /// "Change" pill calls it from a plain `Button`, so all routing stays in the
  /// coordinator. The no-op default keeps previews hermetic.
  @Entry var openPlantPicker: () -> Void = {}
}

#Preview("Mind Garden") {
  MindGardenCoordinatorView()
    .environment(\.practiceStore, MockPracticeStore())
    .environment(\.gardenStore, .sample)
}

#Preview("Mind Garden — Fresh") {
  MindGardenCoordinatorView()
    .environment(\.practiceStore, MockPracticeStore.fresh)
    .environment(\.gardenStore, .fresh)
}
