import SwiftUI

/// The floating top row over the hero: a circular profile button, the centered
/// wordmark, and a notifications bell — matching the Calm reference's header.
/// Purely chrome; actions are injected by the caller (stubbed in the home).
struct HomeTopBar: View {
  var onProfile: () -> Void = {}
  var onNotifications: () -> Void = {}

  var body: some View {
    HStack {
      circleButton(systemImage: "person.fill", label: "Profile", action: onProfile)

      Spacer()

      Text("Global Pause")
        .font(DeepType.wordmark)
        .foregroundStyle(.white)
        .shadow(color: .deepPlum.opacity(0.35), radius: 8, y: 2)

      Spacer()

      circleButton(systemImage: "bell.fill", label: "Notifications", action: onNotifications)
    }
    .padding(.horizontal, .edge)
  }

  private func circleButton(
    systemImage: String,
    label: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 40, height: 40)
        .background(.ultraThinMaterial, in: Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
    }
    .buttonStyle(.softPress)
    .accessibilityLabel(label)
  }
}

#Preview("Top Bar") {
  ZStack(alignment: .top) {
    LinearGradient(colors: [.lavenderMist, .skyWash], startPoint: .top, endPoint: .bottom)
      .ignoresSafeArea()
    HomeTopBar()
      .padding(.top, 8)
  }
}
