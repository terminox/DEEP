import SwiftUI

/// One initiative within a cause: what it does, who it's reached, how far along
/// it is, and a one-tap heart to back it. Sending updates the live ledger, so
/// the count climbs in place.
///
/// Progress rides as an arc around the motif rather than a bar beneath the text —
/// the same halo language as the portfolio's allocation ring, and one fewer
/// horizontal strip on a card that already carries three lines of type.
struct CompassionProjectCard: View {
  @Environment(\.heartLedger) private var ledger
  let category: CompassionCategory
  let project: CompassionProject

  @State private var burst = 0

  private var percent: Int { Int((project.progress * 100).rounded()) }

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      motif

      VStack(alignment: .leading, spacing: 6) {
        Text(project.title)
          .font(DeepType.body.weight(.semibold))
          .foregroundStyle(.deepPlum)
        Text(project.blurb)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .fixedSize(horizontal: false, vertical: true)

        // Two facts held apart by space, not by a mark. The cause's reach is
        // already told once, above; repeating it per project only crowds the row.
        HStack(spacing: 14) {
          fact(symbol: "heart.fill", tint: .blushPowder) {
            Text("\(project.heartsShared.formatted()) hearts")
              .contentTransition(.numericText(value: Double(project.heartsShared)))
          }
          fact(symbol: "target", tint: .lavenderMist) {
            Text("\(percent)% funded")
          }
        }
        .font(DeepType.caption.weight(.medium))
        .foregroundStyle(.driftGrey)
        .padding(.top, 2)
      }

      sendButton
    }
    .padding(16)
    .frostedCard()
  }

  /// The project's artwork inside its own progress arc.
  private var motif: some View {
    ZStack {
      CompassionRing(
        segments: [RingSegment(share: project.progress, colors: project.palette.colors)],
        lineWidth: 5,
        gap: 0
      )
      CompassionMotif(symbol: project.symbol, palette: project.palette, cornerRadius: 14)
        .padding(9)
    }
    .frame(width: 68, height: 68)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Progress")
    .accessibilityValue("\(percent) percent funded")
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
        .background {
          Circle().fill(
            ledger.canGive
              ? AnyShapeStyle(Color.blushPowder.opacity(0.22))
              : AnyShapeStyle(Color.white.opacity(0.4))
          )
        }
        .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
    }
    .buttonStyle(.softPress)
    .disabled(!ledger.canGive)
    .heartBurst(trigger: burst)
    .accessibilityLabel("Send a heart to \(project.title)")
  }

  private func fact<Label: View>(
    symbol: String,
    tint: Color,
    @ViewBuilder label: () -> Label
  ) -> some View {
    HStack(spacing: 5) {
      Image(systemName: symbol)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(tint)
      label()
    }
    .fixedSize()
  }
}

#Preview("Project card") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: 12) {
      ForEach(CompassionLibrary.healthcare.projects) { project in
        CompassionProjectCard(category: CompassionLibrary.healthcare, project: project)
      }
    }
    .padding(.edge)
  }
  .environment(\.heartLedger, .sample)
}

#Preview("Project card — no hearts left") {
  ZStack {
    AtmosphereBackground()
    CompassionProjectCard(
      category: CompassionLibrary.nature,
      project: CompassionLibrary.nature.projects[0]
    )
    .padding(.edge)
  }
  .environment(\.heartLedger, .spent)
}
