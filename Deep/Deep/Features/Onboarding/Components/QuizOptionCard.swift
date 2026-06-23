import SwiftUI

/// A single-select answer row: a frosted pill with a soft gradient orb, the
/// answer text, and a trailing selection mark that blooms in when chosen.
/// Tapping animates with the foam-like `.settle` press.
struct QuizOptionCard: View {
  let option: QuizOption
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Circle()
          .fill(
            LinearGradient(
              colors: option.palette.colors,
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 30, height: 30)
          .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))

        VStack(alignment: .leading, spacing: 2) {
          Text(option.title)
            .font(DeepType.body)
            .foregroundStyle(.deepPlum)
          if let subtitle = option.subtitle {
            Text(subtitle)
              .font(DeepType.caption)
              .foregroundStyle(.driftGrey)
          }
        }
        .multilineTextAlignment(.leading)

        Spacer(minLength: 8)

        selectionMark
      }
      .padding(.vertical, 16)
      .padding(.horizontal, 18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .frostedCard(cornerRadius: .card)
      .overlay(
        RoundedRectangle(cornerRadius: .card, style: .continuous)
          .strokeBorder(.lavenderMist, lineWidth: isSelected ? 1.5 : 0)
      )
      .contentShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
    }
    .buttonStyle(.softPress)
    .animation(.settle, value: isSelected)
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }

  @ViewBuilder
  private var selectionMark: some View {
    if isSelected {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 22))
        .foregroundStyle(.lavenderMist)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    } else {
      Circle()
        .strokeBorder(Color.driftGrey.opacity(0.5), lineWidth: 1.5)
        .frame(width: 22, height: 22)
    }
  }
}

#Preview("Quiz option card") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: 14) {
      QuizOptionCard(
        option: QuizOption(id: "calm", title: "Calm", palette: .tide),
        isSelected: true,
        action: {}
      )
      QuizOptionCard(
        option: QuizOption(id: "connection", title: "Connection", subtitle: "Feeling less alone", palette: .dusk),
        isSelected: false,
        action: {}
      )
      QuizOptionCard(
        option: QuizOption(id: "clarity", title: "Clarity", palette: .mist),
        isSelected: false,
        action: {}
      )
    }
    .padding(.horizontal, .edge)
  }
}
