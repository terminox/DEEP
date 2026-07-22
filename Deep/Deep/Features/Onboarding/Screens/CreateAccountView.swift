import SwiftUI

/// Account gateway after the Mind Tree — the invitation to keep what the flow
/// has gathered. Presents the available sign-up methods (email today; more
/// slot into the footer later) plus the log-in escape for returning users.
/// The email form itself lives in `SignUpView`.
struct CreateAccountView: View {
  @Environment(\.onboardingAdvance) private var advance

  var body: some View {
    ZStack {
      AtmosphereBackground()

      VStack(alignment: .leading, spacing: .rhythm) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Keep your space")
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
          Text("An account holds your Mind Tree, your answers, and everything you grow here.")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
        .onboardingContentRise()

        Spacer()

        VStack(spacing: 14) {
          OnboardingPrimaryButton(title: "Continue with Email", systemImage: "envelope") {
            advance(.signUp)
          }

          Button {
            advance(.logIn)
          } label: {
            (Text("Already have an account? ") + Text("Log in").bold().underline())
              .font(DeepType.caption)
              .foregroundStyle(.deepPlum)
              .frame(minHeight: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)

          Text(.init("By continuing, you agree to our [Terms](https://deep.app/terms) and [Privacy Policy](https://deep.app/privacy)."))
            .font(DeepType.micro)
            .foregroundStyle(.driftGrey)
            .tint(.deepPlum)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
      }
      .padding(.horizontal, .edge)
      .padding(.bottom, .rhythm)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

#Preview("Create account — gateway") {
  CreateAccountView()
}
