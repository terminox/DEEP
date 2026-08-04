import SwiftUI

/// The app's SwiftUI root and composition point. It owns `AppDependencies`
/// (the API client + all app-lifetime stores) and decides among three phases:
///
///  - **restoring** — a calm, breathing launch beat while any saved session is
///    confirmed with the backend, so a returning user never flashes the welcome
///    screen.
///  - **flow** — the onboarding + auth flow (welcome → quiz → mind tree →
///    sign-up → shaping, or welcome → log in).
///  - **main** — the UIKit tab shell, once the user is authenticated *and* their
///    onboarding is complete.
///
/// One moonCream + atmosphere backdrop persists beneath every phase, so
/// hand-offs crossfade atmosphere-to-atmosphere and the soft drift's veil blur
/// only ever touches the loading text — never `AtmosphereBackground`, whose
/// internally blurred orbs would rasterize into hard-edged discs under an
/// animated outer blur. Leaving the loading beat is a staged exhale that
/// `bootstrap()` conducts explicitly — never a removal transition, which
/// SwiftUI skips outright on the beat's self-updating breath timeline: the
/// text exhales away in place, the destination surfaces beneath its tail
/// after a beat of stillness (the flow rising in on an unveiled soft drift,
/// the main shell as a plain crossfade — blurring the onboarding's live video
/// or the hosted UIKit tab shell would force an offscreen pass every frame),
/// and the by-then invisible beat is unmounted once everything settles.
/// Dependencies are injected into the environment for all branches.
struct AppRootView: View {
  @State private var deps = AppDependencies()
  @State private var didRestore = false
  /// Sends the launch beat's breathing text away; the beat itself stays
  /// mounted (transparent) until `beatDismissed`, so its exhale is a plain
  /// state animation rather than a skippable exit transition.
  @State private var beatExhaled = false
  @State private var beatDismissed = false
  @Environment(\.scenePhase) private var scenePhase

  private enum Phase: Equatable { case restoring, flow, main }

  /// The staged hand-off's single source of truth. Private — these values
  /// choreograph only this screen's launch send-off; the exhale itself keeps
  /// the `.exhale` motion token's tempo.
  private enum Handoff {
    /// The quiet between the text beginning its exhale and the destination
    /// starting to surface beneath it.
    static let stillness: TimeInterval = 0.55
    /// Margin after the destination starts arriving before the by-then
    /// invisible beat is unmounted.
    static let settle: TimeInterval = 0.3
  }

  private var phase: Phase {
    guard didRestore else { return .restoring }
    return (deps.accountStore.isSignedIn && deps.onboardingStore.hasCompletedOnboarding)
      ? .main : .flow
  }

  var body: some View {
    ZStack {
      // The one persistent backdrop: every phase renders over this identical
      // moonCream + atmosphere, so crossfades never dip and no transition ever
      // blurs the atmosphere itself. Behind the opaque main shell the drift
      // settles, so the resting orbs cost nothing per frame.
      Color.moonCream.ignoresSafeArea()
      AtmosphereBackground(animated: phase != .main)

      switch phase {
      case .restoring:
        Color.clear
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
          pauseRepository: deps.pauseRepository,
          imageLoader: deps.imageLoader
        )
        .ignoresSafeArea()
        .transition(.opacity)
      case .flow:
        OnboardingCoordinatorView()
          .transition(.softDrift(veils: false))
      }

      // Above the destination, so the exhaling text finishes over whatever
      // surfaces beneath it.
      if !beatDismissed {
        BreatheLoadingView(drawsBackdrop: false, exhaled: beatExhaled)
      }
    }
    .animation(.hush, value: phase)
    .environment(\.accountStore, deps.accountStore)
    .environment(\.onboardingStore, deps.onboardingStore)
    .environment(\.onboardingRemote, deps.onboardingRemote)
    .environment(\.subscriptionStore, deps.subscriptionStore)
    .environment(\.soundContentRepository, deps.soundRepository)
    .environment(\.practiceStore, deps.practiceStore)
    .environment(\.heartLedger, deps.heartLedger)
    .environment(\.imageLoader, deps.imageLoader)
    .task { await bootstrap() }
    // Returning to the foreground retries the practice journal's offline
    // queue and picks up sessions recorded on other installs.
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active, didRestore, deps.accountStore.isSignedIn else { return }
      Task { await deps.practiceStore.refresh() }
    }
  }

  private func bootstrap() async {
    // Hold the breathing beat at least this long, however fast restore runs —
    // a flash of the loading screen reads as a glitch, not a breath.
    async let floor: Void? = try? Task.sleep(for: .breatheFloor)
    await deps.accountStore.restore()
    if deps.accountStore.isSignedIn {
      // Concurrent: neither depends on the other, and against an unreachable
      // dev host their timeouts overlap instead of stacking.
      async let refreshed: Void = deps.practiceStore.refresh()
      if let profile = try? await deps.onboardingRemote.fetchProfile() {
        deps.onboardingStore.hydrate(
          quizAnswers: profile.quizAnswers,
          mindTree: profile.mindTree,
          completed: profile.completed
        )
      }
      await refreshed
    }
    _ = await floor
    // The staged send-off: text exhales in place, the destination surfaces
    // through its tail after a beat of stillness, and the transparent shell
    // is dismissed once settled. Conducted here because a removal transition
    // would be skipped over the beat's self-updating breath timeline.
    withAnimation(.exhale) { beatExhaled = true }
    try? await Task.sleep(for: .seconds(Handoff.stillness))
    withAnimation(.hush) { didRestore = true }
    try? await Task.sleep(for: .seconds(Handoff.settle))
    beatDismissed = true
  }
}

#Preview("App root") {
  AppRootView()
}
