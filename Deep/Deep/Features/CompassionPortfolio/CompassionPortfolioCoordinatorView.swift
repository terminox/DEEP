import SwiftUI

/// Coordinator view for the Compassion portfolio — the business-specific
/// composition root. It owns navigation (portfolio → cause detail) and the
/// shared `HeartLedger`, and nothing else.
///
/// Per the project's SwiftUI rules, a coordinator keeps styling to a minimum:
/// screen-level styling such as `AtmosphereBackground` lives in the leaf screens
/// (`CompassionPortfolioHomeView`, `CompassionCategoryView`) so it actually
/// renders behind their content rather than behind the `NavigationStack`.
struct CompassionPortfolioCoordinatorView: View {
  @State private var ledger: HeartLedger
  @State private var path = NavigationPath()

  init(ledger: HeartLedger = .sample) {
    _ledger = State(initialValue: ledger)
  }

  var body: some View {
    NavigationStack(path: $path) {
      CompassionPortfolioHomeView()
        .navigationDestination(for: CompassionCategory.self) { category in
          CompassionCategoryView(category: category)
        }
    }
    .environment(\.openCategory, { category in path.append(category) })
    .environment(\.heartLedger, ledger)
    .preferredColorScheme(.light)
  }
}

extension EnvironmentValues {
  /// Pushes a cause's detail onto the Compassion navigation path. The coordinator
  /// injects the real append; leaf tiles call it from a `Button` instead of
  /// hosting a `NavigationLink`, so all routing flows through the coordinator's
  /// single `NavigationPath`. The default is a no-op fallback that keeps previews
  /// hermetic.
  @Entry var openCategory: (CompassionCategory) -> Void = { _ in }
}

#Preview("Compassion — Portfolio") {
  CompassionPortfolioCoordinatorView(ledger: .sample)
}

#Preview("Compassion — No hearts left") {
  CompassionPortfolioCoordinatorView(ledger: .spent)
}
