import SwiftUI
import AuthenticationServices

/// The account gate at the end of the quiz: "your space is ready". Offers only
/// the two requested methods — Sign in with Apple and email — re-cast from the
/// Calm reference's auth screen (Google/Facebook dropped). Apple signs in here;
/// email pushes to the create-account form.
struct AuthChoiceView: View {
  @Environment(\.accountStore) private var accountStore
  @Environment(\.onboardingAdvance) private var advance

  private let buttonHeight: CGFloat = 56

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

        VStack(spacing: 12) {
          SignInWithAppleButton(.continue, onRequest: { request in
            request.requestedScopes = [.fullName, .email]
          }, onCompletion: handleApple)
          .signInWithAppleButtonStyle(.black)
          .frame(height: buttonHeight)
          .clipShape(Capsule(style: .continuous))
          .shadow(color: Color.deepPlum.opacity(0.22), radius: 18, x: 0, y: 10)

          Button(action: { advance(.emailSignUp) }) {
            HStack(spacing: 10) {
              Image(systemName: "envelope.fill")
                .font(.system(size: 16, weight: .medium))
              Text("Continue with Email")
                .font(.system(size: 17, weight: .medium))
            }
            .foregroundStyle(.deepPlum)
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(Capsule(style: .continuous).fill(.white))
            .overlay(
              Capsule(style: .continuous)
                .strokeBorder(Color.lavenderMist.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.lavenderMist.opacity(0.3), radius: 18, x: 0, y: 10)
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
