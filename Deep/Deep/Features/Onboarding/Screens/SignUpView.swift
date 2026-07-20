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

  var body: some View {
    ZStack {
      AtmosphereBackground()

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
            placeholder: "Your name", text: $name,
            textContentType: .name, autocapitalization: .words
          )
          AuthField(
            placeholder: "Email", text: $email,
            keyboard: .emailAddress, textContentType: .emailAddress
          )
          AuthField(
            placeholder: "Password (8+ characters)", text: $password,
            isSecure: true, textContentType: .newPassword,
            submitLabel: .go, onSubmit: submit
          )
        }

        if let errorMessage {
          Text(errorMessage)
            .font(DeepType.caption)
            .foregroundStyle(.deepPlum)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
        }

        Spacer()

        VStack(spacing: 14) {
          OnboardingPrimaryButton(title: "Create account", isEnabled: canSubmit, action: submit)

          Button {
            advance(.logIn)
          } label: {
            Text("I already have an account")
              .font(DeepType.caption)
              .foregroundStyle(.driftGrey)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, .edge)
      .padding(.bottom, .rhythm)
      .frame(maxWidth: .infinity, alignment: .leading)

      if isSubmitting {
        LoadingOrb()
      }
    }
    .navigationBarBackButtonHidden(true)
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
