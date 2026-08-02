import UIKit
import SwiftUI

/// The presented Global Pause experience — a fully-UIKit screen whose backdrop
/// IS the shared `GlobalPauseCardView`, installed by the card-lift transition
/// and handed back on dismiss. The experience is meditation-only: it starts
/// the moment the card is installed (synced to the world during the nightly
/// window, solo otherwise), and completing it crossfades into the reflection
/// screen, which silently hands the card home behind its opaque atmosphere.
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
  /// Wall-clock completion fallback — covers a missing or failed audio URL.
  private var completionTask: Task<Void, Never>?

  private var hasStartedMeditation = false
  private var hasCompleted = false
  private var isTornDown = false

  /// True when the nightly meditation is live and this visitor joined it at
  /// the shared offset; false for a solo pass from the top.
  private var isSynced = false
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

  override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

  override func viewDidLoad() {
    super.viewDidLoad()
    // Never a black hole even if the card is briefly absent.
    view.backgroundColor = .moonCream

    closeButton.alpha = 0
    closeButton.accessibilityLabel = "Close"
    closeButton.addAction(
      UIAction { [weak self] _ in
        // Tear down before the dismiss animation so the globe hands back to
        // the feed at its natural placement, already spinning.
        self?.tearDown()
        self?.onClose()
      },
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

  /// Feeds each live poll into the globe: country counts light the surface
  /// (`EarthGlowStore` lerps them in), fresh joins ring outward as ripples.
  private func observeLiveGlobe() {
    guard !isTornDown else { return }
    let byCountry = withObservationTracking {
      session.participantsByCountry
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in self?.observeLiveGlobe() }
    }
    scene.glow.participantsByCountry = byCountry
    for iso in session.consumeNewJoins() {
      scene.ripples.emit(forISO: iso)
    }
    // The participant count refreshes on the same poll; keep the meditation
    // overlay's "N meditating with you" honest.
    if let overlayHost, !hasCompleted {
      overlayHost.rootView = makeOverlayRoot()
    }
  }

  // MARK: - Meditation

  /// One-shot: begins the meditation the moment the card is installed.
  /// Synced during the nightly window (joining the live stream at the shared
  /// offset), solo from zero any other time.
  private func startMeditation() {
    guard !hasStartedMeditation, !isTornDown else { return }
    hasStartedMeditation = true

    isSynced = session.phase == .meditation
    duration = session.meditationDuration > 0 ? session.meditationDuration : 600
    var offset: TimeInterval = 0
    if isSynced {
      offset = session.meditationElapsed
      if offset >= duration {
        // Latecomer past the end — the shared stream is over; a solo pass
        // from the top instead.
        isSynced = false
        offset = 0
      }
    }
    // Synced recovery re-seeks to the live edge; solo recovery resumes in
    // place (the player falls back to `play()` when the provider is nil).
    audio.meditationOffsetProvider = isSynced
      ? { [weak session] in session?.meditationElapsed ?? 0 }
      : nil

    // The world stills: globe decelerates to rest, drags and country taps
    // sleep for the duration.
    scene.interaction.decelerateToRest(over: 5)
    card?.setGlobeInteractive(false)
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
        participantCount: session.participantCount
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
  /// clock (primary), the phase engine (synced only — covers a realign
  /// zeroing the audio clock near the end), and a wall-clock fallback
  /// (covers a missing or failed audio URL).
  private func armCompletion(offset: TimeInterval) {
    observeAudioCompletion()
    if isSynced { observePhaseCompletion() }
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

  /// Synced only: the phase engine crossing into feedback ends the shared
  /// meditation even if the audio clock never quite reaches the end.
  private func observePhaseCompletion() {
    guard !isTornDown, !hasCompleted else { return }
    let phase = withObservationTracking {
      session.phase
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in self?.observePhaseCompletion() }
    }
    if phase == .feedback {
      presentReflection()
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
    card?.setGlobeInteractive(true)
    card?.resetGlobePhasePlacement(animated: false)
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
    session: .preview(phase: .meditation),
    scene: scene,
    audio: MockGlobalPauseAudioPlayer.meditating,
    onClose: {}
  )
  controller.loadViewIfNeeded()
  controller.install(card)
  controller.closeButton.alpha = 1
  return controller
}
