import SwiftUI

/// The feedback-phase composer: one gentle line into the world's feed.
/// Posting requires a signed-in account; the server also gates by phase, and
/// both refusals surface as quiet inline notes rather than alerts.
struct PeaceMessageComposer: View {
  /// Performs the post; throws `APIError` on refusal.
  var send: (String) async throws -> Void

  @State private var text = ""
  @State private var isSending = false
  @State private var note: String?
  @State private var sent = false

  private let limit = 280

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("LEAVE A PEACE MESSAGE")
        .font(DeepType.micro)
        .tracking(1.4)
        .foregroundStyle(.driftGrey)

      HStack(alignment: .bottom, spacing: 10) {
        TextField("What did tonight hold for you?", text: $text, axis: .vertical)
          .font(DeepType.body)
          .foregroundStyle(.deepPlum)
          .lineLimit(1...4)
          .onChange(of: text) { _, updated in
            if updated.count > limit { text = String(updated.prefix(limit)) }
            note = nil
          }

        sendButton
      }
      .padding(14)
      .frostedCard(cornerRadius: 20)

      if let note {
        Text(note)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .transition(.opacity)
      } else if sent {
        Text("Sent to the world. Thank you.")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .transition(.opacity)
      }
    }
    .animation(.settle, value: note)
    .animation(.settle, value: sent)
  }

  private var trimmed: String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var sendButton: some View {
    Button {
      Task { await submit() }
    } label: {
      Group {
        if isSending {
          ProgressView()
            .tint(.white)
        } else {
          Image(systemName: "arrow.up")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
        }
      }
      .frame(width: 34, height: 34)
      .background(
        Circle().fill(
          LinearGradient(
            colors: [.lavenderMist, .blushPowder],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
      )
      .opacity(trimmed.isEmpty ? 0.45 : 1)
    }
    .buttonStyle(.softPress)
    .disabled(trimmed.isEmpty || isSending)
    .accessibilityLabel("Send peace message")
  }

  private func submit() async {
    guard !trimmed.isEmpty, !isSending else { return }
    isSending = true
    defer { isSending = false }
    do {
      try await send(trimmed)
      text = ""
      sent = true
    } catch let error as APIError {
      switch error {
      case .unauthorized:
        note = "Sign in from the You tab to leave a message."
      case .http(_, let code, _) where code == "phase_closed":
        note = "The pause has moved on — messages open in the feedback phase."
      case .http(_, let code, _) where code == "message_limit":
        note = "Three messages a night is plenty. Rest now."
      default:
        note = "Your message couldn't be sent just now."
      }
    } catch {
      note = "Your message couldn't be sent just now."
    }
  }
}

#Preview("Composer") {
  VStack(spacing: 24) {
    PeaceMessageComposer { _ in }
    PeaceMessageComposer { _ in throw APIError.unauthorized }
  }
  .padding(.edge)
  .background(.moonCream)
}
