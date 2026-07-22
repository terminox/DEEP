import SwiftUI
import UIKit

/// A single frosted text field for the auth screens, styled to match the
/// onboarding surfaces (frosted glass, soft pill, Deep type). Kept minimal —
/// a label-less field with a gentle placeholder, per DESIGN.md's calm voice.
///
/// Optional touches: a leading SF Symbol (`icon`), a soft trailing checkmark
/// when `isValid` is true, and — for secure fields — a reveal toggle that
/// swaps the obscured entry for plain text.
struct AuthField: View {
  let placeholder: String
  @Binding var text: String
  var icon: String? = nil
  var isSecure: Bool = false
  var isValid: Bool? = nil
  var keyboard: UIKeyboardType = .default
  var textContentType: UITextContentType? = nil
  var autocapitalization: TextInputAutocapitalization = .never
  var submitLabel: SubmitLabel = .next
  var onSubmit: () -> Void = {}

  @State private var isRevealed = false
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(spacing: 12) {
      if let icon {
        Image(systemName: icon)
          .font(DeepType.body)
          .foregroundStyle(.driftGrey)
      }

      field
        .font(DeepType.body)
        .foregroundStyle(.deepPlum)
        .tint(.lavenderMist)
        .textInputAutocapitalization(autocapitalization)
        .autocorrectionDisabled(true)
        .keyboardType(keyboard)
        .textContentType(textContentType)
        .submitLabel(submitLabel)
        .onSubmit(onSubmit)
        .focused($isFocused)

      if isValid == true {
        Image(systemName: "checkmark.circle.fill")
          .font(DeepType.body)
          .foregroundStyle(.lavenderMist)
          .transition(.opacity)
      }

      if isSecure {
        Button {
          isRevealed.toggle()
          isFocused = true
        } label: {
          Image(systemName: isRevealed ? "eye.slash" : "eye")
            .font(DeepType.body)
            .foregroundStyle(.driftGrey)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
        // Full 44pt tap target without inflating the pill beyond its siblings.
        .padding(.vertical, -11)
        .padding(.trailing, -12)
      }
    }
    .animation(.exhale, value: isValid)
    .padding(.horizontal, 18)
    .padding(.vertical, 16)
    .frostedCard(cornerRadius: .chip)
  }

  /// The obscured/plain entry swap for secure fields. The binding lives
  /// outside, so text survives the swap; the toggle reasserts focus.
  @ViewBuilder
  private var field: some View {
    if isSecure && !isRevealed {
      SecureField(placeholder, text: $text)
    } else {
      TextField(placeholder, text: $text)
    }
  }
}

#Preview("Auth field") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: .rhythm) {
      AuthField(placeholder: "Your name", text: .constant(""), icon: "person")
      AuthField(
        placeholder: "Email", text: .constant("drift@deep.app"),
        icon: "envelope", isValid: true
      )
      AuthField(
        placeholder: "Password", text: .constant("secret"),
        icon: "lock", isSecure: true
      )
      AuthField(placeholder: "No icon", text: .constant(""))
    }
    .padding(.horizontal, .edge)
  }
}
