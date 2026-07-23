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

      VStack(alignment: .center, spacing: .rhythm) {
        Image("OnboardingLogo")
          .resizable()
          .scaledToFit()
          .frame(maxWidth: 300)
          .accessibilityAddTraits(.isHeader)
          .accessibilityLabel("DEEP — your peaceful space")
          .shadow(color: .moonCream.opacity(0.8), radius: 12)
        
        Spacer()
        
        Text("Create an account to save your progress")
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
          .multilineTextAlignment(.center)
          .onboardingContentRise()

        VStack(spacing: 16) {
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
