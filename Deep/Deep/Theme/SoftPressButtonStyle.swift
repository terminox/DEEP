import SwiftUI

/// Foam-like press feedback — scale 0.97 with a damped release.
/// Matches the "Settle" motion described in DESIGN.md.
struct SoftPressButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .animation(DeepMotion.settle, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SoftPressButtonStyle {
    static var softPress: SoftPressButtonStyle { SoftPressButtonStyle() }
}
