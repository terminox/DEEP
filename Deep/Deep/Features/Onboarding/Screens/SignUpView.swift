import SwiftUI

/// Create-account step, placed after the Mind Tree choice. When it succeeds the
/// flow moves to `CraftingSpaceView`, whose loader also syncs the gathered
/// onboarding answers to the backend. Styled to match the onboarding surfaces —
/// a gentle invitation, never a wall.
struct SignUpView: View {
  @Environment(\.accountStore) private var accountStore
  @Environment(\.onboardingAdvance) private var advance

  @State private var name = ""
  @State private var email = ""
  @State private var password = ""
  @State private var errorMessage: String?
  @State private var isSubmitting = false

  private var canSubmit: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty
      && !email.isEmpty
      && !password.isEmpty
      && !isSubmitting
  }

  /// Mirrors the submit-time check so the trailing checkmark never lies.
  private var emailLooksValid: Bool {
    email.contains("@") && email.contains(".")
  }

  private var passwordIsLongEnough: Bool {
    password.count >= 8
  }

  var body: some View {
    ZStack {
      AtmosphereBackground()

      VStack(alignment: .leading, spacing: .rhythm) {
        VStack(alignment: .leading, spacing: .rhythm) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Create your space")
              .font(DeepType.displayTitle)
              .foregroundStyle(.deepPlum)
            Text("So your practice stays with you.")
              .font(DeepType.caption)
              .foregroundStyle(.driftGrey)
          }
          .padding(.top, 8)

          VStack(spacing: 14) {
            AuthField(
              placeholder: "Your name", text: $name, icon: "person",
              textContentType: .name, autocapitalization: .words
            )
            AuthField(
              placeholder: "Email", text: $email, icon: "envelope",
              isValid: emailLooksValid ? true : nil,
              keyboard: .emailAddress, textContentType: .emailAddress
            )
            AuthField(
              placeholder: "Password", text: $password, icon: "lock",
              isSecure: true, textContentType: .newPassword,
              submitLabel: .go, onSubmit: submit
            )

            HStack(spacing: 8) {
              Image(systemName: passwordIsLongEnough ? "checkmark.circle.fill" : "circle")
                .font(DeepType.caption)
                .foregroundStyle(passwordIsLongEnough ? Color.lavenderMist : Color.driftGrey)
              Text("At least 8 characters")
                .font(DeepType.caption)
                .foregroundStyle(.driftGrey)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 18)
            .animation(.exhale, value: passwordIsLongEnough)
          }

          if let errorMessage {
            Text(errorMessage)
              .font(DeepType.caption)
              .foregroundStyle(.deepPlum)
              .frame(maxWidth: .infinity, alignment: .leading)
              .transition(.opacity)
          }
        }
        .onboardingContentDrift()

        Spacer()

        OnboardingPrimaryButton(title: "Create account", isEnabled: canSubmit, action: submit)
      }
      .padding(.horizontal, .edge)
      .padding(.bottom, .rhythm)
      .frame(maxWidth: .infinity, alignment: .leading)

      if isSubmitting {
        LoadingOrb()
      }
    }
  }

  private func submit() {
    guard canSubmit else { return }
    // Gentle client-side validation, mirroring the backend's own checks.
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return show(AccountError.emptyName) }
    guard email.contains("@"), email.contains(".") else { return show(AccountError.invalidEmail) }
    guard password.count >= 8 else { return show(AccountError.weakPassword) }

    isSubmitting = true
    errorMessage = nil
    Task {
      defer { isSubmitting = false }
      do {
        try await accountStore.signUp(name: trimmedName, email: email, password: password)
        advance(.craftingSpace)
      } catch {
        withAnimation(.exhale) { errorMessage = message(for: error) }
      }
    }
  }

  private func show(_ error: AccountError) {
    withAnimation(.exhale) { errorMessage = error.errorDescription }
  }

  private func message(for error: Error) -> String {
    (error as? LocalizedError)?.errorDescription
      ?? "We couldn't create your space just now. Please try again."
  }
}

#Preview("Sign up") {
  SignUpView()
    .environment(\.accountStore, PreviewAccountStore())
}
