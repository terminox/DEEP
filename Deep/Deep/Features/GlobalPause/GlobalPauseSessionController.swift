import UIKit
import SwiftUI

/// The presented Global Pause experience — a fully-UIKit screen whose backdrop
/// IS the shared `GlobalPauseCardView`, installed by the card-lift transition
/// and handed back on dismiss. The experience is the live meditation only —
/// it joins the shared stream at the synced offset the moment the card is
/// installed — and completing it crossfades into the reflection screen, which
/// silently hands the card home behind its opaque atmosphere.
final class GlobalPauseSessionController: UIViewController {
  private let session: GlobalPauseSession
  private let scene: GlobalPauseEarthScene
  private let audio: any GlobalPauseAudioPlaying
  /// The shared stores the ending ritual reads. UIKit severs the SwiftUI
  /// environment, so they are handed in and re-injected into the hosted
  /// completion view by hand.
  private let practiceStore: any PracticeStore
  private let heartLedger: HeartLedger
  private let gardenStore: GardenStore
  private let continuityWitness: ContinuityWitness
  /// The reflection's composer heads its card with the member's own name, so
  /// they see who they are posting as before they commit.
  private let accountStore: any AccountStore
  /// The reward ritual draws the plant's mascot artwork; without the real
  /// loader it reaches the throwaway default and falls back to a gradient.
  private let imageLoader: any ImageLoading
  private let onClose: () -> Void

  /// Faded in late by the present animator, out early by the dismiss animator.
  let closeButton: UIButton

  private(set) var card: GlobalPauseCardView?

  private var overlayHost: UIHostingController<AnyView>?
  private var reflectionHost: UIHostingController<AnyView>?
  /// The 1.5 s meditation → reflection crossfade; stored so `tearDown()` can
  /// cancel it if a dismissal races the fade.
  private var reflectionFadeAnimator: UIViewPropertyAnimator?
  /// The mid-meditation leave confirmation, retired automatically if the
  /// meditation ends while it is still up.
  private weak var leaveAlert: UIAlertController?
  /// Wall-clock completion fallback — covers a missing or failed audio URL.
  private var completionTask: Task<Void, Never>?

  /// The arrival turn: the world spins for this long and stops on you.
  private static let arrivalTurn: TimeInterval = 60
  /// The self-spin gate shuts a beat before the turn lands, so idle drift has
  /// nothing left to restart with and the globe stays exactly where it stopped.
  /// Invisible while the turn owns the globe — drift is skipped anyway.
  private static let arrivalGate: TimeInterval = 55
  /// When the arrival must land. Stamped once the card-lift has, so the minute
  /// is measured from what the user sees, not from the tap.
  private var arrivalDeadline: Date?
  /// The location the in-flight arrival is aimed at, so a corrected one can be
  /// spotted. Nil until the arrival is armed.
  private var arrivalTarget: PauseJoinPoint?
  /// Fires the user's own join spark as the globe lands on them.
  private var ownJoinTask: Task<Void, Never>?

  private var hasStartedMeditation = false
  private var hasCompleted = false
  private var isTornDown = false
  /// The overlay arrives empty and cascades in once the card-lift has landed,
  /// so nothing rides the flight but the globe.
  private var isOverlayRevealed = false
  /// The world's lights wait behind this gate until the card-lift has landed —
  /// otherwise the first poll lights the whole world mid-flight, and the glows
  /// have finished rising before anyone is looking at them.
  private var joinsGateOpen = false

  private var duration: TimeInterval = 600

  init(
    session: GlobalPauseSession,
    scene: GlobalPauseEarthScene,
    audio: any GlobalPauseAudioPlaying,
    practiceStore: any PracticeStore,
    heartLedger: HeartLedger,
    gardenStore: GardenStore,
    continuityWitness: ContinuityWitness,
    accountStore: any AccountStore,
    imageLoader: any ImageLoading,
    onClose: @escaping () -> Void
  ) {
    self.session = session
    self.scene = scene
    self.audio = audio
    self.practiceStore = practiceStore
    self.heartLedger = heartLedger
    self.gardenStore = gardenStore
    self.continuityWitness = continuityWitness
    self.accountStore = accountStore
    self.imageLoader = imageLoader
    self.onClose = onClose

    // Liquid Glass on iOS 26, hand-blended frosted capsule below — the UIKit
    // twin of `GlassCloseButton`'s fallback.
    var config: UIButton.Configuration
    if #available(iOS 26.0, *) {
      config = .glass()
    } else {
      config = .plain()
      config.background.backgroundColor = UIColor.white.withAlphaComponent(0.45)
      config.background.strokeColor = UIColor.white.withAlphaComponent(0.5)
      config.background.strokeWidth = 0.5
    }
    config.image = UIImage(
      systemName: "xmark",
      withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
    )
    config.baseForegroundColor = .deepPlum
    config.cornerStyle = .capsule
    closeButton = UIButton(configuration: config)

    super.init(nibName: nil, bundle: nil)
    overrideUserInterfaceStyle = .light
    // The session covers the whole screen; it owns the status bar while up
    // (dark content over the cream atmosphere).
    modalPresentationCapturesStatusBarAppearance = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// Dark over the cream arrival and reflection; light once night has fallen.
  /// Assigned inside animation blocks so the flip rides the surrounding fade.
  private var showsLightStatusBar = false {
    didSet { setNeedsStatusBarAppearanceUpdate() }
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    showsLightStatusBar ? .lightContent : .darkContent
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    // Never a black hole even if the card is briefly absent.
    view.backgroundColor = .moonCream

    closeButton.alpha = 0
    closeButton.accessibilityLabel = "Close"
    closeButton.addAction(
      UIAction { [weak self] _ in self?.requestClose() },
      for: .touchUpInside
    )
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(closeButton)
    NSLayoutConstraint.activate([
      closeButton.widthAnchor.constraint(equalToConstant: 44),
      closeButton.heightAnchor.constraint(equalToConstant: 44),
      closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
      closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: .edge)
    ])

    // The session begins: presence + live polling for as long as we're here.
    session.enterSession()
    observeLiveGlobe()
  }

  /// The card-lift has landed (UIKit runs this after `completeTransition`):
  /// let the overlay cascade in — pill, count, progress line — so nothing but
  /// the globe ever rides the flight. Once only; an alert dismissing over the
  /// session must not replay the arrival.
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !isOverlayRevealed, !isTornDown else { return }
    isOverlayRevealed = true
    if let overlayHost, !hasCompleted {
      overlayHost.rootView = makeOverlayRoot()
    }
    // The card's backdrop is already night — flip the status bar light with
    // the cascade. A latecomer who landed straight in reflection stays dark
    // over its cream.
    if !hasCompleted {
      UIView.animate(withDuration: .hush) { self.showsLightStatusBar = true }
    }
    turnGlobeHome()
  }

  /// The flight has landed, and the arrival begins: the world keeps turning for
  /// a minute and comes to rest on *you*.
  ///
  /// Two beats, deliberately apart. The world's lights come up early so the
  /// globe turns lit and alive rather than as a dark ball. Your own light is
  /// held to the landing — it flares as the globe stops on you, which is both
  /// the moment worth marking and the only moment your point is guaranteed to
  /// be on the near hemisphere (a ripple emitted on the back face is culled and
  /// simply never draws).
  ///
  /// A latecomer who landed straight in reflection gets none of it: the globe
  /// is behind an opaque screen and the night is over.
  private func turnGlobeHome() {
    guard !hasCompleted else { return }
    arrivalDeadline = Date().addingTimeInterval(Self.arrivalTurn)
    armArrivalTurn()
    Task { [weak self] in
      try? await Task.sleep(for: .seconds(2.5))
      guard let self, !self.isTornDown, !self.hasCompleted else { return }
      self.joinsGateOpen = true
      self.applyLiveGlobe()
    }
  }

  /// Aims the arrival at the user's location, once, and schedules their own
  /// spark for the landing. Re-aims if a better location turns up while the
  /// turn is still well clear of touching down.
  ///
  /// The re-aim is not defensive coding: `enterSession()` seeds `myLocation`
  /// synchronously from the *locale country centroid* so the globe has somewhere
  /// to turn immediately, and the server's IP-resolved point overwrites it on
  /// the first heartbeat. Landing on the centroid of a large country can be 20°
  /// of longitude from where the user actually is — visibly not "on you".
  ///
  /// Nothing to aim at means nothing happens: no turn, no spark. The globe then
  /// drifts and is stilled by the gate, which is what it did before any of this.
  private func armArrivalTurn() {
    guard !isTornDown, !hasCompleted,
          let deadline = arrivalDeadline,
          let home = session.myLocation
    else { return }
    let remaining = max(0, deadline.timeIntervalSinceNow)

    if arrivalTarget == nil {
      arrivalTarget = home
      scene.interaction.settle(onLatDeg: home.lat, lonDeg: home.lon, over: remaining)
      ownJoinTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(remaining))
        guard let self, !self.isTornDown, !self.hasCompleted else { return }
        // Flare it from here rather than wait on the server's echo of the first
        // heartbeat, which can be a whole poll late. `GlobalPauseSession`
        // swallows that echo.
        if let home = self.session.myLocation {
          self.scene.enqueueOwnJoin(home)
        }
      }
      return
    }

    // A correction, not a fresh arrival: same landing time, and no extra lap —
    // but still taken forward, so the globe never reverses mid-turn.
    guard home != arrivalTarget, remaining > 10 else { return }
    arrivalTarget = home
    scene.interaction.settle(
      onLatDeg: home.lat, lonDeg: home.lon, over: remaining, minimumTurns: 0
    )
  }

  /// Keeps the globe subscribed to the live poll. The read *is* the
  /// subscription: every input the globe follows is touched on every pass —
  /// including while the joins gate is still shut — or the loop stops waking
  /// and the world never lights at all.
  private func observeLiveGlobe() {
    guard !isTornDown else { return }
    withObservationTracking {
      _ = session.participantsByCountry
      // Not a globe input — the overlay's continent row rides the same poll,
      // and this loop is what rebuilds it.
      _ = session.participantsByContinent
      _ = session.participantLocations
      _ = session.unlocatedByCountry
      // The arrival follows this one too: it aims the turn, and a corrected
      // location has to be able to wake the loop on its own.
      _ = session.myLocation
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in self?.observeLiveGlobe() }
    }
    applyLiveGlobe()
  }

  /// Feeds the latest poll into the globe: located participants light the
  /// surface as lat/lon points (unlocated ones as country blobs), and fresh
  /// joins spark + ring at their coordinates. Older servers send no locations
  /// at all — the globe then keeps the classic country glow.
  ///
  /// Every light waits behind the same gate the joins do. Otherwise the first
  /// poll — which lands while the card is still in flight — quietly lights the
  /// whole world, and by the time the gate opens ~3s later the glows have
  /// finished rising and each spark flares onto an already-lit planet. Gate
  /// open, the lights and the first sparks land in one turn: every arrival
  /// rides its own glow coming up.
  ///
  /// Called directly when the gate opens — never `observeLiveGlobe()`, which
  /// would install a second self-renewing tracking chain.
  private func applyLiveGlobe() {
    guard !isTornDown else { return }
    if joinsGateOpen {
      let locations = session.participantLocations
      let unlocated = session.unlocatedByCountry
      if locations.isEmpty && unlocated.isEmpty {
        scene.glow.participantsByCountry = session.participantsByCountry
      } else {
        scene.glow.locations = locations
        scene.glow.unlocatedByCountry = unlocated
      }
      // The server's IP-resolved home can arrive after the first render —
      // keep the home glow seated on the freshest value.
      if let home = session.myLocation, scene.glow.homeLocation != home {
        scene.glow.homeLocation = home
      }
      scene.enqueueJoins(session.consumeNewJoins())
    }
    // The location the arrival aims at rides the same poll. This is also the
    // path that arms it at all when no location existed as the card landed.
    armArrivalTurn()
    // The participant count refreshes on the same poll; keep the meditation
    // overlay's "N meditating with you" honest — that has nothing to do with
    // the globe's gate.
    if let overlayHost, !hasCompleted {
      overlayHost.rootView = makeOverlayRoot()
    }
  }

  // MARK: - Meditation

  /// One-shot: joins the live meditation the moment the card is installed,
  /// at the shared offset. A latecomer past the end goes straight to
  /// reflection — the shared stream is over.
  private func startMeditation() {
    guard !hasStartedMeditation, !isTornDown else { return }
    hasStartedMeditation = true

    duration = session.meditationDuration > 0 ? session.meditationDuration : 600
    let offset = session.meditationElapsed
    guard offset < duration else {
      presentReflection()
      return
    }
    // Recovery (interruption, stall) re-seeks to the live edge.
    audio.meditationOffsetProvider = { [weak session] in
      session?.meditationElapsed ?? 0
    }

    // Hand the globe over to the arrival: the turn armed once the card lands
    // owns the motion for the next minute, and this shuts the self-spin down
    // underneath it so drift has nothing left to restart with when the turn
    // touches down — the globe stays exactly where it stopped. Invisible while
    // the turn runs (drift is skipped outright), and the fallback that stills
    // the globe anyway if no location is ever resolved to aim at.
    //
    // The globe stays touchable throughout: you can turn it to look for your
    // own light (drags pass through the held gate by design, and cancel the
    // arrival — the user always wins), and country taps still reveal names.
    scene.interaction.decelerateToRest(over: Self.arrivalGate)
    card?.resetGlobePhasePlacement(animated: false)

    if let url = session.schedule?.meditationAudioURL {
      audio.playMeditation(url: url, startingAt: offset, duration: duration)
    }

    installOverlay()
    armCompletion(offset: offset)
  }

  private func makeOverlayRoot() -> AnyView {
    AnyView(
      GlobalPauseMeditationView(
        audio: audio,
        duration: duration,
        participantCount: session.participantCount,
        continents: ContinentPresence.row(from: session.participantsByContinent),
        revealed: isOverlayRevealed
      )
      // iOS 26 quirk: hosting SwiftUI inside this custom-presented
      // controller arrives with `isEnabled == false` in the environment —
      // Buttons silently dead while gestures still fire. Re-enable at the
      // root; per-control `.disabled(...)` below still wins locally.
      .environment(\.isEnabled, true)
      .preferredColorScheme(.light)
    )
  }

  private func installOverlay() {
    let host = UIHostingController(rootView: makeOverlayRoot())
    // A clear hosting view already hit-tests selectively: SwiftUI reports
    // nil over empty/transparent regions (those touches fall through to the
    // globe card beneath) and claims only real content. The meditation view
    // is entirely hit-transparent, so every touch reaches the globe.
    host.view.backgroundColor = .clear

    addChild(host)
    host.view.frame = view.bounds
    host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.insertSubview(host.view, belowSubview: closeButton)
    host.didMove(toParent: self)

    overlayHost = host
  }

  // MARK: - Completion

  /// Three idempotent triggers funnel into `presentReflection()`: the audio
  /// clock (primary), the live window closing (covers a realign zeroing the
  /// audio clock near the end), and a wall-clock fallback (covers a missing
  /// or failed audio URL).
  private func armCompletion(offset: TimeInterval) {
    observeAudioCompletion()
    observeLiveCompletion()
    let delay = max(0, duration - offset) + 2
    completionTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(delay))
      guard !Task.isCancelled else { return }
      self?.presentReflection()
    }
  }

  /// Re-arming observation of the player's clock — it publishes ~every 0.5 s
  /// while the meditation runs.
  private func observeAudioCompletion() {
    guard !isTornDown, !hasCompleted else { return }
    let elapsed = withObservationTracking {
      audio.meditationElapsed
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in self?.observeAudioCompletion() }
    }
    if elapsed >= duration - 0.5 {
      presentReflection()
    }
  }

  /// The live window closing ends the shared meditation even if the audio
  /// clock never quite reaches the end.
  private func observeLiveCompletion() {
    guard !isTornDown, !hasCompleted else { return }
    let isLive = withObservationTracking {
      session.isMeditationLive
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in self?.observeLiveCompletion() }
    }
    if !isLive {
      presentReflection()
    }
  }

  // MARK: - Leaving

  /// Mid-meditation close asks first — the session is a live shared moment.
  /// Once reflection has started the button is already disabled, so the
  /// confirm path is effectively live-only; the guard keeps it honest anyway.
  private func requestClose() {
    guard !isTornDown else { return }
    guard !hasCompleted else {
      tearDown()
      onClose()
      return
    }

    let alert = UIAlertController(
      title: "Leave your session?",
      message: "The world keeps breathing — you can rejoin while it's live.",
      preferredStyle: .alert
    )
    alert.addAction(
      UIAlertAction(title: "Leave", style: .destructive) { [weak self] _ in
        self?.confirmLeave()
      }
    )
    alert.addAction(UIAlertAction(title: "Keep breathing", style: .cancel))
    alert.overrideUserInterfaceStyle = .light
    leaveAlert = alert
    present(alert, animated: true)
  }

  /// The screen empties before the flight home: overlay and close button fade
  /// completely, hold a breath, then the reverse card-lift begins with only
  /// the globe on its atmosphere.
  private func confirmLeave() {
    guard !isTornDown else { return }
    guard !hasCompleted else {
      // Reflection raced the alert — the card is already (or about to be)
      // home, so leave via the plain fade.
      tearDown()
      onClose()
      return
    }

    closeButton.isUserInteractionEnabled = false
    UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut]) { [weak self] in
      self?.overlayHost?.view.alpha = 0
      self?.closeButton.alpha = 0
      self?.showsLightStatusBar = false
    } completion: { [weak self] _ in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
        // Tear down before the dismiss animation so the globe hands back to
        // the feed at its natural placement, already spinning.
        self?.tearDown()
        self?.onClose()
      }
    }
  }

  // MARK: - Reflection

  /// The meditation is over: crossfade (1.5 s) into the reflection screen,
  /// then silently hand the card back to its seat behind the opaque cover.
  private func presentReflection() {
    guard !hasCompleted, !isTornDown else { return }
    hasCompleted = true
    completionTask?.cancel()
    completionTask = nil

    // The books as they stand right now, before the claim moves them: the
    // ending ritual animates from here to whatever the grants settle on, and
    // Global Pause has no optimistic credit to read back.
    let before = GlobalPauseRewardSnapshot(
      garden: gardenStore.growth,
      heartBalance: heartLedger.balance,
      heartsEarnedToday: heartLedger.heartsEarnedToday,
      continuityDays: practiceStore.currentStreakDays,
      continuityWitnessedToday: continuityWitness.hasWitnessedToday
    )

    // Claim tonight's attendance award as reflection begins — always; the
    // server judges eligibility, so an ineligible claim resolves to nothing.
    session.claimPauseAward()

    // A leave confirmation still up when the meditation ends would strand the
    // user over the reflection — retire it.
    leaveAlert?.dismiss(animated: true)
    leaveAlert = nil

    let root = AnyView(
      GlobalPauseCompletionView(
        before: before,
        onFinish: { [weak self] in self?.finishSession() }
      )
        .environment(\.globalPauseSession, session)
        .environment(\.heartLedger, heartLedger)
        .environment(\.gardenStore, gardenStore)
        .environment(\.continuityWitness, continuityWitness)
        .environment(\.accountStore, accountStore)
        .environment(\.imageLoader, imageLoader)
        // Same iOS 26 re-enable as the meditation overlay.
        .environment(\.isEnabled, true)
        .preferredColorScheme(.light)
    )
    let host = UIHostingController(rootView: root)
    // The SwiftUI view paints its own opaque atmosphere.
    host.view.backgroundColor = .clear

    addChild(host)
    host.view.frame = view.bounds
    host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    host.view.alpha = 0
    host.view.isUserInteractionEnabled = false
    // Above the meditation overlay AND the close button — the fade covers
    // both.
    view.addSubview(host.view)
    host.didMove(toParent: self)
    reflectionHost = host

    closeButton.isUserInteractionEnabled = false

    // Deliberately longer than `.hush` (the card's handback happens behind
    // it), but on the app's own exhale curve rather than UIKit's mechanical
    // easeInOut.
    let animator = UIViewPropertyAnimator(
      duration: 1.5,
      timingParameters: UICubicTimingParameters.hush
    )
    animator.addAnimations { [weak self] in
      host.view.alpha = 1
      self?.closeButton.alpha = 0
      // The reflection is opaque cream — the status bar goes dark with it.
      self?.showsLightStatusBar = false
    }
    animator.addCompletion { [weak self] position in
      guard position == .end else { return }
      self?.completeReflectionHandback()
    }
    reflectionFadeAnimator = animator
    animator.startAnimation()
  }

  /// The reflection screen is fully opaque now — silently hand the card back
  /// to its lounge seat behind it (mirroring the dismissal safety net), so
  /// the eventual dismiss is a plain fade over an already-seated card.
  private func completeReflectionHandback() {
    reflectionFadeAnimator = nil
    reflectionHost?.view.isUserInteractionEnabled = true
    tearDown()
    if let card = uninstallCard(), let slot = card.homeSlot {
      slot.adopt(card)
      card.endGlobeFlight(isLobby: false)
      card.applyRestState(isLobby: false)
    }
    if let overlayHost {
      overlayHost.willMove(toParent: nil)
      overlayHost.view.removeFromSuperview()
      overlayHost.removeFromParent()
      self.overlayHost = nil
    }
  }

  private func finishSession() {
    onClose()
  }

  // MARK: - Teardown

  /// Ends the session for this visitor: audio off, presence released, globe
  /// restored to its feed rest (spinning, natural placement). Idempotent —
  /// runs from the close button, the reflection handback, and the dismissal
  /// safety net.
  private func tearDown() {
    // A dismissal racing the crossfade: stop it and drop the half-faded
    // reflection so the card is still installed and can fly home.
    if let animator = reflectionFadeAnimator {
      animator.stopAnimation(true)
      reflectionFadeAnimator = nil
      if let reflectionHost {
        reflectionHost.willMove(toParent: nil)
        reflectionHost.view.removeFromSuperview()
        reflectionHost.removeFromParent()
        self.reflectionHost = nil
      }
      closeButton.isUserInteractionEnabled = true
    }
    guard !isTornDown else { return }
    isTornDown = true
    completionTask?.cancel()
    completionTask = nil
    // Leaving mid-arrival: the landing never comes, so neither does the spark.
    ownJoinTask?.cancel()
    ownJoinTask = nil
    arrivalDeadline = nil
    arrivalTarget = nil
    audio.stop()
    session.leaveSession()
    scene.interaction.resumeSpin(over: 1)
    // The world's lights are the session's alone: clear every glow input so
    // the store fades them out over its lerp (the proven home-glow path) while
    // the card flies home, and drop every join queued or already sparking.
    scene.clearJoins()
    // The gate belongs to this visit — a late observation callback must not
    // find it open and re-light a world the session just put out.
    joinsGateOpen = false
    scene.glow.homeLocation = nil
    scene.glow.locations = []
    scene.glow.unlocatedByCountry = [:]
    scene.glow.participantsByCountry = [:]
    card?.resetGlobePhasePlacement(animated: false)
    showsLightStatusBar = false
  }

  // MARK: - Card handoff

  /// Adopts the shared card as the screen's backdrop, beneath the overlay and
  /// close button — and begins the meditation, since card install always
  /// precedes visibility (both the flight and no-slot fallback paths).
  func install(_ card: GlobalPauseCardView) {
    self.card = card
    card.frame = view.bounds
    card.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.insertSubview(card, at: 0)
    startMeditation()
  }

  func uninstallCard() -> GlobalPauseCardView? {
    guard let card else { return nil }
    self.card = nil
    card.removeFromSuperview()
    return card
  }

  /// Safety net: if a dismissal ever bypasses the animator's handoff, the feed
  /// must not lose its card (or keep ghost audio / presence). No-ops after the
  /// reflection handback — the card is already home.
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    guard presentingViewController == nil else { return }
    tearDown()
    guard let card = uninstallCard(), let slot = card.homeSlot else { return }
    slot.adopt(card)
    card.endGlobeFlight(isLobby: false)
    card.applyRestState(isLobby: false)
  }
}

#if DEBUG
#Preview("Session") {
  let scene = GlobalPauseEarthScene.preview
  let card = GlobalPauseCardView(scene: scene)
  card.applyRestState(isLobby: true)

  let controller = GlobalPauseSessionController(
    session: .preview(live: true),
    scene: scene,
    audio: MockGlobalPauseAudioPlayer.meditating,
    practiceStore: MockPracticeStore(),
    heartLedger: .sample,
    gardenStore: .sample,
    continuityWitness: .unwitnessed,
    accountStore: PreviewAccountStore(),
    imageLoader: FixtureImageLoader(),
    onClose: {}
  )
  controller.loadViewIfNeeded()
  controller.install(card)
  controller.closeButton.alpha = 1
  return controller
}
#endif
