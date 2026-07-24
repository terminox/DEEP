import SwiftUI

/// The landing after the meditation (20:50–21:00): the globe lifts back into
/// motion as a header while the world talks back — a peace-message composer,
/// the live voices feed, then intention and mood for tonight's reflection.
struct GlobalPauseFeedbackView: View {
  @Environment(\.globalPauseSession) private var session

  @State private var intentionSelection: Intention.ID?
  @State private var showMoodChips = false
  @State private var moodSelection: String?

  /// Matches the shrunken globe header placement the lobby applies in this
  /// phase — content scrolls beneath it.
  private let globeHeaderHeight: CGFloat = 260

  private let moods: [Intention] = [
    Intention(key: "calm", label: "Calm"),
    Intention(key: "grateful", label: "Grateful"),
    Intention(key: "lighter", label: "Lighter"),
    Intention(key: "tender", label: "Tender"),
    Intention(key: "heavy", label: "Still heavy"),
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: .rhythm) {
        Color.clear.frame(height: globeHeaderHeight)

        PeaceMessageComposer { text in
          _ = try await session.post(message: text)
        }
        .padding(.horizontal, .edge)

        if !session.messages.isEmpty {
          VoicesOfPeaceSection(voices: session.messages.map(\.asVoiceOfPeace))
        }

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

#Preview("Feedback") {
  ZStack {
    Color.moonCream.ignoresSafeArea()
    GlobalPauseFeedbackView()
      .environment(\.globalPauseSession, .preview(phase: .feedback))
  }
}
