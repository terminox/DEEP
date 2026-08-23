import SwiftUI
import StoreKit

/// The "You" tab — identity (with the non-actionable plan chip) up top, then
/// Calm-inspired cards of purely actionable rows: subscription (manage /
/// restore) and account (log out / delete), closing on a quiet version footer.
///
/// It reads the *shared* stores (threaded down from `AppRootView` through the
/// tab shell), so resetting onboarding here flips the gate `AppRootView`
/// watches and crossfades back to onboarding.
struct ProfileView: View {
  @Environment(\.accountStore) private var accountStore
  @Environment(\.onboardingStore) private var onboardingStore
  @Environment(\.subscriptionStore) private var subscriptionStore
  @Environment(\.practiceStore) private var practiceStore
  @Environment(\.gardenStore) private var gardenStore
  @Environment(\.heartLedger) private var heartLedger

  @State private var showLogoutConfirm = false
  @State private var showDeleteConfirm = false
  @State private var showManageSubscriptions = false
  @State private var restorePhase: RestorePhase = .idle
  @State private var isDeletingAccount = false
  @State private var deleteFailed = false

  private enum RestorePhase: Equatable {
    case idle, working, restored, failed
  }

  private var account: Account? { accountStore.account }

  var body: some View {
    ZStack {
      AtmosphereBackground()

      ScrollView {
        VStack(spacing: .rhythm) {
          identityHeader
          membershipSection
          accountSection
          footer
        }
        .padding(.horizontal, .edge)
        .padding(.top, .rhythm)
        .padding(.bottom, 40)
      }
      .scrollIndicators(.hidden)
    }
    .task { await subscriptionStore.loadPlans() }
    .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
    .confirmationDialog(
      "Log out of DEEP?",
      isPresented: $showLogoutConfirm,
      titleVisibility: .visible
    ) {
      Button("Log out", role: .destructive, action: logOut)
      Button("Stay", role: .cancel) {}
    } message: {
      Text("You'll start fresh from the welcome flow. What you've shared stays safe.")
    }
    .alert("Delete your account?", isPresented: $showDeleteConfirm) {
      Button("Delete", role: .destructive, action: deleteAccount)
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This permanently erases your account and everything you've shared. "
        + "If you have a DEEP Pro subscription, cancel it separately in your "
        + "App Store settings — deleting your account doesn't cancel billing."
      )
    }
    .alert("Something went wrong", isPresented: $deleteFailed) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("We couldn't delete your account. Please try again in a moment.")
    }
  }

  // MARK: - Identity

  private var identityHeader: some View {
    VStack(spacing: 6) {
      avatar
        .padding(.bottom, 6)
      Text(account?.displayName ?? "Friend")
        .font(DeepType.displayTitle)
        .foregroundStyle(.deepPlum)
      if let email = account?.email {
        Text(email)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      } else if account?.method == .apple {
        Text("Signed in with Apple")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      }
      planChip
    }
    .frame(maxWidth: .infinity)
    .padding(.top, .rhythm)
    .padding(.bottom, 8)
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
      .frame(width: 64, height: 64)
      .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
      .overlay(
        Text(initials)
          .font(.system(.title3, design: .serif, weight: .light))
          .foregroundStyle(.white)
      )
      .shadow(color: Color.lavenderMist.opacity(0.4), radius: 18, y: 8)
  }

  /// The non-actionable membership status, worn as part of the identity —
  /// the cards below stay purely actionable.
  private var planChip: some View {
    Label(planLabel, systemImage: "sparkles")
      .font(DeepType.micro)
      .foregroundStyle(.driftGrey)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(Capsule().fill(.white.opacity(0.5)))
      .padding(.top, 4)
  }

  private var planLabel: String {
    switch subscriptionStore.status {
    case .subscribed(let productID):
      switch productID {
      case DeepProduct.yearly: return "DEEP Pro · Yearly"
      case DeepProduct.monthly: return "DEEP Pro · Monthly"
      default: return "DEEP Pro"
      }
    case .none:
      return "Free plan"
    case .unknown:
      return "Checking…"
    }
  }

  private var initials: String {
    let name = account?.displayName ?? "Friend"
    let letters = name.split(separator: " ").compactMap(\.first).prefix(2)
    return letters.isEmpty ? "·" : String(letters).uppercased()
  }

  // MARK: - Membership

  private var membershipSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      SettingsSection(title: "Membership") {
        SettingsRow(icon: "creditcard", title: "Manage subscription", accessory: .chevron) {
          showManageSubscriptions = true
        }
        SettingsRow(
          icon: "arrow.clockwise",
          title: "Restore purchases",
          accessory: restoreAccessory,
          action: restorePurchases
        )
      }
      if restorePhase == .failed {
        Text("Couldn't reach the App Store. Please try again in a moment.")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .padding(.horizontal, 8)
      }
    }
  }

  private var restoreAccessory: SettingsRow.Accessory {
    switch restorePhase {
    case .idle, .failed: return .none
    case .working: return .progress
    case .restored: return .value("Restored")
    }
  }

  private func restorePurchases() {
    guard restorePhase != .working else { return }
    restorePhase = .working
    Task {
      do {
        try await subscriptionStore.restore()
        restorePhase = .restored
      } catch is CancellationError {
        // Backing out of the App Store prompt — nothing happened, say nothing.
        restorePhase = .idle
        return
      } catch {
        restorePhase = .failed
      }
      try? await Task.sleep(for: .seconds(2.5))
      withAnimation(.settle) { restorePhase = .idle }
    }
  }

  // MARK: - Account

  private var accountSection: some View {
    SettingsSection(title: "Account") {
      SettingsRow(
        icon: "rectangle.portrait.and.arrow.right",
        title: "Log out",
        role: .destructive
      ) {
        showLogoutConfirm = true
      }
      SettingsRow(
        icon: "trash",
        title: "Delete account",
        accessory: isDeletingAccount ? .progress : .none,
        role: .destructive,
        tint: .duskRose
      ) {
        guard !isDeletingAccount else { return }
        showDeleteConfirm = true
      }
    }
  }

  private func logOut() {
    Task {
      await accountStore.logOut()
      // Resetting onboarding flips `hasCompletedOnboarding`, which `AppRootView`
      // observes — together with the now-signed-out state it crossfades back to
      // the welcome flow. The practice journal, garden, and wallet belong to
      // the account, so they leave with it — a later sign-up must never open
      // on this user's plants or balance.
      onboardingStore.reset()
      practiceStore.reset()
      gardenStore.resetLocalState()
      heartLedger.resetLocalState()
    }
  }

  private func deleteAccount() {
    isDeletingAccount = true
    Task {
      do {
        try await accountStore.deleteAccount()
        // Same exit as log out; the shell crossfades to the welcome flow, so
        // the in-flight state never needs resetting on success.
        onboardingStore.reset()
        practiceStore.reset()
        gardenStore.resetLocalState()
        heartLedger.resetLocalState()
      } catch {
        isDeletingAccount = false
        deleteFailed = true
      }
    }
  }

  // MARK: - Footer

  private var footer: some View {
    Text(versionLine)
      .font(DeepType.micro)
      .foregroundStyle(.driftGrey.opacity(0.8))
      .frame(maxWidth: .infinity)
      .padding(.top, 8)
  }

  private var versionLine: String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "—"
    let build = info?["CFBundleVersion"] as? String ?? "—"
    return "DEEP v\(version) (\(build))"
  }
}

#Preview("Profile — email user, subscribed") {
  ProfileView()
    .environment(\.accountStore, MockAccountStore.emailUser)
    .environment(\.onboardingStore, MockOnboardingStore.fresh)
    .environment(\.subscriptionStore, MockSubscriptionStore.subscribed)
}

#Preview("Profile — apple user, free") {
  ProfileView()
    .environment(\.accountStore, MockAccountStore.appleUser)
    .environment(\.onboardingStore, MockOnboardingStore.fresh)
    .environment(\.subscriptionStore, MockSubscriptionStore.free)
}
