import SwiftUI

/// The soft, dismissable paywall — the last step before the app. Re-cast from
/// the Calm reference's subscribe screen, but true to Deep's "invitation, never
/// demand": a quiet "Maybe later" always lets the user in. Both subscribing and
/// declining call `onboardingFinish()`.
struct OnboardingPaywallView: View {
  @Environment(\.subscriptionStore) private var store
  @Environment(\.onboardingFinish) private var finish

  @State private var selectedPlanID: String?
  @State private var isPurchasing = false

  private struct Benefit: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
  }

  private let benefits: [Benefit] = [
    Benefit(symbol: "waveform", title: "Unhurried sounds, meditations & sleep stories"),
    Benefit(symbol: "globe.asia.australia.fill", title: "Shared global pauses, whenever you need one"),
    Benefit(symbol: "leaf.fill", title: "A space that grows softer the more you return"),
  ]

  var body: some View {
    ZStack(alignment: .topLeading) {
      AtmosphereBackground()

      ScrollView {
        VStack(spacing: .rhythm) {
          VStack(spacing: 10) {
            Text("Begin your journey, gently.")
              .font(DeepType.displayTitle)
              .foregroundStyle(.deepPlum)
              .multilineTextAlignment(.center)
            Text("Everything Deep offers, whenever you're ready.")
              .font(DeepType.body)
              .foregroundStyle(.driftGrey)
              .multilineTextAlignment(.center)
          }
          .padding(.top, 56)

          VStack(alignment: .leading, spacing: 16) {
            ForEach(benefits) { benefit in
              HStack(spacing: 14) {
                Image(systemName: benefit.symbol)
                  .font(.system(size: 16))
                  .foregroundStyle(.lavenderMist)
                  .frame(width: 40, height: 40)
                  .background(Circle().fill(.white.opacity(0.5)))
                Text(benefit.title)
                  .font(DeepType.body)
                  .foregroundStyle(.deepPlum)
                  .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
              }
            }
          }

          plansSection

          VStack(spacing: 6) {
            OnboardingPrimaryButton(title: primaryTitle, isEnabled: !isPurchasing) {
              Task { await purchaseSelected() }
            }
            OnboardingGhostButton(title: "Maybe later") { finish() }
          }

          Text("Cancel anytime. What you share in Deep stays in Deep.")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, .edge)
        .padding(.bottom, .rhythm)
      }
      .scrollIndicators(.hidden)

      GlassCloseButton { finish() }
        .padding(.leading, .edge)
        .padding(.top, 8)
    }
    .navigationBarBackButtonHidden(true)
    .task {
      await store.loadPlans()
      if selectedPlanID == nil {
        selectedPlanID = store.plans.first(where: { $0.period == .yearly })?.id ?? store.plans.first?.id
      }
    }
  }

  @ViewBuilder
  private var plansSection: some View {
    if store.plans.isEmpty {
      // Offline / store not configured — the gentle fallback. "Maybe later"
      // still works, so the user is never trapped.
      Text("Plans are taking a moment to load.")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    } else {
      HStack(spacing: 14) {
        ForEach(store.plans) { plan in
          PlanCard(
            plan: plan,
            isSelected: selectedPlanID == plan.id,
            highlight: plan.period == .yearly ? "Best value" : nil
          ) {
            withAnimation(.settle) { selectedPlanID = plan.id }
          }
        }
      }
    }
  }

  private var primaryTitle: String {
    if isPurchasing { return "One moment…" }
    let selected = store.plans.first(where: { $0.id == selectedPlanID })
    return selected?.trialNote != nil ? "Start free trial" : "Begin your journey"
  }

  private func purchaseSelected() async {
    guard let plan = store.plans.first(where: { $0.id == selectedPlanID }) else { return }
    isPurchasing = true
    defer { isPurchasing = false }
    try? await store.purchase(plan)
    if store.isSubscribed { finish() }
  }
}

#Preview("Onboarding — Paywall") {
  OnboardingPaywallView()
    .environment(\.subscriptionStore, MockSubscriptionStore.free)
}
