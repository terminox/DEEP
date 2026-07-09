import UIKit
import SwiftUI

/// The Global Pause lobby — a fully-UIKit screen whose content IS the shared
/// `GlobalPauseCardView`, installed by the card-lift transition and handed
/// back on dismiss. The controller itself is a thin shell: cream backdrop,
/// glass close button, status-bar ownership.
final class GlobalPauseLobbyController: UIViewController {
  private let onClose: () -> Void

  /// Faded in late by the present animator, out early by the dismiss animator.
  let closeButton: UIButton

  private(set) var card: GlobalPauseCardView?

  init(onClose: @escaping () -> Void) {
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

    closeButton.alpha = 0
    closeButton.accessibilityLabel = "Close"
    closeButton.addAction(UIAction { [onClose] _ in onClose() }, for: .touchUpInside)
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(closeButton)
    NSLayoutConstraint.activate([
      closeButton.widthAnchor.constraint(equalToConstant: 44),
      closeButton.heightAnchor.constraint(equalToConstant: 44),
      closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
      closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: .edge)
    ])
  }

  // MARK: - Card handoff

  /// Adopts the shared card as the screen's content, beneath the close button.
  func install(_ card: GlobalPauseCardView) {
    self.card = card
    card.frame = view.bounds
    card.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.insertSubview(card, at: 0)
  }

  func uninstallCard() -> GlobalPauseCardView? {
    guard let card else { return nil }
    self.card = nil
    card.removeFromSuperview()
    return card
  }

  /// Safety net: if a dismissal ever bypasses the animator's handoff, the feed
  /// must not lose its card.
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    guard presentingViewController == nil,
          let card = uninstallCard(),
          let slot = card.homeSlot
    else { return }
    slot.adopt(card)
    card.endGlobeFlight(isLobby: false)
    card.applyRestState(isLobby: false)
  }
}

#Preview("Lobby") {
  let scene = GlobalPauseEarthScene.preview
  let card = GlobalPauseCardView(scene: scene)
  card.applyRestState(isLobby: true)

  let lobby = GlobalPauseLobbyController(onClose: {})
  lobby.loadViewIfNeeded()
  lobby.install(card)
  lobby.closeButton.alpha = 1
  return lobby
}
