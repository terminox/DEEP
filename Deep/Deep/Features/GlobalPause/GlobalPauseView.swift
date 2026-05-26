import SwiftUI

struct GlobalPauseView: View {
    @State private var hasJoined = false
    @State private var selectedIntention: Intention.ID? = Intention.samples.first?.id

    private let pauses = CountryPause.samples
    private let voices = VoiceOfPeace.samples

    private var nextPauseDate: Date {
        Date().addingTimeInterval(60 * 60 + 60 * 18 + 42)
    }

    var body: some View {
        ZStack(alignment: .top) {
            AtmosphereBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: DeepSpacing.rhythm) {
                    ParticipantsCounter(count: 128_756)
                        .padding(.horizontal, DeepSpacing.edge)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Let's create a Global pause")
                            .font(DeepType.caption)
                            .foregroundStyle(DeepColor.driftGrey)
                            .padding(.horizontal, DeepSpacing.edge)

                        NextPauseCard(
                            target: nextPauseDate,
                            scheduleLines: [
                                "Every day, at the same time.",
                                "21:00 Thailand Time"
                            ],
                            durationDescription: "10 minutes together",
                            hasJoined: $hasJoined
                        )
                        .padding(.horizontal, DeepSpacing.edge)
                    }

                    LiveAroundWorldSection(pauses: pauses)

                    IntentionPicker(
                        intentions: Intention.samples,
                        selection: $selectedIntention
                    )

                    VoicesOfPeaceSection(voices: voices)

                    Color.clear.frame(height: 28)
                }
                .padding(.top, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .top, spacing: 0) {
                GlobalPauseHeader()
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                    .background(
                        LinearGradient(
                            colors: [
                                DeepColor.moonCream.opacity(0.85),
                                DeepColor.moonCream.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                    )
            }
        }
        .preferredColorScheme(.light)
    }
}

#Preview("Global Pause") {
    GlobalPauseView()
}

#Preview("Global Pause • Dynamic Type XL") {
    GlobalPauseView()
        .environment(\.dynamicTypeSize, .xLarge)
}
