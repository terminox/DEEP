import SwiftUI

/// Chooses a single daily pause time — Deep's gentler take on the Calm reference's
/// sleep-schedule dial. A real `DatePicker` drives the value; the decorative
/// `DailyRhythmDial` above it gives the orbital look without the drag-math.
struct DailyRhythmView: View {
  @Environment(\.onboardingStore) private var store
  @Environment(\.onboardingAdvance) private var advance

  @State private var time: Date = DailyRhythmView.defaultTime

  var body: some View {
    ZStack {
      AtmosphereBackground()

      VStack(spacing: .rhythm) {
        VStack(spacing: 10) {
          Text("When would you like to pause?")
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
            .multilineTextAlignment(.center)
          Text("We'll offer a soft reminder — never a nudge you can't ignore.")
            .font(DeepType.body)
            .foregroundStyle(.driftGrey)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 8)

        DailyRhythmDial(hour: components.hour ?? 21, minute: components.minute ?? 0)
          .frame(width: 200, height: 200)

        DatePicker("Daily pause time", selection: $time, displayedComponents: .hourAndMinute)
          .datePickerStyle(.wheel)
          .labelsHidden()
          .padding(.horizontal, 8)
          .padding(.vertical, 6)
          .frostedCard(cornerRadius: .card)

        Spacer()

        OnboardingPrimaryButton(title: "Set my rhythm") {
          store.setDailyPauseTime(components)
          advance(.recommendations)
        }
      }
      .padding(.horizontal, .edge)
      .padding(.bottom, .rhythm)
    }
    .navigationBarBackButtonHidden(true)
    .onAppear(perform: restoreSavedTime)
  }

  private var components: DateComponents {
    Calendar.current.dateComponents([.hour, .minute], from: time)
  }

  private func restoreSavedTime() {
    guard let saved = store.state.dailyPauseTime,
          let date = Calendar.current.date(from: DateComponents(hour: saved.hour, minute: saved.minute))
    else { return }
    time = date
  }

  private static var defaultTime: Date {
    Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date()
  }
}

#Preview("Onboarding — Rhythm") {
  DailyRhythmView()
    .environment(\.onboardingStore, MockOnboardingStore.fresh)
}
