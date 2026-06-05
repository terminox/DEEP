import SwiftUI

/// The greeting + stats card that overlaps the hero scene: a warm welcome line
/// above today's progress and the running streak. The frosted surface lets the
/// dawn colours glow softly through from behind.
struct GardenGreetingCard: View {
  let state: GardenState
  @State private var isCherished = true

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 5) {
          Text("Your Mind Garden")
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
          HStack(spacing: 5) {
            Text("Keep going, you’re growing")
              .font(DeepType.body)
              .foregroundStyle(.driftGrey)
            Image(systemName: "leaf.fill")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(GardenColor.sage)
          }
        }
        Spacer(minLength: 12)
        cherishButton
      }

      Rectangle()
        .fill(.lavenderMist.opacity(0.22))
        .frame(height: 1)

      statRow
    }
    .padding(20)
    .frostedCard()
  }

  private var cherishButton: some View {
    Button {
      withAnimation(.settle) { isCherished.toggle() }
    } label: {
      Image(systemName: isCherished ? "heart.fill" : "heart")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(isCherished ? .blushPowder : .driftGrey)
        .frame(width: 40, height: 40)
        .background(.white.opacity(0.6), in: Circle())
    }
    .buttonStyle(.softPress)
    .accessibilityLabel("Cherish your garden")
  }

  private var statRow: some View {
    HStack(alignment: .top, spacing: 0) {
      progressStat
        .frame(maxWidth: .infinity, alignment: .leading)

      Rectangle()
        .fill(.lavenderMist.opacity(0.22))
        .frame(width: 1, height: 44)
        .padding(.horizontal, 8)

      streakStat
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var progressStat: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Today’s progress")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
      Text("\(state.minutesToday) / \(state.dailyGoalMinutes) min")
        .font(DeepType.counter)
        .foregroundStyle(.deepPlum)
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(.lavenderMist.opacity(0.18))
          Capsule()
            .fill(LinearGradient(
              colors: [.lavenderMist, .blushPowder],
              startPoint: .leading, endPoint: .trailing
            ))
            .frame(width: max(6, geo.size.width * state.progress))
        }
      }
      .frame(height: 6)
    }
  }

  private var streakStat: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Daily streak")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
      HStack(spacing: 6) {
        Image(systemName: "flame.fill")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(LinearGradient(
            colors: [.peachCloud, .blushPowder],
            startPoint: .top, endPoint: .bottom
          ))
        Text("\(state.streakDays) days")
          .font(DeepType.counter)
          .foregroundStyle(.deepPlum)
      }
      Text("Best yet — keep it alight")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey.opacity(0.85))
    }
  }
}

#Preview("Greeting card") {
  ZStack {
    AtmosphereBackground()
    GardenGreetingCard(state: .sample)
      .padding(.edge)
  }
}
