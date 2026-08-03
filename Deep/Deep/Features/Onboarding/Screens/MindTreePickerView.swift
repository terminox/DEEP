import SwiftUI

/// The flow's third and final choice: pick a Mind Tree. The selection is
/// purely visual for now — nothing is persisted; the Mind Garden wiring comes
/// later — so the screen keeps its choice in local state and simply moves on.
struct MindTreePickerView: View {
  @Environment(\.onboardingStore) private var store
  @Environment(\.onboardingConfig) private var config
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
        VStack(alignment: .leading, spacing: .rhythm) {
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
              ForEach(config.mindTrees) { tree in
                MindTreeCard(
                  tree: tree,
                  isSelected: selectedTreeID == tree.id
                ) {
                  withAnimation(.settle) { selectedTreeID = tree.id }
                  // Persist the choice now (the Mind Garden will read it later).
                  store.recordMindTree(tree.id)
                }
              }
            }
          }
          .scrollIndicators(.hidden)
          // Let the frosted cards' soft shadows breathe past the viewport edges.
          .scrollClipDisabled()
        }
        .onboardingContentDrift()

        OnboardingPrimaryButton(title: "Continue", isEnabled: selectedTreeID != nil) {
          advance(.createAccount)
        }
      }
      .padding(.horizontal, .edge)
      .padding(.bottom, .rhythm)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .onAppear { selectedTreeID = store.state.mindTree }
  }
}

#Preview("Onboarding — Mind Tree") {
  MindTreePickerView()
    .environment(\.onboardingStore, MockOnboardingStore.fresh)
}
