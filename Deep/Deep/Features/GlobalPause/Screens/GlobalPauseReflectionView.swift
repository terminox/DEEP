import SwiftUI

/// The landing after the meditation: a thank-you, and one card to write into.
/// It fades in over the meditation and covers the globe card's silent handback
/// to its lounge seat behind the presentation.
///
/// One ask, one tap. The composer *is* the card the message will appear as, so
/// the member sees their name, their place and their chosen word before they
/// commit rather than discovering them in the feed afterwards. The forward tap
/// posts it — there is no separate send, so writing a message costs no more
/// steps than skipping one.
///
/// It says nothing about hearts or sunlight: the reward ritual it continues
/// into carries that news, and the message's own grant is folded into the same
/// receipt.
///
/// Its background is painted by `GlobalPauseCompletionView` — one atmosphere
/// spanning both halves of the ending, so nothing crossfades against itself.
struct GlobalPauseReflectionView: View {
  /// True while the ending is settling tonight's award before the ritual — the
  /// forward tap rests rather than promising a number that hasn't landed.
  var isPreparing = false
  var onContinue: () -> Void

  @Environment(\.globalPauseSession) private var session

  @State private var text = ""
  @State private var tag: Intention.ID?
  @State private var isSending = false
  @State private var note: String?
  /// Set once a refusal has been shown, so the next tap leaves rather than
  /// trapping the member on a message that will not send.
  @State private var mayContinueUnsent = false
  /// The text the content filter turned away. Editing it away from this
  /// re-arms sending, since a kinder rewording may well pass; leaving it as is
  /// lets the next tap move on, as every other refusal does.
  @State private var rejectedText: String?
  @FocusState private var isWriting: Bool

  private var intentions: [Intention] {
    session.schedule?.intentions ?? Intention.samples
  }

  private var trimmed: String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var tagLabel: String? {
    intentions.first { $0.key == tag }?.label
  }

  /// Resolved here: the button and the note render their `String`s verbatim.
  private var buttonTitle: String {
    trimmed.isEmpty || mayContinueUnsent
      ? String(localized: "Continue", bundle: .app, locale: .app)
      : String(localized: "Send & continue", bundle: .app, locale: .app)
  }

  var body: some View {
    ScrollView {
      VStack(spacing: .rhythm * 1.5) {
        header

        PeaceMessageComposerCard(
          text: $text,
          tagLabel: tagLabel,
          isFocused: $isWriting
        )

        tagRow

        if let note {
          Text(note)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .multilineTextAlignment(.center)
            .transition(.opacity)
        }
      }
      .padding(.horizontal, .edge)
      .padding(.vertical, .rhythm)
    }
    // Centres the card when it fits and scrolls when it doesn't — unlike
    // `containerRelativeFrame`, which pins the content to the full container
    // height and so lets the keyboard drive it under the bottom inset.
    .defaultScrollAnchor(.center)
    .scrollIndicators(.hidden)
    .scrollDismissesKeyboard(.interactively)
    .safeAreaInset(edge: .bottom) {
      RewardContinueButton(
        verbatim: buttonTitle,
        isBusy: isSending || isPreparing,
        action: { Task { await commit() } }
      )
      .padding(.horizontal, .edge)
      .padding(.bottom, .rhythm)
    }
    .animation(.settle, value: note)
    .onChange(of: text) { _, updated in
      guard let rejectedText, updated != rejectedText else { return }
      self.rejectedText = nil
      mayContinueUnsent = false
    }
  }

  private var header: some View {
    VStack(spacing: 7) {
      Text("PEACE MESSAGE")
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.driftGrey)
      Text("Thank you for pausing")
        .font(DeepType.displayTitle)
        .foregroundStyle(.deepPlum)
        .multilineTextAlignment(.center)
    }
  }

  private var tagRow: some View {
    VStack(spacing: 12) {
      Text("What were you holding?")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)

      FlowLayout(spacing: 8, runSpacing: 8) {
        ForEach(intentions) { intention in
          DeepChip(label: intention.label, isSelected: tag == intention.id) {
            withAnimation(.settle) {
              tag = (tag == intention.id) ? nil : intention.id
            }
          }
        }
      }
    }
  }

  /// The whole feedback phase in one tap: post the message with its tag (the
  /// server stores the tag on the card *and* upserts tonight's reflection), or
  /// record a tag left without a message, then move on to the ritual.
  ///
  /// A refusal keeps the member here once, with a quiet note, and turns the
  /// button into a plain "Continue" so they are never stuck.
  private func commit() async {
    guard !isSending, !isPreparing else { return }
    isWriting = false

    if mayContinueUnsent || (trimmed.isEmpty && tag == nil) {
      onContinue()
      return
    }

    isSending = true
    defer { isSending = false }
    do {
      if trimmed.isEmpty {
        // A word without a message still belongs in tonight's reflection.
        try await session.submit(intention: tag, mood: nil)
      } else {
        try await session.post(message: trimmed, intention: tag)
      }
      onContinue()
    } catch let error as APIError {
      withAnimation(.settle) {
        note = Self.note(for: error)
        mayContinueUnsent = true
        rejectedText = Self.isRejection(error) ? text : nil
      }
    } catch {
      withAnimation(.settle) {
        note = String(localized: "Your message couldn't be sent just now.", bundle: .app, locale: .app)
        mayContinueUnsent = true
      }
    }
  }

  /// The server's content filter turning the words themselves away.
  private static func isRejection(_ error: APIError) -> Bool {
    if case .http(422, "message_rejected", _) = error { return true }
    return false
  }

  private static func note(for error: APIError) -> String {
    switch error {
    case .unauthorized:
      String(localized: "Sign in from the You tab to leave a message.", bundle: .app, locale: .app)
    case .http(_, let code, _) where code == "message_limit":
      String(localized: "Three messages a day is plenty. Rest now.", bundle: .app, locale: .app)
    case .http(422, "message_rejected", _):
      String(
        localized: "This message can't be shared. Please keep it kind.",
        bundle: .app,
        locale: .app,
        comment: "Inline note when the content filter refuses a peace message."
      )
    case .http(403, "account_suspended", _):
      // Not a rejection of the words: editing won't help, so the member
      // simply continues without sending.
      String(
        localized: "Your account can't share peace messages right now.",
        bundle: .app,
        locale: .app,
        comment: "Inline note when a suspended account tries to post a peace message."
      )
    default:
      String(localized: "Your message couldn't be sent just now.", bundle: .app, locale: .app)
    }
  }
}

#if DEBUG
#Preview("Reflection") {
  ReflectionPreview()
}

#Preview("Reflection — settling the award") {
  ReflectionPreview(isPreparing: true)
}

private struct ReflectionPreview: View {
  var isPreparing = false

  var body: some View {
    ZStack {
      Color.moonCream.ignoresSafeArea()
      AtmosphereBackground()
      GlobalPauseReflectionView(isPreparing: isPreparing, onContinue: {})
    }
    .environment(\.globalPauseSession, .preview())
    .environment(
      \.accountStore,
      PreviewAccountStore(
        account: Account(
          displayName: "Miyu", email: nil, method: .apple, appleUserID: "preview"
        )
      )
    )
  }
}
#endif
