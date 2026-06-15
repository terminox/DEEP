import SwiftUI

/// One initiative within a cause: what it does, who it's reached, how far along
/// it is, and a one-tap heart to back it. Sending updates the live ledger, so
/// the count climbs in place.
struct CompassionProjectCard: View {
  @Environment(\.heartLedger) private var ledger
  let category: CompassionCategory
  let project: CompassionProject

  @State private var burst = 0

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      CompassionMotif(symbol: project.symbol, palette: project.palette, cornerRadius: 14)
        .frame(width: 64, height: 64)

      VStack(alignment: .leading, spacing: 6) {
        Text(project.title)
          .font(DeepType.body.weight(.semibold))
          .foregroundStyle(.deepPlum)
        Text(project.blurb)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 6) {
          Image(systemName: "heart.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.blushPowder)
          Text(project.heartsShared.formatted())
            .contentTransition(.numericText(value: Double(project.heartsShared)))
          Text("·")
          Text("\(project.peopleReached.formatted()) reached")
        }
        .font(DeepType.caption.weight(.medium))
        .foregroundStyle(.driftGrey)

        progressBar
      }

      sendButton
    }
    .padding(16)
    .frostedCard()
  }

  private var progressBar: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(.lavenderMist.opacity(0.18))
        Capsule()
          .fill(LinearGradient(colors: [.lavenderMist, .blushPowder], startPoint: .leading, endPoint: .trailing))
          .frame(width: max(6, geo.size.width * project.progress))
      }
    }
    .frame(height: 6)
    .padding(.top, 2)
  }

  private var sendButton: some View {
    Button {
      ledger.sendHeart(to: category, project: project)
      burst += 1
    } label: {
      Image(systemName: "heart.fill")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(ledger.canGive ? .blushPowder : .driftGrey.opacity(0.5))
        .frame(width: 40, height: 40)
        .background(.white.opacity(0.6), in: Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
    }
    .buttonStyle(.softPress)
    .disabled(!ledger.canGive)
    .heartBurst(trigger: burst)
    .accessibilityLabel("Send a heart to \(project.title)")
  }
}

#Preview("Project card") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: 12) {
      CompassionProjectCard(category: CompassionLibrary.healthcare, project: CompassionLibrary.healthcare.projects[0])
      CompassionProjectCard(category: CompassionLibrary.healthcare, project: CompassionLibrary.healthcare.projects[1])
    }
    .padding(.edge)
  }
  .environment(\.heartLedger, .sample)
}
