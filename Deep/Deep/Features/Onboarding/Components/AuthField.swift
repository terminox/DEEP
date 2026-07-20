import SwiftUI
import UIKit

/// A single frosted text field for the auth screens, styled to match the
/// onboarding surfaces (frosted glass, soft pill, Deep type). Kept minimal —
/// a label-less field with a gentle placeholder, per DESIGN.md's calm voice.
struct AuthField: View {
  let placeholder: String
  @Binding var text: String
  var isSecure: Bool = false
  var keyboard: UIKeyboardType = .default
  var textContentType: UITextContentType? = nil
  var autocapitalization: TextInputAutocapitalization = .never
  var submitLabel: SubmitLabel = .next
  var onSubmit: () -> Void = {}

  var body: some View {
    Group {
      if isSecure {
        SecureField(placeholder, text: $text)
      } else {
        TextField(placeholder, text: $text)
      }
    }
    .font(DeepType.body)
    .foregroundStyle(.deepPlum)
    .tint(.lavenderMist)
    .textInputAutocapitalization(autocapitalization)
    .autocorrectionDisabled(true)
    .keyboardType(keyboard)
    .textContentType(textContentType)
    .submitLabel(submitLabel)
    .onSubmit(onSubmit)
    .padding(.horizontal, 18)
    .padding(.vertical, 16)
    .frostedCard(cornerRadius: .chip)
  }
}

#Preview("Auth field") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: .rhythm) {
      AuthField(placeholder: "Your name", text: .constant(""))
      AuthField(placeholder: "Password", text: .constant("secret"), isSecure: true)
    }
    .padding(.horizontal, .edge)
  }
}
