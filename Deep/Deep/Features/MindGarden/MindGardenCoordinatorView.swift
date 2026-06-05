import SwiftUI

/// Coordinator view for the Mind Garden flow — the business-specific composition
/// root. It owns navigation and hosts the home screen, and nothing else.
///
/// Per the project's SwiftUI rules, a coordinator keeps styling to a minimum:
/// screen-level styling such as `AtmosphereBackground` and the full-bleed hero
/// live in the leaf screen (`MindGardenHomeView`) so they render in front of the
/// `NavigationStack` rather than being hidden behind it.
struct MindGardenCoordinatorView: View {
  @State private var state: GardenState

  init(state: GardenState = .sample) {
    _state = State(initialValue: state)
  }

  var body: some View {
    NavigationStack {
      MindGardenHomeView(state: state)
        .toolbar(.hidden, for: .navigationBar)
    }
    .preferredColorScheme(.light)
  }
}

#Preview("Mind Garden") {
  MindGardenCoordinatorView()
}

#Preview("Mind Garden — Fresh") {
  MindGardenCoordinatorView(state: .fresh)
}
