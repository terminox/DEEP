import UIKit
import SwiftUI

/// The Global Pause lobby — a fully-UIKit screen whose backdrop IS the shared
/// `GlobalPauseCardView`, installed by the card-lift transition and handed
/// back on dismiss. On top of that card ride the phase overlay (SwiftUI) and
/// the glass close button; the controller itself conducts the event: it
/// observes `session.phase` and drives the globe (decelerate / resume /
/// placement / interactivity) and the event audio through each transition.
final class GlobalPauseLobbyController: UIViewController {
  private let session: GlobalPauseSession
  private let scene: GlobalPauseEarthScene
  private let audio: any GlobalPauseAudioPlaying
  private let reminder: any PauseReminding
  private let onClose: () -> Void

  /// Faded in late by the present animator, out early by the dismiss animator.
  let closeButton: UIButton

  private(set) var card: GlobalPauseCardView?

  private var overlayHost: UIHostingController<AnyView>?
  /// Last phase the choreography ran for, so observation re-fires (any state
  /// change on the session) don't restart animations mid-flight.
  private var appliedPhaseKind: PhaseKind?
  private var isTornDown = false

  private enum PhaseKind: Equatable {
    case loading, offHours, lobby, welcome, meditation, feedback

    init(_ phase: PausePhase) {
      switch phase {
      case .loading: self = .loading
      case .offHours: self = .offHours
      case .lobby: self = .lobby
      case .welcome: self = .welcome
      case .meditation: self = .meditation
      case .feedback: self = .feedback
      }
    }
  }

  init(
    session: GlobalPauseSession,
    scene: GlobalPauseEarthScene,
    audio: any GlobalPauseAudioPlaying,
    reminder: any PauseReminding,
    onClose: @escaping () -> Void
  ) {
    self.session = session
    self.scene = scene
    self.audio = audio
    self.reminder = reminder
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
    // The lobby covers the whole screen; it owns the status bar while up
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

    installOverlay()

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

    // The event begins: presence + live polling for as long as we're here.
    session.enterLobby()
    observePhase()
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
  }

  // MARK: - Phase overlay

  private func installOverlay() {
    let root = AnyView(
      GlobalPauseLobbyOverlayView()
        .environment(\.globalPauseSession, session)
        .environment(\.pauseReminder, reminder)
        // iOS 26 quirk: hosting SwiftUI inside this custom-presented
        // controller arrives with `isEnabled == false` in the environment —
        // Buttons silently dead while gestures still fire. Re-enable at the
        // root; per-control `.disabled(...)` below still wins locally.
        .environment(\.isEnabled, true)
        .preferredColorScheme(.light)
    )
    let host = UIHostingController(rootView: root)
    // A clear hosting view already hit-tests selectively: SwiftUI reports
    // nil over empty/transparent regions (those touches fall through to the
    // globe card beneath) and claims only real content — buttons, chips, the
    // feedback scroll view. No custom filtering needed, and filtering by
    // "hit == hosting view" would actually kill buttons, since SwiftUI
    // routes their gestures through the hosting view itself.
    host.view.backgroundColor = .clear

    addChild(host)
    host.view.frame = view.bounds
    host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(host.view)
    host.didMove(toParent: self)

    overlayHost = host
  }

  /// Re-arming observation loop on the `@Observable` session — the same
  /// pattern `MainTabController.observeHasTrack` uses.
  private func observePhase() {
    guard !isTornDown else { return }
    let phase = withObservationTracking {
      session.phase
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in self?.observePhase() }
    }
    apply(phase: phase)
  }

  /// The conductor: globe + audio per phase. Runs once per phase *kind* —
  /// observation may re-fire for unrelated session changes.
  private func apply(phase: PausePhase) {
    let kind = PhaseKind(phase)
    guard kind != appliedPhaseKind, let card else { return }
    let isFirstApply = appliedPhaseKind == nil
    appliedPhaseKind = kind

    switch kind {
    case .loading, .offHours:
      // Quiet browsing outside the event: turning globe, no music.
      scene.interaction.resumeSpin(over: 1)
      card.setGlobeInteractive(true)
      card.resetGlobePhasePlacement(animated: !isFirstApply)
      audio.stop()

    case .lobby:
      scene.interaction.resumeSpin(over: 1)
      card.setGlobeInteractive(true)
      card.resetGlobePhasePlacement(animated: !isFirstApply)
      if let url = session.schedule?.lobbyAudioURL {
        audio.playLobbyLoop(url: url, volume: 0.6)
      }

    case .welcome:
      // The loop pre-quiets under the welcome lines; meditation replaces it.
      if let url = session.schedule?.lobbyAudioURL, audio.mode != .lobbyLoop {
        audio.playLobbyLoop(url: url, volume: 0.6)
      }
      audio.setLobbyVolume(0.3, fadeDuration: 2)

    case .meditation:
      // The world stills together: globe decelerates to rest, drags and
      // country taps sleep, and the live stream joins at the shared offset.
      scene.interaction.decelerateToRest(over: 5)
      card.setGlobeInteractive(false)
      card.resetGlobePhasePlacement(animated: !isFirstApply)
      if let url = session.schedule?.meditationAudioURL {
        audio.playMeditation(
          url: url,
          startingAt: session.meditationElapsed,
          duration: session.meditationDuration
        )
      }

    case .feedback:
      // Motion returns; the globe lifts into a header over the feedback flow.
      scene.interaction.resumeSpin(over: 3)
      card.setGlobeInteractive(true)
      card.setGlobePhasePlacement(scale: 0.62, offsetY: -0.28, animated: !isFirstApply)
      if let url = session.schedule?.lobbyAudioURL {
        audio.playLobbyLoop(url: url, volume: 0.25)
      }
    }
  }

  // MARK: - Teardown

  /// Ends the event for this visitor: audio off, presence released, globe
  /// restored to its feed rest (spinning, natural placement). Idempotent —
  /// runs from the close button and again from the dismissal safety net.
  private func tearDown() {
    guard !isTornDown else { return }
    isTornDown = true
    audio.stop()
    session.leaveLobby()
    scene.interaction.resumeSpin(over: 1)
    card?.setGlobeInteractive(true)
    card?.resetGlobePhasePlacement(animated: false)
  }

  // MARK: - Card handoff

  /// Adopts the shared card as the screen's backdrop, beneath the overlay and
  /// close button.
  func install(_ card: GlobalPauseCardView) {
    self.card = card
    card.frame = view.bounds
    card.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.insertSubview(card, at: 0)
    // The lobby may open mid-event; conduct the current phase immediately.
    apply(phase: session.phase)
  }

  func uninstallCard() -> GlobalPauseCardView? {
    guard let card else { return nil }
    self.card = nil
    card.removeFromSuperview()
    return card
  }

  /// Safety net: if a dismissal ever bypasses the animator's handoff, the feed
  /// must not lose its card (or keep ghost audio / presence).
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

#Preview("Lobby") {
  let scene = GlobalPauseEarthScene.preview
  let card = GlobalPauseCardView(scene: scene)
  card.applyRestState(isLobby: true)

  let lobby = GlobalPauseLobbyController(
    session: .preview(phase: .lobby),
    scene: scene,
    audio: MockGlobalPauseAudioPlayer(),
    reminder: MockPauseReminder(),
    onClose: {}
  )
  lobby.loadViewIfNeeded()
  lobby.install(card)
  lobby.closeButton.alpha = 1
  return lobby
}
