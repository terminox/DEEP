import SwiftUI

/// The "You" tab — a calm account screen with a gentle log-out that signs the
/// user out and returns them to the welcome flow.
///
/// It reads the *shared* onboarding/account stores (threaded down from
/// `AppRootView` through the tab shell), so resetting onboarding here flips the
/// gate `AppRootView` watches and crossfades back to onboarding.
struct ProfileView: View {
  @Environment(\.accountStore) private var accountStore
  @Environment(\.onboardingStore) private var onboardingStore

  @State private var showLogoutConfirm = false

  private var account: Account? { accountStore.account }

  var body: some View {
    ZStack {
      AtmosphereBackground()

      VStack(spacing: .rhythm) {
        Spacer()

        avatar
        VStack(spacing: 6) {
          Text(account?.displayName ?? "Friend")
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
          if let email = account?.email {
            Text(email)
              .font(DeepType.caption)
              .foregroundStyle(.driftGrey)
          }
          methodChip
        }

        Spacer()

        VStack(spacing: 10) {
          Button(role: .destructive) {
            showLogoutConfirm = true
          } label: {
            Text("Log out")
              .font(DeepType.sectionTitle)
              .foregroundStyle(.deepPlum)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 18)
              .frostedCard(cornerRadius: .chip)
          }
          .buttonStyle(.softPress)

          Text("This signs you out and gently returns you to the start.")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .multilineTextAlignment(.center)
        }
      }
      .padding(.horizontal, .edge)
      .padding(.vertical, .rhythm)
    }
    .confirmationDialog(
      "Log out of Deep?",
      isPresented: $showLogoutConfirm,
      titleVisibility: .visible
    ) {
      Button("Log out", role: .destructive, action: logOut)
      Button("Stay", role: .cancel) {}
    } message: {
      Text("You'll start fresh from the welcome flow. What you've shared stays safe.")
    }
  }

  private var avatar: some View {
    Circle()
      .fill(
        LinearGradient(
          colors: ArtworkPalette.dusk.colors,
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .frame(width: 96, height: 96)
      .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
      .overlay(
        Text(initials)
          .font(.system(.title, design: .serif, weight: .light))
          .foregroundStyle(.white)
      )
      .shadow(color: Color.lavenderMist.opacity(0.4), radius: 18, y: 8)
  }

  @ViewBuilder
  private var methodChip: some View {
    if let method = account?.method {
      Label(
        method == .apple ? "Signed in with Apple" : "Signed in with email",
        systemImage: method == .apple ? "applelogo" : "envelope.fill"
      )
      .font(DeepType.micro)
      .foregroundStyle(.driftGrey)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(Capsule().fill(.white.opacity(0.5)))
      .padding(.top, 4)
    }
  }

  private var initials: String {
    let name = account?.displayName ?? "Friend"
    let letters = name.split(separator: " ").compactMap(\.first).prefix(2)
    return letters.isEmpty ? "·" : String(letters).uppercased()
  }

  private func logOut() {
    Task {
      await accountStore.logOut()
      // Resetting onboarding flips `hasCompletedOnboarding`, which `AppRootView`
      // observes — together with the now-signed-out state it crossfades back to
      // the welcome flow.
      onboardingStore.reset()
    }
  }
}

#Preview("Profile — email user") {
  ProfileView()
    .environment(\.accountStore, MockAccountStore.emailUser)
    .environment(\.onboardingStore, MockOnboardingStore.fresh)
}

#Preview("Profile — apple user") {
  ProfileView()
    .environment(\.accountStore, MockAccountStore.appleUser)
    .environment(\.onboardingStore, MockOnboardingStore.fresh)
}
