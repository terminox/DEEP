import SwiftUI

/// The feedback-phase composer — one gentle line into the world's feed.
///
/// It is the published card, made editable: the same chrome, the same identity
/// header, the same tag in the same place. What the member writes into is what
/// the world reads back, so nothing about the card can surprise them after the
/// fact — least of all that they posted under their name, from their country.
///
/// It holds no send button of its own. The screen's one forward tap commits it
/// (see `GlobalPauseReflectionView`), so writing a message costs no extra step
/// than not writing one.
struct PeaceMessageComposerCard: View {
  @Binding var text: String
  /// The label of the tag currently chosen, shown where the published card
  /// shows it. Nil until the member picks a word.
  var tagLabel: String?
  var isFocused: FocusState<Bool>.Binding

  @Environment(\.accountStore) private var accountStore

  /// The 280 the server enforces (`POST /pause/messages`), applied here so the
  /// limit is a soft stop rather than a refusal after the fact.
  static let limit = 280

  private var name: String {
    accountStore.account?.displayName ?? "Friend"
  }

  /// The same country the post itself carries — read from one source so the
  /// preview can never disagree with what gets stored.
  private var place: String {
    guard let region = Locale.current.region?.identifier.uppercased() else { return "" }
    return Locale.current.localizedString(forRegionCode: region) ?? region
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      PeaceMessageIdentity(name: name, place: place, tintSeed: name)

      TextField("What did tonight hold for you?", text: $text, axis: .vertical)
        .font(DeepType.caption)
        .foregroundStyle(Color.deepPlum.opacity(0.78))
        .lineSpacing(2)
        .lineLimit(2...5)
        .focused(isFocused)
        .submitLabel(.done)
        .onChange(of: text) { _, updated in
          if updated.count > Self.limit { text = String(updated.prefix(Self.limit)) }
        }

      if let tagLabel {
        HStack {
          Spacer(minLength: 0)
          DeepTagLabel(label: tagLabel)
        }
        .transition(.opacity)
      }
    }
    .peaceMessageCard()
    .animation(.settle, value: tagLabel)
  }
}

#Preview("Composer — empty") {
  ComposerCardPreview(initial: "", tag: nil)
}

#Preview("Composer — written and tagged") {
  ComposerCardPreview(
    initial: "The city went quiet with me tonight. Thank you, whoever you are.",
    tag: "Gratitude"
  )
}

private struct ComposerCardPreview: View {
  let initial: String
  let tag: String?

  @State private var text: String
  @FocusState private var isFocused: Bool

  init(initial: String, tag: String?) {
    self.initial = initial
    self.tag = tag
    _text = State(initialValue: initial)
  }

  private static let miyu = Account(
    displayName: "Miyu", email: nil, method: .apple, appleUserID: "preview"
  )

  var body: some View {
    ZStack {
      AtmosphereBackground()
      PeaceMessageComposerCard(text: $text, tagLabel: tag, isFocused: $isFocused)
        .padding(.edge)
    }
    .environment(\.accountStore, PreviewAccountStore(account: Self.miyu))
  }
}
