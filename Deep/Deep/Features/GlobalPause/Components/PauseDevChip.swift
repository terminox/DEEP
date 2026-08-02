#if DEBUG
import SwiftUI

/// Dev-build-only time-travel control for the Global Pause: a small frosted
/// capsule chip. The lounge hosts "Go live" / "Real time"; the session screen
/// hosts "End". Never ships — the file is DEBUG-only and call sites also gate
/// on `AppConfig.current.isDev`.
struct PauseDevChip: View {
  let label: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(label)
        .font(DeepType.micro)
        .foregroundStyle(.deepPlum)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(.white.opacity(0.6)))
    }
    .buttonStyle(.softPress)
  }
}

#Preview("Dev chips") {
  ZStack {
    Color.moonCream.ignoresSafeArea()
    HStack(spacing: 8) {
      PauseDevChip(label: "Go live") {}
      PauseDevChip(label: "Real time") {}
    }
  }
}
#endif
