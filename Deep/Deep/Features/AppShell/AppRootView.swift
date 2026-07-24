import SwiftUI

/// The app's SwiftUI root and composition point. It owns `AppDependencies`
/// (the API client + all app-lifetime stores) and decides among three phases:
///
///  - **restoring** — a calm launch beat while any saved session is confirmed
///    with the backend, so a returning user never flashes the welcome screen.
///  - **flow** — the onboarding + auth flow (welcome → quiz → mind tree →
///    sign-up → shaping, or welcome → log in).
///  - **main** — the UIKit tab shell, once the user is authenticated *and* their
///    onboarding is complete.
///
/// Transitions are a `.bloom` crossfade, never a hard cut, per Deep's motion
/// language. Dependencies are injected into the environment for both branches.
struct AppRootView: View {
  @State private var deps = AppDependencies()
  @State private var didRestore = false
  @Environment(\.scenePhase) private var scenePhase

  private enum Phase: Equatable { case restoring, flow, main }

  private var phase: Phase {
    guard didRestore else { return .restoring }
    return (deps.accountStore.isSignedIn && deps.onboardingStore.hasCompletedOnboarding)
      ? .main : .flow
  }

  var body: some View {
    ZStack {
      switch phase {
      case .restoring:
        ZStack {
          AtmosphereBackground()
          LoadingOrb()
        }
        .transition(.opacity)
      case .main:
        RootTabView(
          onboardingStore: deps.onboardingStore,
          accountStore: deps.accountStore,
          subscriptionStore: deps.subscriptionStore,
          soundRepository: deps.soundRepository,
          soundPlayer: deps.soundPlayer,
          practiceStore: deps.practiceStore,
          heartLedger: deps.heartLedger,
          pauseSession: deps.pauseSession,
          pauseRepository: deps.pauseRepository
        )
        .ignoresSafeArea()
        .transition(.opacity)
      case .flow:
        OnboardingCoordinatorView()
          .transition(.opacity)
      }
    }
    .animation(.bloom, value: phase)
    .environment(\.accountStore, deps.accountStore)
    .environment(\.onboardingStore, deps.onboardingStore)
    .environment(\.onboardingRemote, deps.onboardingRemote)
    .environment(\.subscriptionStore, deps.subscriptionStore)
    .environment(\.soundContentRepository, deps.soundRepository)
    .environment(\.practiceStore, deps.practiceStore)
    .environment(\.heartLedger, deps.heartLedger)
    .task { await bootstrap() }
    // Returning to the foreground retries the practice journal's offline
    // queue and picks up sessions recorded on other installs.
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active, didRestore, deps.accountStore.isSignedIn else { return }
      Task { await deps.practiceStore.refresh() }
    }
  }

  private func bootstrap() async {
    await deps.accountStore.restore()
    if deps.accountStore.isSignedIn {
      if let profile = try? await deps.onboardingRemote.fetchProfile() {
        deps.onboardingStore.hydrate(
          quizAnswers: profile.quizAnswers,
          mindTree: profile.mindTree,
          completed: profile.completed
        )
      }
      await deps.practiceStore.refresh()
    }
    withAnimation(.bloom) { didRestore = true }
  }
}

#Preview("App root") {
  AppRootView()
}
