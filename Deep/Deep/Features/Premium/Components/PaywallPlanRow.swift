import SwiftUI

/// One selectable plan: its name and what it costs, with what a year saves said
/// plainly beside it.
///
/// It wears the quiz option card's selection grammar — the same frosted card,
/// the same lavender border, the same check — but moves the mark to the leading
/// edge, because the trailing edge here belongs to the price. Nothing new is
/// invented; the pieces just stand in a different order.
struct PaywallPlanRow: View {
  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  let plan: SubscriptionPlan
  /// What this plan saves against the other one. `nil` on the plan that is the
  /// baseline, and whenever there is nothing honest to claim.
  var savings: Double? = nil
  /// Whether this row carries its own trial note. The screen states a shared
  /// trial once above the group instead; this is for when the plans differ.
  var showsTrialNote: Bool = false
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Group {
        if dynamicTypeSize.isAccessibilitySize {
          // At these sizes a two-column row can only fight itself. One column,
          // always — a layout that decides differently between launches is
          // worse than one that always stacks.
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
              selectionMark
              name
            }
            trialNote
            priceColumn(alignment: .leading)
          }
        } else {
          HStack(spacing: 14) {
            selectionMark
            VStack(alignment: .leading, spacing: 3) {
              name
              subline
              trialNote
            }
            // A greedy frame rather than a Spacer: a Spacer bids against the
            // text column and wraps the plan's name on a row with room to
            // spare.
            .frame(maxWidth: .infinity, alignment: .leading)
            priceColumn(alignment: .trailing)
          }
        }
      }
      .padding(.vertical, 16)
      .padding(.horizontal, 18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .frostedCard(cornerRadius: .card)
      .overlay(
        RoundedRectangle(cornerRadius: .card, style: .continuous)
          .strokeBorder(.lavenderMist, lineWidth: isSelected ? 1.5 : 0)
      )
      .contentShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
    }
    .buttonStyle(.softPress)
    .animation(.settle, value: isSelected)
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }

  // MARK: - Bands

  @ViewBuilder
  private var selectionMark: some View {
    if isSelected {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 22))
        .foregroundStyle(.lavenderMist)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    } else {
      Circle()
        .strokeBorder(Color.driftGrey.opacity(0.5), lineWidth: 1.5)
        .frame(width: 22, height: 22)
    }
  }

  private var name: some View {
    Text(plan.period == .yearly ? "Yearly" : "Monthly")
      .font(DeepType.body)
      .foregroundStyle(.deepPlum)
  }

  private var subline: some View {
    Text(PaywallCopy.planSubline(for: plan, locale: locale))
      .font(DeepType.caption)
      .foregroundStyle(.driftGrey)
  }

  @ViewBuilder
  private var trialNote: some View {
    if showsTrialNote, let note = plan.trialNote {
      Text(note)
        .font(DeepType.micro)
        .foregroundStyle(.irisDusk)
    }
  }

  private func priceColumn(alignment: HorizontalAlignment) -> some View {
    VStack(alignment: alignment, spacing: 5) {
      Text(plan.displayPrice)
        .font(DeepType.body.weight(.semibold))
        .foregroundStyle(.deepPlum)
      if dynamicTypeSize.isAccessibilitySize {
        subline
      }
      if let savings {
        Text(PaywallCopy.savingsBadge(fraction: savings, locale: locale))
          .font(DeepType.micro)
          .foregroundStyle(.irisDusk)
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          // The inset tonal panel, not a rule and not a new style.
          .pebble(cornerRadius: .chip)
      }
    }
  }
}

#if DEBUG
#Preview("Paywall plan row") {
  @Previewable @State var selected = DeepProduct.yearly
  ZStack {
    AtmosphereBackground()
    VStack(spacing: 14) {
      ForEach(MockSubscriptionStore.samplePlans) { plan in
        PaywallPlanRow(
          plan: plan,
          savings: plan.period == .yearly
            ? PaywallPricing.yearlySavings(in: MockSubscriptionStore.samplePlans)
            : nil,
          isSelected: selected == plan.id,
          action: { selected = plan.id }
        )
      }
    }
    .padding(.horizontal, .edge)
  }
}

#Preview("Paywall plan row — large type") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: 14) {
      ForEach(MockSubscriptionStore.samplePlans) { plan in
        PaywallPlanRow(
          plan: plan,
          savings: plan.period == .yearly
            ? PaywallPricing.yearlySavings(in: MockSubscriptionStore.samplePlans)
            : nil,
          isSelected: plan.period == .yearly,
          action: {}
        )
      }
    }
    .padding(.horizontal, .edge)
  }
  .environment(\.dynamicTypeSize, .accessibility2)
}
#endif
