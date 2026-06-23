import SwiftUI
import AuthenticationServices

/// The account gate at the end of the quiz: "your space is ready". Offers only
/// the two requested methods — Sign in with Apple and email — re-cast from the
/// Calm reference's auth screen (Google/Facebook dropped). Apple signs in here;
/// email pushes to the create-account form.
struct AuthChoiceView: View {
  @Environment(\.accountStore) private var accountStore
  @Environment(\.onboardingAdvance) private var advance

  var body: some View {
    ZStack {
      AtmosphereBackground()

      VStack(spacing: .rhythm) {
        Spacer()

        VStack(spacing: 12) {
          Text("Your space is ready.")
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
            .multilineTextAlignment(.center)
          Text("Save it so it's here whenever you return.")
            .font(DeepType.body)
            .foregroundStyle(.driftGrey)
            .multilineTextAlignment(.center)
        }

        Spacer()

        VStack(spacing: 14) {
          SignInWithAppleButton(.continue, onRequest: { request in
            request.requestedScopes = [.fullName, .email]
          }, onCompletion: handleApple)
          .signInWithAppleButtonStyle(.whiteOutline)
          .frame(height: 54)
          .clipShape(Capsule(style: .continuous))

          Button(action: { advance(.emailSignUp) }) {
            Label("Continue with Email", systemImage: "envelope.fill")
              .font(DeepType.sectionTitle)
              .foregroundStyle(.deepPlum)
              .frame(maxWidth: .infinity)
              .frame(height: 54)
              .background(Capsule(style: .continuous).fill(.moonCream))
              .overlay(Capsule(style: .continuous).strokeBorder(.white.opacity(0.6), lineWidth: 0.5))
          }
          .buttonStyle(.softPress)
        }

        Text("By continuing you agree to our Terms and acknowledge our Privacy Policy. What you share in Deep stays in Deep.")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .multilineTextAlignment(.center)
          .padding(.top, 4)
      }
      .padding(.horizontal, .edge)
      .padding(.bottom, .rhythm)
    }
    .navigationBarBackButtonHidden(true)
  }

  private func handleApple(_ result: Result<ASAuthorization, Error>) {
    guard case .success(let authorization) = result,
          let credential = authorization.credential as? ASAuthorizationAppleIDCredential
    else { return } // cancellation / failure: stay put, no error shaming
    accountStore.signInWithApple(
      AppleCredential(
        userID: credential.user,
        fullName: credential.fullName,
        email: credential.email
      )
    )
    advance(.welcome)
  }
}

#Preview("Onboarding — Auth choice") {
  AuthChoiceView()
    .environment(\.accountStore, MockAccountStore.signedOut)
}
