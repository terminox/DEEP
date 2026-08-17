import SwiftUI

/// Coordinator view for the Compassion portfolio — the business-specific
/// composition root. It owns routing — the donate sheet, and the cause-detail
/// push — and nothing else.
///
/// The cause detail is currently **parked**: nothing appends to `path`, so
/// `CompassionCategoryView` is unreachable while giving happens on the cause
/// cards themselves. The route is kept wired rather than deleted, so the screen
/// (and everything built for it — `SendAHeartBar`, `CompassionProjectCard`,
/// `PartnerOrganizationCard`) is one call to `openCategory` away from returning.
///
/// The `HeartLedger` now lives app-wide (injected by the shell alongside
/// `\.practiceStore`), so hearts earned in a Deep Session anywhere land in the
/// same balance this tab shows.
///
/// Per the project's SwiftUI rules, a coordinator keeps styling to a minimum:
/// screen-level styling such as `AtmosphereBackground` lives in the leaf screens
/// (`CompassionPortfolioHomeView`, `CompassionCategoryView`) so it actually
/// renders behind their content rather than behind the `NavigationStack`.
struct CompassionPortfolioCoordinatorView: View {
  @State private var path = NavigationPath()
  @State private var donation: CompassionCategory?

  var body: some View {
    NavigationStack(path: $path) {
      CompassionPortfolioHomeView()
        .navigationDestination(for: CompassionCategory.self) { category in
          CompassionCategoryView(category: category)
        }
    }
    .sheet(item: $donation) { category in
      DonateHeartsView(category: category)
    }
    .environment(\.openCategory, { category in path.append(category) })
    .environment(\.openDonation, { category in donation = category })
    .preferredColorScheme(.light)
  }
}

extension EnvironmentValues {
  /// Pushes a cause's detail onto the Compassion navigation path. The coordinator
  /// injects the real append; leaf tiles call it from a `Button` instead of
  /// hosting a `NavigationLink`, so all routing flows through the coordinator's
  /// single `NavigationPath`. The default is a no-op fallback that keeps previews
  /// hermetic.
  ///
  /// Nothing calls this today — see the note on the coordinator.
  @Entry var openCategory: (CompassionCategory) -> Void = { _ in }

  /// Opens the donate sheet for a cause. Same contract as `openCategory`: a leaf
  /// card asks, the coordinator decides how it's presented, and the default
  /// no-op keeps previews hermetic.
  @Entry var openDonation: (CompassionCategory) -> Void = { _ in }
}

#Preview("Compassion — Portfolio") {
  CompassionPortfolioCoordinatorView()
    .environment(\.heartLedger, .sample)
}

#Preview("Compassion — No hearts left") {
  CompassionPortfolioCoordinatorView()
    .environment(\.heartLedger, .spent)
}
