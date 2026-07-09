import UIKit
import SwiftUI

/// UIKit twin of `Earth3DView` — the globe unit the fully-UIKit Global Pause
/// card and lobby share. Owns its Metal view and renderer, and draws the soft
/// halo backdrop and the tapped-country reveal around them.
///
/// Composition (back to front):
///   1. Halo backdrop (lavender bloom + blush cradle)
///   2. `EarthMTKView` (the orb itself + bloom post)
///   3. Tap-reveal country name capsule
///
/// **Backdrop sizing is proportional to the orb radius** (`0.2214 × height`),
/// unlike `Earth3DView`'s `min(width, height)`. The orb is height-proportional
/// and centre-anchored, so tying the backdrop to it makes the whole scene
/// scale-continuous through the card-lift transition's transform trick — a
/// `min(w,h)`-sized backdrop would pop when the flight pins the bounds.
///
/// The join-ripple rings (`EarthHaloRipplesOverlay`) are not ported yet —
/// ambient garnish, deferred until the lobby grows real live-participant flow.
final class EarthSceneView: UIView {
  private let glow: EarthGlowStore
  private let interaction: EarthInteraction
  private var renderer: EarthRenderer?
  private var mtkView: EarthMTKView?

  private let halo = RadialGradientView(
    colors: [.lavenderMist.withAlphaComponent(0.32), .lavenderMist.withAlphaComponent(0)]
  )
  private let cradle = RadialGradientView(
    colors: [.blushPowder.withAlphaComponent(0.22), .blushPowder.withAlphaComponent(0)]
  )

  private let revealCapsule = UIVisualEffectView(
    effect: UIBlurEffect(style: .systemUltraThinMaterialLight)
  )
  private let revealLabel = UILabel()
  private var revealTask: Task<Void, Never>?

  /// Gates drag/tap on the orb — false in the feed card (the whole card is the
  /// tap target, so this view must be transparent to hit-testing), true in the
  /// lobby.
  var isInteractive: Bool = false {
    didSet {
      isUserInteractionEnabled = isInteractive
      mtkView?.isUserInteractionEnabled = isInteractive
    }
  }

  init(glow: EarthGlowStore, interaction: EarthInteraction) {
    self.glow = glow
    self.interaction = interaction
    super.init(frame: .zero)

    // Starts non-interactive (feed-card mode); `isInteractive` flips this.
    isUserInteractionEnabled = false

    addSubview(halo)
    addSubview(cradle)

    if let renderer = EarthRenderer(glowStore: glow, interaction: interaction) {
      self.renderer = renderer
      let mtkView = EarthMTKView.configured(renderer: renderer, interaction: interaction)
      mtkView.isUserInteractionEnabled = isInteractive
      addSubview(mtkView)
      self.mtkView = mtkView

      renderer.onFrame = { [glow] time in
        Task { @MainActor in
          glow.tick(time: time)
        }
      }
    }

    configureReveal()
    interaction.onCountryTap = { [weak self] country in
      self?.reveal(country.name)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Layout

  override func layoutSubviews() {
    super.layoutSubviews()

    mtkView?.frame = bounds

    // Everything hangs off the orb's on-screen radius so the scene reads
    // identically at card scale and lobby scale.
    let orbRadius = CGFloat(EarthRendererConstants.orbScreenRadiusFractionOfHeight) * bounds.height
    let center = CGPoint(x: bounds.midX, y: bounds.midY)

    let haloSide = orbRadius * 7.45
    halo.frame = CGRect(
      x: center.x - haloSide / 2,
      y: center.y - 0.18 * orbRadius - haloSide / 2,
      width: haloSide,
      height: haloSide
    )

    let cradleSize = CGSize(width: orbRadius * 4.06, height: orbRadius * 1.58)
    cradle.frame = CGRect(
      x: center.x - cradleSize.width / 2,
      y: center.y + 1.44 * orbRadius - cradleSize.height / 2,
      width: cradleSize.width,
      height: cradleSize.height
    )

    layoutReveal()
  }

  // MARK: - Country reveal

  private func configureReveal() {
    revealLabel.font = .revealTitle
    revealLabel.textColor = .deepPlum.withAlphaComponent(0.85)
    revealCapsule.contentView.addSubview(revealLabel)
    revealCapsule.clipsToBounds = true
    revealCapsule.alpha = 0
    revealCapsule.isUserInteractionEnabled = false
    addSubview(revealCapsule)
  }

  private func layoutReveal() {
    revealLabel.sizeToFit()
    let size = CGSize(width: revealLabel.bounds.width + 36, height: revealLabel.bounds.height + 16)
    revealCapsule.frame = CGRect(
      x: bounds.midX - size.width / 2,
      y: 12,
      width: size.width,
      height: size.height
    )
    revealCapsule.layer.cornerRadius = size.height / 2
    revealLabel.frame = CGRect(
      x: 18, y: 8,
      width: revealLabel.bounds.width,
      height: revealLabel.bounds.height
    )
  }

  private func reveal(_ name: String) {
    revealTask?.cancel()
    revealLabel.text = name
    layoutReveal()
    UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut]) {
      self.revealCapsule.alpha = 1
    }
    revealTask = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 2_400_000_000)
      guard !Task.isCancelled else { return }
      UIView.animate(withDuration: 0.6, delay: 0, options: [.curveEaseInOut]) {
        self?.revealCapsule.alpha = 0
      }
    }
  }
}

#Preview("Earth scene — active world") {
  let scene = GlobalPauseEarthScene.preview
  let view = EarthSceneView(glow: scene.glow, interaction: scene.interaction)
  view.isInteractive = true
  view.backgroundColor = .moonCream
  return view
}
