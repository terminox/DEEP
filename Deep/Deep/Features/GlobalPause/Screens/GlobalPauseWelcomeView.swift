import SwiftUI

/// The ten quiet seconds before the meditation: welcome lines crossfading
/// over the globe, nothing to tap.
struct GlobalPauseWelcomeView: View {
  @Environment(\.globalPauseSession) private var session

  @State private var index = 0

  private var messages: [String] {
    let configured = session.schedule?.welcomeMessages ?? []
    return configured.isEmpty ? ["Welcome. Tonight the world pauses together."] : configured
  }

  var body: some View {
    VStack {
      Spacer()
      Text(messages[min(index, messages.count - 1)])
        .font(DeepType.displayTitle)
        .foregroundStyle(.deepPlum)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 44)
        .id(index)
        .transition(.opacity.combined(with: .offset(y: 6)))
      Spacer()
      Spacer()
    }
    .allowsHitTesting(false)
    .task {
      // The welcome window is ten seconds; share it across however many
      // lines the admin configured.
      let perMessage = 10.0 / Double(messages.count)
      while !Task.isCancelled, index < messages.count - 1 {
        try? await Task.sleep(for: .seconds(perMessage))
        withAnimation(.exhale) { index += 1 }
      }
    }
  }
}

#Preview("Welcome") {
  ZStack {
    Color.moonCream.ignoresSafeArea()
    GlobalPauseWelcomeView()
      .environment(\.globalPauseSession, .preview(phase: .welcome))
  }
}
