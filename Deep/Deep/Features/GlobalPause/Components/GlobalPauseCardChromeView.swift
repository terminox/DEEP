import UIKit
import SwiftUI

/// UIKit twin of the retired SwiftUI `GlobalPauseCardChrome`: the card's
/// bottom chrome — a cream legibility scrim, the "Global Pause" title, a short
/// caption, and a non-interactive "Join now" pill (a styled label, not a
/// button: the whole card is the tap target).
///
/// Fills the card's bounds (the scrim runs centre → bottom); content pins
/// bottom-leading with Auto Layout. The card-lift animator fades this view as
/// one unit — real labels fading in place, never snapshots.
final class GlobalPauseCardChromeView: UIView {
  private let scrim = LinearGradientView(
    colors: [.moonCream.withAlphaComponent(0), .moonCream.withAlphaComponent(0.85)],
    startPoint: CGPoint(x: 0.5, y: 0.5),
    endPoint: CGPoint(x: 0.5, y: 1)
  )
  private let titleLabel = UILabel()
  private let captionLabel = UILabel()
  private let pill = LinearGradientView(
    colors: [.lavenderMist, .blushPowder],
    startPoint: CGPoint(x: 0, y: 0.5),
    endPoint: CGPoint(x: 1, y: 0.5)
  )
  private let pillLabel = UILabel()
  /// Carries the pill's shadow so the pill itself can clip to its capsule.
  private let pillShadow = UIView()

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

    for view in [titleLabel, captionLabel, pillShadow, pill, pillLabel] {
      view.translatesAutoresizingMaskIntoConstraints = false
    }
    addSubview(titleLabel)
    addSubview(captionLabel)
    addSubview(pillShadow)

    NSLayoutConstraint.activate([
      pillShadow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
      pillShadow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),

      pill.topAnchor.constraint(equalTo: pillShadow.topAnchor),
      pill.leadingAnchor.constraint(equalTo: pillShadow.leadingAnchor),
      pill.trailingAnchor.constraint(equalTo: pillShadow.trailingAnchor),
      pill.bottomAnchor.constraint(equalTo: pillShadow.bottomAnchor),

      pillLabel.topAnchor.constraint(equalTo: pill.topAnchor, constant: 11),
      pillLabel.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 22),
      pillLabel.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -22),
      pillLabel.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -11),

      captionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
      captionLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
      captionLabel.bottomAnchor.constraint(equalTo: pillShadow.topAnchor, constant: -10),

      titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
      titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
      titleLabel.bottomAnchor.constraint(equalTo: captionLabel.topAnchor, constant: -4)
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    pill.layer.cornerRadius = pill.bounds.height / 2
    pillShadow.layer.shadowPath = UIBezierPath(
      roundedRect: pill.bounds,
      cornerRadius: pill.bounds.height / 2
    ).cgPath
  }
}

#Preview("Card chrome") {
  let chrome = GlobalPauseCardChromeView(caption: "Breathe with the world, together")
  chrome.backgroundColor = .skyWash
  return chrome
}
