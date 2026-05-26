import SwiftUI

/// Top header for the Global Pause screen: back chevron, serif wordmark,
/// subtitle, and bell + profile actions.
struct GlobalPauseHeader: View {
    var onBack: () -> Void = {}
    var onNotifications: () -> Void = {}
    var onProfile: () -> Void = {}

    var body: some View {
        ZStack {
            VStack(spacing: 2) {
                Text("Global Pause")
                    .font(DeepType.wordmark)
                    .foregroundStyle(DeepColor.deepPlum)
                    .accessibilityAddTraits(.isHeader)
                Text("Together, we pause for peace.")
                    .font(DeepType.caption)
                    .foregroundStyle(DeepColor.driftGrey)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)

            HStack(spacing: 10) {
                CircleIconButton(systemName: "chevron.left", action: onBack)
                    .accessibilityLabel("Back")
                Spacer(minLength: 0)
                CircleIconButton(systemName: "bell", action: onNotifications)
                    .accessibilityLabel("Notifications")
                ProfileBubble(action: onProfile)
                    .accessibilityLabel("Profile")
            }
        }
        .padding(.horizontal, DeepSpacing.edge)
    }
}

private struct CircleIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(DeepColor.deepPlum.opacity(0.85))
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(.white.opacity(0.7))
                        .background(Circle().fill(.ultraThinMaterial))
                )
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.6), lineWidth: 0.5)
                )
                .shadow(color: DeepColor.lavenderMist.opacity(0.18), radius: 8, y: 4)
        }
        .buttonStyle(.softPress)
    }
}

private struct ProfileBubble: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DeepColor.softLilac, DeepColor.blushPowder],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "person.fill")
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .frame(width: 36, height: 36)
            .overlay(
                Circle().strokeBorder(.white.opacity(0.7), lineWidth: 0.6)
            )
            .shadow(color: DeepColor.lavenderMist.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(.softPress)
    }
}

#Preview {
    ZStack {
        AtmosphereBackground()
        GlobalPauseHeader()
    }
}
