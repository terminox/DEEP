import SwiftUI

/// Calm content hand-off between onboarding screens: a soft fade with a small
/// vertical drift and a breath of blur. Going forward the new screen rises in
/// from below while the old one drifts upward; going back the motion mirrors,
/// so the flow always reads as one continuous, unhurried breath.
struct SoftDriftTransition: Transition {
  enum Direction {
    case forward, backward
  }

  var direction: Direction

  func body(content: Content, phase: TransitionPhase) -> some View {
    content
      .opacity(phase.isIdentity ? 1 : 0)
      .offset(y: offset(for: phase))
      .blur(radius: phase.isIdentity ? 0 : 6)
  }

  private func offset(for phase: TransitionPhase) -> CGFloat {
    switch phase {
    case .identity: 0
    case .willAppear: direction == .forward ? 16 : -16
    case .didDisappear: direction == .forward ? -16 : 16
    }
  }
}

#Preview("Soft drift") {
  @Previewable @State var showsFirst = true
  @Previewable @State var direction = SoftDriftTransition.Direction.forward

  ZStack {
    // Stand-ins for two onboarding screens — no real dependencies.
    if showsFirst {
      LinearGradient(colors: [.peachCloud, .blushPowder], startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
        .overlay {
          Text("First screen")
            .font(DeepType.sectionTitle)
            .foregroundStyle(.deepPlum)
        }
        .transition(SoftDriftTransition(direction: direction))
    } else {
      LinearGradient(colors: [.skyWash, .moonCream], startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
        .overlay {
          Text("Second screen")
            .font(DeepType.sectionTitle)
            .foregroundStyle(.deepPlum)
        }
        .transition(SoftDriftTransition(direction: direction))
    }

    VStack {
      Spacer()
      HStack(spacing: .rhythm) {
        Button("Back") {
          direction = .backward
          withAnimation(.bloom) { showsFirst.toggle() }
        }
        Button("Forward") {
          direction = .forward
          withAnimation(.bloom) { showsFirst.toggle() }
        }
      }
      .padding(.bottom, .rhythm)
    }
  }
}
