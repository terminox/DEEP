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

  private var hasStartedMeditation = false
  private var hasCompleted = false
  private var isTornDown = false
  /// The overlay arrives empty and cascades in once the card-lift has landed,
  /// so nothing rides the flight but the globe.
  private var isOverlayRevealed = false
  /// Join sparks wait behind this gate until the turn-to-you has settled —
  /// otherwise the user's own spark plays mid-flight or mid-turn and is missed.
  private var joinsGateOpen = false

  private var duration: TimeInterval = 600

  init(
    session: GlobalPauseSession,
    scene: GlobalPauseEarthScene,
    audio: any GlobalPauseAudioPlaying,
    onClose: @escaping () -> Void
  ) {
    self.session = session
    self.scene = scene
    self.audio = audio
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
    // Night falls with the cascade — one composed arrival. A latecomer who
    // landed straight in reflection stays on cream.
    if !hasCompleted {
      card?.setNightMode(true, animated: true)
      UIView.animate(withDuration: .hush) { self.showsLightStatusBar = true }
    }
    turnGlobeHome()
  }

  /// The flight has landed: turn the world to *you* and light your home glow,
  /// then open the joins gate so sparks (including your own) play where the
  /// user is actually looking.
  private func turnGlobeHome() {
    if let home = session.myLocation {
      scene.interaction.orient(toLatDeg: home.lat, lonDeg: home.lon, over: 2.5)
      scene.glow.homeLocation = home
    }
    Task { [weak self] in
      try? await Task.sleep(for: .seconds(2.5))
      guard let self, !self.isTornDown else { return }
      self.joinsGateOpen = true
      self.scene.enqueueJoins(self.session.consumeNewJoins())
    }
  }

  /// Feeds each live poll into the globe: located participants light the
  /// surface as lat/lon points (unlocated ones as country blobs), and fresh
  /// joins spark + ring at their coordinates. Older servers send no locations
  /// at all — the globe then keeps the classic country glow.
  private func observeLiveGlobe() {
    guard !isTornDown else { return }
    let (byCountry, locations, unlocated) = withObservationTracking {
      (session.participantsByCountry, session.participantLocations, session.unlocatedByCountry)
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in self?.observeLiveGlobe() }
    }
    if locations.isEmpty && unlocated.isEmpty {
      scene.glow.participantsByCountry = byCountry
    } else {
      scene.glow.locations = locations
      scene.glow.unlocatedByCountry = unlocated
    }
    // The server's IP-resolved home can arrive after the first render —
    // keep the home glow seated on the freshest value.
    if let home = session.myLocation, scene.glow.homeLocation != home {
      scene.glow.homeLocation = home
    }
    if joinsGateOpen {
      scene.enqueueJoins(session.consumeNewJoins())
    }
    // The participant count refreshes on the same poll; keep the meditation
    // overlay's "N meditating with you" honest.
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

    // The world stills — idle drift and momentum die — but the globe stays
    // touchable: you can turn it to look for your own light (drags pass
    // through the held gate by design), and country taps still reveal names.
    scene.interaction.decelerateToRest(over: 5)
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
    // Night lifts on the same beat, so the reverse flight flies a cream card.
    card?.setNightMode(false, animated: true)
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

    // A leave confirmation still up when the meditation ends would strand the
    // user over the reflection — retire it.
    leaveAlert?.dismiss(animated: true)
    leaveAlert = nil

    let root = AnyView(
      GlobalPauseReflectionView(onDone: { [weak self] in self?.finishSession() })
        .environment(\.globalPauseSession, session)
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

    let animator = UIViewPropertyAnimator(duration: 1.5, curve: .easeInOut) { [weak self] in
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
    audio.stop()
    session.leaveSession()
    scene.interaction.resumeSpin(over: 1)
    scene.glow.homeLocation = nil
    card?.resetGlobePhasePlacement(animated: false)
    // The idempotent funnel every terminal path hits — the lounge must never
    // receive a night card.
    card?.setNightMode(false, animated: false)
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

#Preview("Session") {
  let scene = GlobalPauseEarthScene.preview
  let card = GlobalPauseCardView(scene: scene)
  card.applyRestState(isLobby: true)

  let controller = GlobalPauseSessionController(
    session: .preview(live: true),
    scene: scene,
    audio: MockGlobalPauseAudioPlayer.meditating,
    onClose: {}
  )
  controller.loadViewIfNeeded()
  controller.install(card)
  controller.closeButton.alpha = 1
  return controller
}
