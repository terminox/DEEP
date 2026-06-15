import SwiftUI

/// The cause detail's primary action, pinned to the bottom: send a heart to the
/// whole cause in one tap. Dims once the balance is spent, and shows the hearts
/// left so the user always knows what they have to give.
struct SendAHeartBar: View {
  @Environment(\.heartLedger) private var ledger
  let category: CompassionCategory

  @State private var burst = 0

  var body: some View {
    Button {
      ledger.sendHeart(to: category)
      burst += 1
    } label: {
      HStack(spacing: 10) {
        Image(systemName: "heart.fill")
          .font(.system(size: 16, weight: .semibold))
        if ledger.canGive {
          Text("Send a Heart")
          Spacer(minLength: 8)
          Text("\(ledger.balance.formatted()) left")
            .font(DeepType.caption.weight(.medium))
            .opacity(0.85)
            .contentTransition(.numericText(value: Double(ledger.balance)))
        } else {
          Text("No hearts left to give")
          Spacer(minLength: 8)
          Text("Practise to earn more")
            .font(DeepType.caption.weight(.medium))
            .opacity(0.85)
        }
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
      .opacity(ledger.canGive ? 1 : 0.55)
      .shadow(color: Color.lavenderMist.opacity(0.35), radius: 18, y: 10)
    }
    .buttonStyle(.softPress)
    .disabled(!ledger.canGive)
    .heartBurst(trigger: burst)
    .padding(.horizontal, .edge)
    .padding(.bottom, 6)
    .accessibilityLabel("Send a heart to \(category.name)")
    .accessibilityHint(ledger.canGive ? "\(ledger.balance) hearts left" : "No hearts left")
  }
}

#Preview("Send a heart bar") {
  VStack {
    Spacer()
    SendAHeartBar(category: CompassionLibrary.nature)
      .environment(\.heartLedger, .sample)
    SendAHeartBar(category: CompassionLibrary.nature)
      .environment(\.heartLedger, .spent)
  }
  .background { AtmosphereBackground() }
}
