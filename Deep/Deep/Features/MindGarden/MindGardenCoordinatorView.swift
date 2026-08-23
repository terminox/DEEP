import SwiftUI

/// The Mind Garden coordinator's own routes — currently just the plant picker.
/// Deep Session pushes ride the `DeepSession` value itself, as everywhere else.
enum GardenRoute: Hashable {
  case plantPicker
}

/// Coordinator view for the Mind Garden flow — the business-specific composition
/// root. It owns navigation (home → Deep Session threshold, home → plant
/// picker) and hosts the home screen, and nothing else.
///
/// Per the project's SwiftUI rules, a coordinator keeps styling to a minimum:
/// screen-level styling such as `AtmosphereBackground` and the full-bleed hero
/// live in the leaf screen (`MindGardenHomeView`) so they render in front of the
/// `NavigationStack` rather than being hidden behind it.
struct MindGardenCoordinatorView: View {
  @Environment(\.practiceStore) private var practice
  @Environment(\.gardenStore) private var gardenStore
  @State private var path = NavigationPath()

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
        .navigationDestination(for: GardenRoute.self) { route in
          switch route {
          case .plantPicker:
            PlantPickerView()
          }
        }
    }
    .environment(\.openDeepSession, { session in path.append(session) })
    .environment(\.openPlantPicker, { path.append(GardenRoute.plantPicker) })
    .preferredColorScheme(.light)
  }
}

extension EnvironmentValues {
  /// Pushes the plant picker onto the Mind Garden navigation path. The
  /// coordinator injects the real append (mirroring `openDeepSession`); the
  /// growth card's quiet "Change" affordance calls it from a plain `Button`,
  /// so all routing flows through the coordinator's single `NavigationPath`.
  /// The no-op default keeps previews hermetic.
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
