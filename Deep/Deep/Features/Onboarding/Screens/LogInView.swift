import SwiftUI

/// Returning-user log-in, reachable from the welcome screen. On success it pulls
/// the user's onboarding profile from the backend and hydrates the local store;
/// if their onboarding is already complete, `AppRootView`'s gate opens straight
/// into the app, otherwise the flow resumes at the first question.
struct LogInView: View {
  @Environment(\.accountStore) private var accountStore
  @Environment(\.onboardingStore) private var onboardingStore
  @Environment(\.onboardingRemote) private var onboardingRemote
  @Environment(\.onboardingAdvance) private var advance

  @State private var email = ""
  @State private var password = ""
  @State private var errorMessage: String?
  @State private var isSubmitting = false

  private var canSubmit: Bool {
    !email.isEmpty && !password.isEmpty && !isSubmitting
  }

  var body: some View {
    ZStack {
      AtmosphereBackground()

      VStack(alignment: .leading, spacing: .rhythm) {
        VStack(alignment: .leading, spacing: .rhythm) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Welcome back")
              .font(DeepType.displayTitle)
              .foregroundStyle(.deepPlum)
            Text("Pick up right where you left off.")
              .font(DeepType.caption)
              .foregroundStyle(.driftGrey)
          }
          .padding(.top, 8)

          VStack(spacing: 14) {
            AuthField(
              placeholder: "Email", text: $email, icon: "envelope",
              keyboard: .emailAddress, textContentType: .emailAddress
            )
            AuthField(
              placeholder: "Password", text: $password, icon: "lock",
              isSecure: true, textContentType: .password,
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
        }
        .onboardingContentDrift()

        Spacer()

        OnboardingPrimaryButton(title: "Log in", isEnabled: canSubmit, action: submit)
      }
      .padding(.horizontal, .edge)
      .padding(.bottom, .rhythm)
      .frame(maxWidth: .infinity, alignment: .leading)

      if isSubmitting {
        BreatheLoadingView(line: "Take a breath. We're signing you in.")
          .transition(.opacity)
      }
    }
    .animation(.exhale, value: isSubmitting)
  }

  private func submit() {
    guard canSubmit else { return }
    isSubmitting = true
    errorMessage = nil
    Task {
      defer { isSubmitting = false }
      do {
        try await accountStore.logIn(email: email, password: password)
        // Reflect the server's onboarding state locally so the gate is accurate.
        if let profile = try? await onboardingRemote.fetchProfile() {
          onboardingStore.hydrate(
            quizAnswers: profile.quizAnswers,
            mindTree: profile.mindTree,
            completed: profile.completed
          )
          if !profile.completed {
            advance(.quiz(index: 0))
          }
          // When complete, AppRootView's gate opens automatically.
        } else {
          // Couldn't read onboarding — send them through it to be safe.
          advance(.quiz(index: 0))
        }
      } catch {
        withAnimation(.exhale) { errorMessage = message(for: error) }
      }
    }
  }

  private func message(for error: Error) -> String {
    (error as? LocalizedError)?.errorDescription
      ?? "We couldn't sign you in just now. Please try again."
  }
}

#Preview("Log in") {
  LogInView()
    .environment(\.accountStore, PreviewAccountStore())
}
