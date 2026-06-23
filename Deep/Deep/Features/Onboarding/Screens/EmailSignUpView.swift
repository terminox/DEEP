import SwiftUI

/// The email create-account form — name, email, password with inline validation.
/// Re-cast from the Calm reference's "Create your account" sheet into Deep's
/// frosted, pastel field style. Validation runs through `AccountStore`, so the
/// rules live in one place.
struct EmailSignUpView: View {
  @Environment(\.accountStore) private var accountStore
  @Environment(\.onboardingAdvance) private var advance

  @State private var name = ""
  @State private var email = ""
  @State private var password = ""
  @State private var showPassword = false
  @State private var errorMessage: String?

  @FocusState private var focusedField: Field?
  private enum Field { case name, email, password }

  var body: some View {
    ZStack {
      AtmosphereBackground()

      ScrollView {
        VStack(alignment: .leading, spacing: .rhythm) {
          VStack(alignment: .leading, spacing: 10) {
            Text("Create your space")
              .font(DeepType.displayTitle)
              .foregroundStyle(.deepPlum)
            Text("Just a name to greet you and a way back in.")
              .font(DeepType.body)
              .foregroundStyle(.driftGrey)
          }
          .padding(.top, 8)

          VStack(spacing: 14) {
            field(title: "Your name", text: $name, field: .name) {
              TextField("What shall we call you?", text: $name)
                .textContentType(.givenName)
                .focused($focusedField, equals: .name)
            }

            field(title: "Email", text: $email, field: .email) {
              TextField("you@example.com", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
            }

            field(title: "Password", text: $password, field: .password) {
              HStack {
                Group {
                  if showPassword {
                    TextField("At least 8 characters", text: $password)
                  } else {
                    SecureField("At least 8 characters", text: $password)
                  }
                }
                .textContentType(.newPassword)
                .focused($focusedField, equals: .password)

                Button {
                  showPassword.toggle()
                } label: {
                  Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundStyle(.driftGrey)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showPassword ? "Hide password" : "Show password")
              }
            }
          }

          if let errorMessage {
            Text(errorMessage)
              .font(DeepType.caption)
              .foregroundStyle(.deepPlum)
              .transition(.opacity)
          }

          OnboardingPrimaryButton(title: "Create account") {
            submit()
          }
        }
        .padding(.horizontal, .edge)
        .padding(.bottom, .rhythm)
      }
      .scrollIndicators(.hidden)
    }
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
  }

  @ViewBuilder
  private func field<Content: View>(
    title: String,
    text: Binding<String>,
    field: Field,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title.uppercased())
        .font(DeepType.micro)
        .tracking(1.2)
        .foregroundStyle(.driftGrey)
      content()
        .font(DeepType.body)
        .foregroundStyle(.deepPlum)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frostedCard(cornerRadius: .card)
        .overlay(
          RoundedRectangle(cornerRadius: .card, style: .continuous)
            .strokeBorder(.lavenderMist, lineWidth: focusedField == field ? 1.5 : 0)
        )
    }
    .animation(.settle, value: focusedField)
  }

  private func submit() {
    do {
      try accountStore.createAccount(name: name, email: email, password: password)
      withAnimation(.exhale) { errorMessage = nil }
      advance(.welcome)
    } catch {
      withAnimation(.settle) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something didn't go through. Try again."
      }
    }
  }
}

#Preview("Onboarding — Email sign-up") {
  NavigationStack {
    EmailSignUpView()
      .environment(\.accountStore, MockAccountStore.signedOut)
  }
}
