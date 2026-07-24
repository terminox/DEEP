import SwiftUI

/// Coordinator view for the Mind Garden flow — the business-specific composition
/// root. It owns navigation and hosts the home screen, and nothing else.
///
/// Per the project's SwiftUI rules, a coordinator keeps styling to a minimum:
/// screen-level styling such as `AtmosphereBackground` and the full-bleed hero
/// live in the leaf screen (`MindGardenHomeView`) so they render in front of the
/// `NavigationStack` rather than being hidden behind it.
struct MindGardenCoordinatorView: View {
  @Environment(\.practiceStore) private var practice

  var body: some View {
    NavigationStack {
      // Derived in body, so reading the journal's observable aggregates keeps
      // the garden live: a session finished anywhere regrows this screen.
      MindGardenHomeView(state: GardenState(practice: practice))
        .toolbar(.hidden, for: .navigationBar)
    }
  }
}

#Preview("Mind Garden") {
  MindGardenCoordinatorView()
    .environment(\.practiceStore, MockPracticeStore())
}

#Preview("Mind Garden — Fresh") {
  MindGardenCoordinatorView()
    .environment(\.practiceStore, MockPracticeStore.fresh)
}
