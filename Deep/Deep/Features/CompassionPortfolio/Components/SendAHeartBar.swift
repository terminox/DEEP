import SwiftUI

/// The cause detail's primary action, pinned to the bottom: send a heart to the
/// whole cause in one tap.
///
/// Once the balance is spent it stops being a dimmed button and becomes a quiet
/// frosted note instead — a disabled CTA reads as something broken, and Deep
/// would rather say "come back after a practice" than "you can't".
struct SendAHeartBar: View {
  @Environment(\.heartLedger) private var ledger
  let category: CompassionCategory

  @State private var burst = 0

  var body: some View {
    Group {
      if ledger.canGive {
        sendButton
      } else {
        spentNote
      }
    }
    .animation(.exhale, value: ledger.canGive)
    .padding(.horizontal, .edge)
    .padding(.bottom, 6)
  }

  private var sendButton: some View {
    Button {
      ledger.sendHeart(to: category)
      burst += 1
    } label: {
      HStack(spacing: 10) {
        Image(systemName: "heart.fill")
          .font(.system(size: 16, weight: .semibold))
        Text("Send a heart")
        Spacer(minLength: 8)
        Text("\(ledger.balance.formatted()) left")
          .font(DeepType.caption.weight(.medium))
          .opacity(0.85)
          .contentTransition(.numericText(value: Double(ledger.balance)))
      }
      .font(DeepType.sectionTitle)
      .foregroundStyle(.white)
      .padding(.horizontal, 22)
      .padding(.vertical, 16)
      .frame(maxWidth: .infinity)
      .background {
        Capsule().fill(
          LinearGradient(colors: [.lavenderMist, .blushPowder], startPoint: .leading, endPoint: .trailing)
        )
      }
      .shadow(color: Color.lavenderMist.opacity(0.35), radius: 18, y: 10)
    }
    .buttonStyle(.softPress)
    .heartBurst(trigger: burst)
    .accessibilityLabel("Send a heart to \(category.name)")
    .accessibilityHint("\(ledger.balance) hearts left")
  }

  private var spentNote: some View {
    HStack(spacing: 10) {
      Image(systemName: "heart")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.driftGrey)
      Text("No hearts left")
        .font(DeepType.sectionTitle)
        .foregroundStyle(.deepPlum)
        .lineLimit(1)
      Spacer(minLength: 8)
      Text("Practice earns more")
        .font(DeepType.caption.weight(.medium))
        .foregroundStyle(.driftGrey)
        .lineLimit(1)
    }
    .padding(.horizontal, 22)
    .padding(.vertical, 16)
    .frame(maxWidth: .infinity)
    .frostedCard(cornerRadius: .chip)
    .accessibilityElement(children: .combine)
  }
}

#Preview("Send a heart bar") {
  VStack(spacing: 12) {
    Spacer()
    SendAHeartBar(category: CompassionLibrary.nature)
      .environment(\.heartLedger, .sample)
    SendAHeartBar(category: CompassionLibrary.nature)
      .environment(\.heartLedger, .spent)
  }
  .padding(.bottom, .rhythm)
  .background { AtmosphereBackground() }
}
