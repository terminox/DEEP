import UIKit
import SwiftUI

/// UIKit twin of the retired SwiftUI `GlobalPauseCardChrome`: the card's
/// bottom chrome — a cream legibility scrim, the "Global Pause" title, a
/// caption, and a state-driven block underneath. Off shows the schedule line
/// alone; the final lead before the meditation adds a grey pill ticking
/// "Live in 13:44"; live swaps the caption for "The world is pausing", shows
/// the "Join now" pill (both pills are styled labels, not buttons: the whole
/// card is the tap target), and a pulsing LIVE badge top-left.
///
/// Fills the card's bounds (the scrim runs centre → bottom); content pins
/// bottom-leading with Auto Layout — a stack, so hidden elements collapse and
/// the block always settles to the bottom edge without dead air. The card-lift
/// animator fades this view as one unit — real labels fading in place, never
/// snapshots — which is also why the LIVE badge lives in here: it must vanish
/// with the rest of the chrome during the flight and at lobby rest.
final class GlobalPauseCardChromeView: UIView {
  private let scrim = LinearGradientView(
    colors: [.moonCream.withAlphaComponent(0), .moonCream.withAlphaComponent(0.85)],
    startPoint: CGPoint(x: 0.5, y: 0.5),
    endPoint: CGPoint(x: 0.5, y: 1)
  )
  private let titleLabel = UILabel()
  private let captionLabel = UILabel()
  /// Grey sibling of the "Join now" pill: same geometry, resting colour, a
  /// ticking "Live in MM:SS" label instead of the call to action.
  private let countdownPill = UIView()
  private let countdownLabel = UILabel()
  private let countdownPillShadow = PillShadowView()
  private let pill = LinearGradientView(
    colors: [.lavenderMist, .blushPowder],
    startPoint: CGPoint(x: 0, y: 0.5),
    endPoint: CGPoint(x: 1, y: 0.5)
  )
  private let pillLabel = UILabel()
  /// Carries the pill's shadow so the pill itself can clip to its capsule.
  private let pillShadow = PillShadowView()
  private let liveBadge = LiveBadgeView()
  private let stack = UIStackView()

  /// The countdown's clock. Raw `Date()` drifts from server time — and dev
  /// time travel moves serverNow arbitrarily far from the wall clock — so the
  /// coordinator injects the synced clock's now.
  var now: () -> Date = { Date() }

  private var currentState: GlobalPauseCardState?
  private var countdownTimer: Timer?

  /// Applies one of the card's three states. Caption text swaps crossfade;
  /// visibility changes ride a matching ease so the whole change reads as one
  /// gesture. `isHidden` and `alpha` move together: hiding collapses the
  /// stack slot, the alpha carries the fade.
  func setState(_ state: GlobalPauseCardState, animated: Bool) {
    guard state != currentState else { return }
    currentState = state
    syncCountdownTimer(for: state)

    switch state {
    case .off(let scheduleLine), .countdown(_, let scheduleLine):
      setCaptionText(scheduleLine, animated: animated)
    case .live:
      setCaptionText("The world is pausing", animated: animated)
    }

    let isCountdown = if case .countdown = state { true } else { false }
    let isLive = state == .live
    let apply = {
      self.countdownPillShadow.isHidden = !isCountdown
      self.countdownPillShadow.alpha = isCountdown ? 1 : 0
      self.pillShadow.isHidden = !isLive
      self.pillShadow.alpha = isLive ? 1 : 0
      self.liveBadge.alpha = isLive ? 1 : 0
      self.layoutIfNeeded()
    }
    if animated {
      UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseInOut], animations: apply)
    } else {
      apply()
    }
  }

  /// Swaps the caption with a quiet crossfade.
  private func setCaptionText(_ text: String, animated: Bool) {
    guard captionLabel.text != text else { return }
    guard animated else {
      captionLabel.text = text
      return
    }
    UIView.transition(with: captionLabel, duration: 0.35, options: .transitionCrossDissolve) {
      self.captionLabel.text = text
    }
  }

  // MARK: - Countdown tick

  /// One 1 Hz timer, alive only in the countdown state. Every tick re-derives
  /// the text from `target − now()`, so backgrounding accumulates no drift and
  /// a foreground return resyncs on the next tick. `.common` mode keeps it
  /// ticking while the feed scrolls.
  private func syncCountdownTimer(for state: GlobalPauseCardState) {
    countdownTimer?.invalidate()
    countdownTimer = nil
    guard case .countdown(let target, _) = state else { return }
    updateCountdown(target: target)
    let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.updateCountdown(target: target) }
    }
    timer.tolerance = 0.05
    RunLoop.main.add(timer, forMode: .common)
    countdownTimer = timer
  }

  private func updateCountdown(target: Date) {
    let remaining = max(0, target.timeIntervalSince(now()))
    // Rounding up shows "15:00" on entry and holds "00:01" through the last
    // second; at zero the label clamps to "00:00" until the boundary timer
    // flips the state live.
    let seconds = Int(remaining.rounded(.up))
    countdownLabel.text = String(format: "Live in %02d:%02d", seconds / 60, seconds % 60)
  }

  init(caption: String) {
    super.init(frame: .zero)
    isUserInteractionEnabled = false

    scrim.frame = bounds
    scrim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(scrim)

    titleLabel.text = "Global Pause"
    titleLabel.font = .displayTitle
    titleLabel.textColor = .deepPlum
    titleLabel.adjustsFontForContentSizeCategory = true

    captionLabel.text = caption
    captionLabel.font = .caption
    captionLabel.textColor = .driftGrey
    captionLabel.adjustsFontForContentSizeCategory = true

    countdownLabel.font = .countdown
    countdownLabel.textColor = .white
    countdownLabel.adjustsFontForContentSizeCategory = true

    countdownPill.backgroundColor = .driftGrey
    countdownPill.clipsToBounds = true
    countdownPill.addSubview(countdownLabel)

    countdownPillShadow.layer.shadowColor = UIColor.driftGrey.withAlphaComponent(0.3).cgColor
    countdownPillShadow.layer.shadowOpacity = 1
    countdownPillShadow.layer.shadowRadius = 10
    countdownPillShadow.layer.shadowOffset = CGSize(width: 0, height: 5)
    countdownPillShadow.addSubview(countdownPill)
    countdownPillShadow.isHidden = true
    countdownPillShadow.alpha = 0

    pillLabel.text = "Join now"
    pillLabel.font = .bodyMedium
    pillLabel.textColor = .white
    pillLabel.adjustsFontForContentSizeCategory = true

    pill.clipsToBounds = true
    pill.addSubview(pillLabel)

    pillShadow.layer.shadowColor = UIColor.lavenderMist.withAlphaComponent(0.4).cgColor
    pillShadow.layer.shadowOpacity = 1
    pillShadow.layer.shadowRadius = 10
    pillShadow.layer.shadowOffset = CGSize(width: 0, height: 5)
    pillShadow.addSubview(pill)
    // The pills belong to their own states; the first `setState` decides.
    pillShadow.isHidden = true
    pillShadow.alpha = 0

    liveBadge.alpha = 0

    stack.axis = .vertical
    stack.alignment = .leading
    for view in [titleLabel, captionLabel, countdownPillShadow, pillShadow] {
      stack.addArrangedSubview(view)
    }
    stack.setCustomSpacing(4, after: titleLabel)
    stack.setCustomSpacing(10, after: captionLabel)

    for view in [stack, liveBadge, pill, pillLabel, countdownPill, countdownLabel] {
      view.translatesAutoresizingMaskIntoConstraints = false
    }
    addSubview(stack)
    addSubview(liveBadge)

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),

      pill.topAnchor.constraint(equalTo: pillShadow.topAnchor),
      pill.leadingAnchor.constraint(equalTo: pillShadow.leadingAnchor),
      pill.trailingAnchor.constraint(equalTo: pillShadow.trailingAnchor),
      pill.bottomAnchor.constraint(equalTo: pillShadow.bottomAnchor),

      pillLabel.topAnchor.constraint(equalTo: pill.topAnchor, constant: 11),
      pillLabel.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 22),
      pillLabel.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -22),
      pillLabel.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -11),

      countdownPill.topAnchor.constraint(equalTo: countdownPillShadow.topAnchor),
      countdownPill.leadingAnchor.constraint(equalTo: countdownPillShadow.leadingAnchor),
      countdownPill.trailingAnchor.constraint(equalTo: countdownPillShadow.trailingAnchor),
      countdownPill.bottomAnchor.constraint(equalTo: countdownPillShadow.bottomAnchor),

      countdownLabel.topAnchor.constraint(equalTo: countdownPill.topAnchor, constant: 11),
      countdownLabel.leadingAnchor.constraint(equalTo: countdownPill.leadingAnchor, constant: 22),
      countdownLabel.trailingAnchor.constraint(equalTo: countdownPill.trailingAnchor, constant: -22),
      countdownLabel.bottomAnchor.constraint(equalTo: countdownPill.bottomAnchor, constant: -11),

      liveBadge.topAnchor.constraint(equalTo: topAnchor, constant: 24),
      liveBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24)
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

}

/// Sizes the pill; rounding and the shadow path must happen HERE (the pass
/// that lays the pill out), not in the chrome's `layoutSubviews` — one level
/// up, the pill's frame is still zero on the first pass and the capsule
/// renders as a rectangle until the next layout invalidation.
private final class PillShadowView: UIView {
  override func layoutSubviews() {
    super.layoutSubviews()
    // The pill is edge-pinned to this view, so our bounds are its bounds.
    for pill in subviews {
      pill.layer.cornerRadius = bounds.height / 2
    }
    layer.shadowPath = UIBezierPath(
      roundedRect: bounds,
      cornerRadius: bounds.height / 2
    ).cgPath
  }
}

#Preview("Chrome — off") {
  let chrome = GlobalPauseCardChromeView(caption: "Breathe with the world, together")
  chrome.backgroundColor = .skyWash
  chrome.setState(.off(scheduleLine: "Tonight · 20:40 Thailand Time"), animated: false)
  return chrome
}

#Preview("Chrome — countdown") {
  let chrome = GlobalPauseCardChromeView(caption: "Breathe with the world, together")
  chrome.backgroundColor = .skyWash
  chrome.setState(
    .countdown(target: Date().addingTimeInterval(899), scheduleLine: "Tonight · 20:40 Thailand Time"),
    animated: false
  )
  return chrome
}

#Preview("Chrome — live") {
  let chrome = GlobalPauseCardChromeView(caption: "Breathe with the world, together")
  chrome.backgroundColor = .skyWash
  chrome.setState(.live, animated: false)
  return chrome
}
