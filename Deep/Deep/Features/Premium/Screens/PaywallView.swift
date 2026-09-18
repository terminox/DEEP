import SwiftUI

/// The one paywall. Every door opens onto this screen; only the headline and
/// the subhead know which door it was.
///
/// It is a screen, not a sheet or a cover — a place you go, pushed onto the
/// stack from Settings and stood up as a step in the first run. One arrangement
/// serves both, so nothing about it has to branch on how it was reached.
///
/// There is no close control in a corner, deliberately. An X reads as an escape
/// hatch from a demand, and this is meant to read as an invitation: the way out
/// is a quiet "Not right now" at the foot.
struct PaywallView: View {
  @Environment(\.subscriptionStore) private var subscriptionStore
  @Environment(\.locale) private var locale

  let source: PaywallSource
  /// What happens when the member is done here — bought, or declined. The
  /// screen never leaves under its own power: the You coordinator pops it, the
  /// onboarding coordinator routes on. Routing stays where it belongs.
  let onFinish: () -> Void

  /// Where a purchase has got to. `welcoming` is the beat between a successful
  /// purchase and leaving the screen.
  enum PurchasePhase: Equatable {
    case idle
    case purchasing(productID: String)
    case pending
    case failed
    case welcoming
  }

  @State private var selectedPlanID: String?
  @State private var purchase: PurchasePhase
  @State private var restore: PaywallRestorePhase = .idle
  /// Whether `loadPlans()` has returned at least once. Without it, "still
  /// loading" and "the store has nothing for us" look identical.
  @State private var hasAttemptedLoad = false

  /// `purchase` is injectable so a preview can open the screen already in a
  /// state that a tap would otherwise have to produce.
  init(
    source: PaywallSource,
    onFinish: @escaping () -> Void,
    purchase: PurchasePhase = .idle
  ) {
    self.source = source
    self.onFinish = onFinish
    _purchase = State(initialValue: purchase)
  }

  // MARK: - Stage

  /// What the screen *is*, as opposed to what the member is doing on it —
  /// purchasing decorates the ready stage rather than replacing it.
  private enum Stage: Equatable {
    case loading
    case unreachable
    case ready
    case member
    case welcoming
  }

  private var stage: Stage {
    // Order matters: a completed purchase flips `isSubscribed`, which would
    // otherwise swap the screen to the already-a-member acknowledgement instead
    // of letting the welcome beat play.
    if purchase == .welcoming { return .welcoming }
    if subscriptionStore.isSubscribed { return .member }
    if !subscriptionStore.plans.isEmpty { return .ready }
    return hasAttemptedLoad ? .unreachable : .loading
  }

  /// Yearly is the preselection, without needing to be written into state: an
  /// untouched selection simply resolves to it.
  private var selectedPlan: SubscriptionPlan? {
    if let selectedPlanID,
       let chosen = subscriptionStore.plans.first(where: { $0.id == selectedPlanID }) {
      return chosen
    }
    return subscriptionStore.plans.first(where: { $0.period == .yearly })
      ?? subscriptionStore.plans.first
  }

  private var trialDays: Int? { selectedPlan?.freeTrialDays }

  /// Stages whose content is a few lines rather than a screenful.
  private var isShortStage: Bool { stage == .welcoming || stage == .member }

  private var isPurchasing: Bool {
    if case .purchasing = purchase { return true }
    return false
  }

  var body: some View {
    ZStack {
      // The screen owns its own ground, so it reads the same whether it is
      // pushed from Settings or standing as a step in the onboarding flow.
      AtmosphereBackground()
      content
    }
    .animation(.bloom, value: stage)
    .sensoryFeedback(.selection, trigger: selectedPlanID)
    .sensoryFeedback(.success, trigger: stage == .welcoming)
    .task {
      await subscriptionStore.loadPlans()
      hasAttemptedLoad = true
    }
  }

  /// Only the act is pinned. The fine print scrolls with the content it
  /// describes — pinning it too would leave the plan rows a sliver of screen to
  /// live in, with the monthly option hidden behind a wall of terms.
  private var content: some View {
    ScrollView {
      VStack(spacing: .rhythm) {
        hero
        if stage != .member {
          benefits
        }
        planBand
        if stage != .member, stage != .welcoming {
          PaywallFinePrint(
            billingLine: billingLine,
            restore: restore,
            onRestore: restorePurchases
          )
        }
      }
      .padding(.horizontal, .edge)
      .padding(.top, .rhythm)
      .padding(.bottom, 12)
      // The welcome beat and the member acknowledgement are a few lines each;
      // left at the top of a full-height screen they sit above a void. Centring
      // them is the reward screens' arrangement — applied only there, since
      // pinning a scrolling screen to the container's height would clip
      // everything past the fold.
      .modifier(CentredWhenShort(isActive: isShortStage))
    }
    .scrollIndicators(.hidden)
    .scrollBounceBehavior(.basedOnSize)
    // A bar rather than a plain inset: only a bar earns the scroll edge
    // effect, which softens the terms as they pass under the act instead of
    // slicing a sentence in half at the fold.
    .safeAreaBar(edge: .bottom) { actionBar }
    // Both edges: the screen carries no navigation bar, so scrolled content
    // would otherwise pass hard under the status bar as well as under the act.
    .scrollEdgeEffectStyle(.soft, for: .all)
  }

  // MARK: - Hero

  @ViewBuilder
  private var hero: some View {
    VStack(spacing: 14) {
      // The same lockup the account screen wears, a size down: arriving here
      // straight from signing up, it should read as the same doorway.
      DeepLogoMark(
        size: stage == .welcoming ? 72 : 56,
        tint: .moonCream,
        isGlowing: true
      )
      .padding(.top, 4)

      Image("OnboardingLogoText")
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .foregroundStyle(.irisDusk)
        .frame(maxWidth: 170)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("DEEP — peace begins within")
        .shadow(color: .moonCream.opacity(0.8), radius: 12)

      Text(headline)
        .font(DeepType.displayTitle)
        .foregroundStyle(.deepPlum)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)

      Text(subhead)
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity)
  }

  private var headline: LocalizedStringKey {
    switch stage {
    case .welcoming: return "Welcome to DEEP Premium"
    case .member: return "You're already with us"
    default: return source.headline
    }
  }

  private var subhead: LocalizedStringKey {
    switch stage {
    case .welcoming: return "Everything is open now."
    case .member: return memberSubhead
    default: return source.subhead
    }
  }

  private var memberSubhead: LocalizedStringKey {
    // A restore that just landed here is what the member was waiting to be
    // told; the plan line takes over once the acknowledgement has been read.
    if restore == .restored { return "Restored. Welcome back." }
    guard case .subscribed(let productID) = subscriptionStore.status else {
      return "Your DEEP Premium membership is active."
    }
    switch productID {
    case DeepProduct.yearly: return "Your yearly DEEP Premium membership is active."
    case DeepProduct.monthly: return "Your monthly DEEP Premium membership is active."
    default: return "Your DEEP Premium membership is active."
    }
  }

  // MARK: - Benefits

  /// Constant across every door — what the membership includes doesn't depend
  /// on where you were standing when you asked.
  private var benefits: some View {
    // Two lines, because two is what the app actually unlocks today: premium
    // sounds and premium plants. A third would have to be invented.
    VStack(alignment: .leading, spacing: 18) {
      CraftingChecklistRow("Every sound in the library", isDone: true)
      CraftingChecklistRow("Exclusive plants for your Mind Garden", isDone: true)
    }
    .padding(.vertical, 20)
    .padding(.horizontal, 18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frostedCard(cornerRadius: .card)
  }

  // MARK: - Plans

  @ViewBuilder
  private var planBand: some View {
    switch stage {
    case .loading:
      planSkeleton
    case .unreachable:
      unreachableNote
    case .ready:
      planList
        .allowsHitTesting(!isPurchasing)
    case .member, .welcoming:
      EmptyView()
    }
  }

  private var planList: some View {
    VStack(alignment: .leading, spacing: 14) {
      if let days = sharedTrialDays {
        // Said once over the group, but only when it is true of the group.
        Text("\(days) DAYS FREE")
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)
      }

      ForEach(subscriptionStore.plans) { plan in
        PaywallPlanRow(
          plan: plan,
          savings: plan.period == .yearly ? savings : nil,
          // When the plans don't offer the same trial, the claim belongs to
          // the row that owns it — a banner over a plan with no trial is an
          // offer the store will not honour.
          showsTrialNote: sharedTrialDays == nil,
          isSelected: selectedPlan?.id == plan.id,
          action: { selectedPlanID = plan.id }
        )
      }
    }
  }

  /// The trial every plan offers, or `nil` when they differ — including when
  /// only one of them has one, which is what the bundled StoreKit config
  /// actually describes today.
  private var sharedTrialDays: Int? {
    let trials = subscriptionStore.plans.map(\.freeTrialDays)
    guard let first = trials.first, trials.allSatisfy({ $0 == first }) else { return nil }
    return first
  }

  private var savings: Double? {
    PaywallPricing.yearlySavings(in: subscriptionStore.plans)
  }

  /// Mirrors the real rows' geometry, so nothing jumps when the plans land.
  private var planSkeleton: some View {
    VStack(alignment: .leading, spacing: 14) {
      SkeletonTextLine(width: 96)
      ForEach(0..<2, id: \.self) { _ in
        SkeletonBlock(cornerRadius: .card)
          .frame(height: 84)
      }
    }
    .skeletonBreath()
  }

  private var unreachableNote: some View {
    VStack(spacing: 14) {
      Text("We couldn't reach the App Store just now.")
        .font(DeepType.body)
        .foregroundStyle(.driftGrey)
        .multilineTextAlignment(.center)
      Button {
        Task {
          hasAttemptedLoad = false
          await subscriptionStore.loadPlans()
          hasAttemptedLoad = true
        }
      } label: {
        Text("Try again")
          .font(DeepType.body.weight(.medium))
          .foregroundStyle(.deepPlum)
          .padding(.horizontal, 22)
          .padding(.vertical, 12)
          .frostedCard(cornerRadius: .chip)
      }
      .buttonStyle(.softPress)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
  }

  // MARK: - Action bar

  private var actionBar: some View {
    VStack(spacing: 12) {
      primaryAction

      if let note = quietNote {
        Text(note)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .multilineTextAlignment(.center)
          .transition(.opacity)
      }

      if stage != .member, stage != .welcoming {
        declineControl
      }
    }
    .padding(.horizontal, .edge)
    .padding(.top, 14)
    .padding(.bottom, 12)
    .animation(.exhale, value: purchase)
  }

  @ViewBuilder
  private var primaryAction: some View {
    switch stage {
    case .loading:
      // Not a dimmed button: a disabled CTA reads as something broken. A quiet
      // label holds the same ground until there is something to buy.
      Text("One moment")
        .font(DeepType.body)
        .foregroundStyle(.driftGrey)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 56)
    case .unreachable:
      EmptyView()
    case .ready:
      RewardContinueButton(
        ctaTitle,
        isBusy: isPurchasing,
        accessibilityHint: trialDays == nil
          ? "Subscribes to DEEP Premium"
          : "Starts your free trial of DEEP Premium",
        action: buy
      )
    case .welcoming:
      Text("Everything is open.")
        .font(DeepType.body.weight(.medium))
        .foregroundStyle(.deepPlum)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 56)
    case .member:
      Button(action: onFinish) {
        Text("Done")
          .font(DeepType.body.weight(.medium))
          .foregroundStyle(.deepPlum)
          .frame(maxWidth: .infinity)
          .frame(minHeight: 56)
          .frostedCard(cornerRadius: .chip)
      }
      .buttonStyle(.softPress)
    }
  }

  private var ctaTitle: LocalizedStringKey {
    guard let days = trialDays else { return "Subscribe" }
    return "Start your \(days) days free"
  }

  private var declineControl: some View {
    Button(action: onFinish) {
      Text("Not right now")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private var quietNote: LocalizedStringKey? {
    switch purchase {
    case .failed: return "That didn't go through. Nothing was charged."
    case .pending: return "This purchase needs approval before it can finish."
    case .idle, .purchasing, .welcoming: return nil
    }
  }

  private var billingLine: String? {
    guard stage == .ready, let plan = selectedPlan else { return nil }
    return PaywallCopy.billingLine(
      PaywallPricing.billingFacts(for: plan),
      currency: plan.currency,
      locale: locale
    )
  }

  // MARK: - Acts

  private func buy() {
    guard let plan = selectedPlan else { return }
    purchase = .purchasing(productID: plan.id)
    Task {
      do {
        switch try await subscriptionStore.purchase(plan) {
        case .purchased:
          withAnimation(.bloom) { purchase = .welcoming }
          // A beat to read the welcome, then out. No confetti.
          try? await Task.sleep(for: .seconds(1.8))
          onFinish()
        case .cancelled:
          // Backing out is not a failure. Say nothing at all.
          purchase = .idle
        case .pending:
          purchase = .pending
        }
      } catch is CancellationError {
        purchase = .idle
      } catch {
        purchase = .failed
        try? await Task.sleep(for: .seconds(2.5))
        if purchase == .failed { purchase = .idle }
      }
    }
  }

  /// The restore machine Settings already runs, verbatim: dismissing the App
  /// Store prompt says nothing, a failure is a quiet line, and either way the
  /// row settles back after a beat.
  private func restorePurchases() {
    restore = .working
    Task {
      do {
        try await subscriptionStore.restore()
      } catch is CancellationError {
        restore = .idle
        return
      } catch {
        restore = .failed
        try? await Task.sleep(for: .seconds(2.5))
        if restore == .failed { restore = .idle }
        return
      }
      // A restore that lands turns the screen into the member acknowledgement,
      // which is the confirmation. One that finds nothing has to say so — a
      // Restore that answers with silence reads as a dead button.
      restore = subscriptionStore.isSubscribed ? .restored : .nothingFound
      try? await Task.sleep(for: .seconds(2.5))
      if restore == .restored || restore == .nothingFound { restore = .idle }
    }
  }
}

/// Fills the scroll container and centres its content, but only while asked to.
/// A short screen otherwise hangs from the top edge of a full-height screen.
private struct CentredWhenShort: ViewModifier {
  let isActive: Bool

  func body(content: Content) -> some View {
    if isActive {
      content.containerRelativeFrame(.vertical, alignment: .center)
    } else {
      content
    }
  }
}

#if DEBUG
#Preview("Paywall — plans loaded") {
  PaywallView(source: .settings) {}
    .environment(\.subscriptionStore, MockSubscriptionStore.free)
    .environment(\.legalLinks, .placeholder)
}

#Preview("Paywall — only the year has a trial") {
  PaywallView(source: .settings) {}
    .environment(\.subscriptionStore, MockSubscriptionStore.mixedTrials)
    .environment(\.legalLinks, .placeholder)
}

#Preview("Paywall — loading plans") {
  PaywallView(source: .settings) {}
    .environment(\.subscriptionStore, MockSubscriptionStore.loadingPlans)
    .environment(\.legalLinks, .placeholder)
}

#Preview("Paywall — store unreachable") {
  PaywallView(source: .settings) {}
    .environment(\.subscriptionStore, MockSubscriptionStore.unreachable)
    .environment(\.legalLinks, .placeholder)
}

#Preview("Paywall — purchasing") {
  PaywallView(source: .settings, onFinish: {}, purchase: .purchasing(productID: DeepProduct.yearly))
  .environment(\.subscriptionStore, MockSubscriptionStore.free)
  .environment(\.legalLinks, .placeholder)
}

#Preview("Paywall — purchase failed") {
  PaywallView(source: .settings, onFinish: {}, purchase: .failed)
    .environment(\.subscriptionStore, MockSubscriptionStore.free)
    .environment(\.legalLinks, .placeholder)
}

#Preview("Paywall — welcome beat") {
  PaywallView(source: .settings, onFinish: {}, purchase: .welcoming)
    .environment(\.subscriptionStore, MockSubscriptionStore.free)
    .environment(\.legalLinks, .placeholder)
}

#Preview("Paywall — already a member") {
  PaywallView(source: .settings) {}
    .environment(\.subscriptionStore, MockSubscriptionStore.subscribed)
    .environment(\.legalLinks, .placeholder)
}

#Preview("Paywall — onboarding step") {
  PaywallView(source: .onboarding) {}
    .environment(\.subscriptionStore, MockSubscriptionStore.free)
    .environment(\.legalLinks, .placeholder)
}

#Preview("Paywall — from a locked sound") {
  PaywallView(source: .lockedSound) {}
    .environment(\.subscriptionStore, MockSubscriptionStore.free)
    .environment(\.legalLinks, .placeholder)
}

#Preview("Paywall — large type") {
  PaywallView(source: .settings) {}
    .environment(\.subscriptionStore, MockSubscriptionStore.free)
    .environment(\.legalLinks, .placeholder)
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Paywall — Thai") {
  PaywallView(source: .settings) {}
    .environment(\.subscriptionStore, MockSubscriptionStore.free)
    .environment(\.legalLinks, .placeholder)
    .environment(\.locale, Locale(identifier: "th"))
}
#endif
