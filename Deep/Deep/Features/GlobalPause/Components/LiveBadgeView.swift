import UIKit
import SwiftUI

/// UIKit twin of the SwiftUI `OnAirPill` recipe — a pulsing dot and a micro
/// label in a half-white capsule — for the card chrome, which lays itself out
/// in UIKit. Keep the two in step: same dot, padding, tracking and pulse.
///
/// The pulse is a Core Animation autoreverse loop (the UIKit spelling of
/// `.exhale.repeatForever`). CA strips animations when the app backgrounds and
/// never replays them on its own, so the pulse re-arms on window attach, on
/// foreground, and when Reduce Motion flips.
final class LiveBadgeView: UIView {
  private let dot = UIView()
  private let label = UILabel()
  private var observers: [NSObjectProtocol] = []

  init(title: String = "LIVE") {
    super.init(frame: .zero)
    isUserInteractionEnabled = false
    backgroundColor = UIColor.white.withAlphaComponent(0.5)
    clipsToBounds = true

    dot.backgroundColor = .blushPowder
    dot.layer.cornerRadius = 3

    label.attributedText = NSAttributedString(string: title, attributes: [.kern: 1.4])
    label.font = .micro
    label.textColor = .deepPlum
    label.adjustsFontForContentSizeCategory = true

    for view in [dot, label] {
      view.translatesAutoresizingMaskIntoConstraints = false
      addSubview(view)
    }
    NSLayoutConstraint.activate([
      dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
      dot.centerYAnchor.constraint(equalTo: centerYAnchor),
      dot.widthAnchor.constraint(equalToConstant: 6),
      dot.heightAnchor.constraint(equalToConstant: 6),

      label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 4),
      label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
      label.topAnchor.constraint(equalTo: topAnchor, constant: 5),
      label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5)
    ])

    isAccessibilityElement = true
    accessibilityLabel = "Live"

    for name in [UIApplication.willEnterForegroundNotification,
                 UIAccessibility.reduceMotionStatusDidChangeNotification] {
      observers.append(NotificationCenter.default.addObserver(
        forName: name, object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.armPulse() }
      })
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = bounds.height / 2
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    armPulse()
  }

  private func armPulse() {
    dot.layer.removeAnimation(forKey: "pulse")
    guard window != nil, !UIAccessibility.isReduceMotionEnabled else { return }
    let pulse = CABasicAnimation(keyPath: "opacity")
    pulse.fromValue = 1
    pulse.toValue = 0.4
    pulse.duration = .exhale
    pulse.timingFunction = .exhale
    pulse.autoreverses = true
    pulse.repeatCount = .infinity
    dot.layer.add(pulse, forKey: "pulse")
  }
}

#Preview("Live badge") {
  let container = UIView()
  container.backgroundColor = .skyWash
  let badge = LiveBadgeView()
  badge.translatesAutoresizingMaskIntoConstraints = false
  container.addSubview(badge)
  NSLayoutConstraint.activate([
    badge.centerXAnchor.constraint(equalTo: container.centerXAnchor),
    badge.centerYAnchor.constraint(equalTo: container.centerYAnchor)
  ])
  return container
}
