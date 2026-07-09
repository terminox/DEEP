import SwiftUI

/// The flow's third and final choice: pick a Mind Tree. The selection is
/// purely visual for now — nothing is persisted; the Mind Garden wiring comes
/// later — so the screen keeps its choice in local state and simply moves on.
struct MindTreePickerView: View {
  @Environment(\.onboardingAdvance) private var advance

  @State private var selectedTreeID: String?

  private let columns = [
    GridItem(.flexible(), spacing: 14),
    GridItem(.flexible(), spacing: 14),
  ]

  var body: some View {
    ZStack {
      AtmosphereBackground()

      VStack(alignment: .leading, spacing: .rhythm) {
        OnboardingProgressBar(progress: 1.0, fractionLabel: "3 of 3")
          .padding(.top, 8)

        VStack(alignment: .leading, spacing: 6) {
          Text("Choose your Mind Tree")
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
            .fixedSize(horizontal: false, vertical: true)
          Text("You can change it anytime.")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
        }

        ScrollView {
          LazyVGrid(columns: columns, spacing: 14) {
            ForEach(MindTree.all) { tree in
              MindTreeCard(
                tree: tree,
                isSelected: selectedTreeID == tree.id
              ) {
                withAnimation(.settle) { selectedTreeID = tree.id }
              }
            }
          }
          .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)

        OnboardingPrimaryButton(title: "See My Space", isEnabled: selectedTreeID != nil) {
          advance(.craftingSpace)
        }
      }
      .padding(.horizontal, .edge)
      .padding(.bottom, .rhythm)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

#Preview("Onboarding — Mind Tree") {
  MindTreePickerView()
}
