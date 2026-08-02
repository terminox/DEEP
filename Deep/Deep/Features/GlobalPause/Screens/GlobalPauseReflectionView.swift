import SwiftUI

/// The landing after the meditation: a thank-you, a peace-message composer,
/// then intention and mood for tonight's reflection. Fully opaque — it fades
/// in over the meditation and covers the globe card's silent handback to its
/// lounge seat behind the presentation.
struct GlobalPauseReflectionView: View {
  var onDone: () -> Void

  @Environment(\.globalPauseSession) private var session

  @State private var intentionSelection: Intention.ID?
  @State private var showMoodChips = false
  @State private var moodSelection: String?

  private let moods: [Intention] = [
    Intention(key: "calm", label: "Calm"),
    Intention(key: "grateful", label: "Grateful"),
    Intention(key: "lighter", label: "Lighter"),
    Intention(key: "tender", label: "Tender"),
    Intention(key: "heavy", label: "Still heavy"),
  ]

  var body: some View {
    ZStack {
      Color.moonCream.ignoresSafeArea()
      AtmosphereBackground()

      ScrollView {
        VStack(alignment: .leading, spacing: .rhythm) {
          header

          PeaceMessageComposer { text in
            _ = try await session.post(message: text)
          }
          .padding(.horizontal, .edge)

          IntentionPicker(
            intentions: session.schedule?.intentions ?? Intention.samples,
            selection: $intentionSelection
          )
          .onChange(of: intentionSelection) { _, selected in
            guard let selected else { return }
            Task { try? await session.submit(intention: selected, mood: nil) }
          }

          moodCheckIn

          Color.clear.frame(height: .rhythm)
        }
      }
      .scrollIndicators(.hidden)
    }
    .overlay(alignment: .topLeading) {
      GlassCloseButton(action: onDone)
        .padding(.edge)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Thank you for pausing")
        .font(DeepType.displayTitle)
        .foregroundStyle(.deepPlum)
      Text("Carry tonight's calm with you.")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
    }
    .padding(.horizontal, .edge)
    .padding(.top, 76)
  }

  @ViewBuilder
  private var moodCheckIn: some View {
    if showMoodChips {
      VStack(alignment: .leading, spacing: 14) {
        SectionHeader(title: "How are you feeling?")
        FlowLayout(spacing: 8, runSpacing: 8) {
          ForEach(moods) { mood in
            moodChip(mood)
          }
        }
        .padding(.horizontal, .edge)
      }
      .transition(.opacity)
    } else {
      MoodCheckInCard {
        withAnimation(.settle) { showMoodChips = true }
      }
    }
  }

  private func moodChip(_ mood: Intention) -> some View {
    let isSelected = moodSelection == mood.key
    return Button {
      withAnimation(.settle) { moodSelection = mood.key }
      Task { try? await session.submit(intention: nil, mood: mood.key) }
    } label: {
      Text(mood.label)
        .font(DeepType.body.weight(isSelected ? .medium : .regular))
        .foregroundStyle(isSelected ? .white : Color.deepPlum.opacity(0.85))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
          Capsule().fill(
            isSelected
              ? AnyShapeStyle(
                LinearGradient(
                  colors: [.lavenderMist, .blushPowder],
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              : AnyShapeStyle(Color.white.opacity(0.75))
          )
        )
        .overlay(
          Capsule().strokeBorder(.white.opacity(isSelected ? 0 : 0.6), lineWidth: 0.5)
        )
    }
    .buttonStyle(.softPress)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

#Preview("Reflection") {
  GlobalPauseReflectionView(onDone: {})
    .environment(\.globalPauseSession, .preview())
}
