import SwiftUI

/// A selectable subscription plan tile on the paywall. The selected plan carries
/// a lavender ring and a soft bloom; an optional "best value" / trial ribbon sits
/// above it. Side-by-side, two of these mirror the Calm reference's yearly /
/// monthly choice, re-cast in Deep's palette.
struct PlanCard: View {
  let plan: SubscriptionPlan
  let isSelected: Bool
  var highlight: String? = nil
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 6) {
        if let highlight {
          Text(highlight.uppercased())
            .font(DeepType.micro)
            .tracking(1.2)
            .foregroundStyle(.deepPlum)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(.blushPowder))
            .padding(.bottom, 2)
        }

        Text(plan.title)
          .font(DeepType.sectionTitle)
          .foregroundStyle(.deepPlum)

        Text(plan.perMonthLabel ?? plan.displayPrice)
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)

        if plan.period == .yearly {
          Text(plan.displayPrice + "/yr")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
        }

        if let trial = plan.trialNote {
          Text(trial)
            .font(DeepType.caption)
            .foregroundStyle(.lavenderMist)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(18)
      .frostedCard(cornerRadius: .card)
      .overlay(
        RoundedRectangle(cornerRadius: .card, style: .continuous)
          .strokeBorder(.lavenderMist, lineWidth: isSelected ? 2 : 0)
      )
      .contentShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
      .scaleEffect(isSelected ? 1.0 : 0.97)
    }
    .buttonStyle(.softPress)
    .animation(.settle, value: isSelected)
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }
}

#Preview("Plan cards") {
  ZStack {
    AtmosphereBackground()
    HStack(spacing: 14) {
      PlanCard(
        plan: SubscriptionPlan(id: "y", period: .yearly, displayPrice: "$59.99", perMonthLabel: "$4.99/mo", trialNote: "7-day free trial"),
        isSelected: true,
        highlight: "Best value",
        action: {}
      )
      PlanCard(
        plan: SubscriptionPlan(id: "m", period: .monthly, displayPrice: "$9.99", perMonthLabel: "$9.99/mo"),
        isSelected: false,
        action: {}
      )
    }
    .padding(.horizontal, .edge)
  }
}
