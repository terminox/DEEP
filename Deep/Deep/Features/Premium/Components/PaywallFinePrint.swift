import SwiftUI

/// Where a restore attempt has got to. Mirrors the machine Settings already
/// runs, so backing out of the App Store prompt says nothing in either place.
enum PaywallRestorePhase: Equatable {
  case idle
  case working
  /// The App Store answered, and there was nothing on this account to bring
  /// back. Worth saying: silence after tapping Restore reads as a dead button.
  case nothingFound
  /// Something was restored. The screen itself becomes the acknowledgement, so
  /// this is carried by the member stage rather than by the fine print.
  case restored
  case failed
}

/// The foot of the paywall: what will be charged, that it renews, the two legal
/// documents, and a way back to a purchase already made.
///
/// None of this is decoration. App Review rejects a subscription screen that
/// doesn't state its terms or link its documents, so this band ships even in
/// the states where there is no price to name.
struct PaywallFinePrint: View {
  @Environment(\.locale) private var locale
  @Environment(\.legalLinks) private var legalLinks

  /// `nil` when there is no plan to price — the offline branch keeps the links
  /// and the restore, and simply says nothing about money.
  var billingLine: String?
  let restore: PaywallRestorePhase
  let onRestore: () -> Void

  var body: some View {
    VStack(spacing: 10) {
      if let billingLine {
        Text(billingLine)
          .fixedSize(horizontal: false, vertical: true)
      }

      Text("Your subscription renews automatically until you cancel it in your App Store settings.")
        .fixedSize(horizontal: false, vertical: true)

      Text(LegalCopy.invitation(legalLinks, locale: locale))
        .tint(.deepPlum)

      restoreControl
        .padding(.top, 2)
    }
    .font(DeepType.micro)
    .foregroundStyle(.driftGrey)
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private var restoreControl: some View {
    switch restore {
    case .working:
      Text("Restoring…")
    case .restored:
      // Reached only if the restore brought back nothing that changes the
      // screen; normally the member acknowledgement takes over from here.
      Text("Restored. Welcome back.")
    case .idle, .failed, .nothingFound:
      VStack(spacing: 6) {
        Button(action: onRestore) {
          Text("Restore purchases")
            .font(DeepType.micro.weight(.medium))
            .foregroundStyle(.deepPlum)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        // Quiet lines, never an alert — the same way Settings says it.
        if restore == .failed {
          Text("We couldn't restore just now. Please try again in a moment.")
        } else if restore == .nothingFound {
          Text("There's nothing to restore on this Apple Account.")
        }
      }
    }
  }
}

#if DEBUG
#Preview("Paywall fine print") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: .rhythm) {
      PaywallFinePrint(
        billingLine: PaywallCopy.billingLine(
          PaywallPricing.billingFacts(for: MockSubscriptionStore.samplePlans[0]),
          currency: MockSubscriptionStore.currency,
          locale: Locale(identifier: "en_US")
        ),
        restore: .idle,
        onRestore: {}
      )
      PaywallFinePrint(billingLine: nil, restore: .failed, onRestore: {})
    }
    .padding(.horizontal, .edge)
  }
}
#endif
