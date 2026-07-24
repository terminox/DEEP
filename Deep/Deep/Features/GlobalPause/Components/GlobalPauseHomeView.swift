import SwiftUI

/// The Global Pause tab's content home — a stretchy video hero with a content
/// feed riding up over it (the Global Pause card, a Deep Session doorway, then
/// server-composed shelves and the Explore grid fetched from the backend).
/// Modeled on the Calm iOS Home reference, themed in the Deep design system.
/// Leaf screens route via the `openCollection` / `openCollectionList` /
/// `openGlobalPause` actions the coordinator injects; this view hosts no
/// navigation container itself.
///
/// The Global Pause card is the coordinator-owned UIKit `GlobalPauseCardView`,
/// seated here through `GlobalPauseCardSlot` — the card-lift transition
/// re-parents that one instance between this feed and the lobby.
struct GlobalPauseHomeView: View {
  var card: GlobalPauseCardView

  @Environment(\.soundContentRepository) private var repository
  @Environment(\.openCollectionList) private var openCollectionList
  @Environment(\.globalPauseSession) private var session
  @Environment(\.openGlobalPause) private var openGlobalPause
  @Environment(\.pauseReminder) private var reminder

  private enum LoadState: Equatable { case loading, loaded, failed }
  @State private var home: PauseHome?
  @State private var loadState: LoadState = .loading
  @State private var notifyEnabled = false

  private let heroHeight: CGFloat = 320
  private let heroOverlap: CGFloat = 80

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        StretchyVideoHero(resource: "sky", height: heroHeight)

        VStack(alignment: .leading, spacing: .rhythm) {
          GlobalPauseCardSlot(card: card)
            .frame(height: 200)
            .padding(.horizontal, .edge)

          pauseScheduleContent
            .padding(.horizontal, .edge)

          DeepSessionEntryCard(session: DeepSessionLibrary.balancingBreath)
            .padding(.horizontal, .edge)

          feedContent

          // The tab bar and mini player are real safe-area insets now; this is
          // just breathing room after the last section.
          Color.clear.frame(height: .rhythm)
        }
        .padding(.top, -heroOverlap)
      }
    }
    .scrollIndicators(.hidden)
    .scrollBounceBehavior(.always)
    .ignoresSafeArea(edges: .top)
    .background { AtmosphereBackground() }
    .collapsibleHomeHeader(
      title: "Global Pause",
      subtitle: "Take a breath with the world today"
    )
    .task { await load() }
  }

  /// The schedule strip under the hero card: a countdown card while the
  /// world waits, a join CTA while the pause is live.
  @ViewBuilder
  private var pauseScheduleContent: some View {
    switch session.phase {
    case .loading:
      EmptyView()
    case .offHours(let nextLobbyStart):
      NextPauseCard(
        scheduleLine: nextPauseScheduleLine(for: nextLobbyStart),
        target: nextLobbyStart,
        rsvpCount: nil,
        clockOffset: session.clock.effectiveOffset,
        isNotifyEnabled: $notifyEnabled
      )
      .task { notifyEnabled = reminder.isEnabled }
      .onChange(of: notifyEnabled) { _, wanted in
        guard wanted != reminder.isEnabled else { return }
        Task {
          let granted = await reminder.setEnabled(wanted)
          if granted != wanted {
            withAnimation(.settle) { notifyEnabled = granted }
          }
        }
      }
    case .lobby, .welcome, .meditation, .feedback:
      liveNowCTA
    }
  }

  private var liveNowCTA: some View {
    Button(action: openGlobalPause) {
      HStack(spacing: 12) {
        Circle()
          .fill(.blushPowder)
          .frame(width: 8, height: 8)
        Text("Live now — the world is pausing")
          .font(DeepType.body.weight(.medium))
          .foregroundStyle(.deepPlum)
        Spacer()
        Text("Join")
          .font(DeepType.body.weight(.semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, 18)
          .padding(.vertical, 8)
          .background(
            Capsule().fill(
              LinearGradient(
                colors: [.lavenderMist, .blushPowder],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
          )
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .frostedCard()
    }
    .buttonStyle(.softPress)
    .accessibilityLabel("The Global Pause is live now. Join the pause.")
  }

  /// "Tonight · 20:30 Thailand Time" / "Tomorrow · 20:30 Thailand Time",
  /// phrased against the pause's home timezone rather than the device's.
  private func nextPauseScheduleLine(for target: Date) -> String {
    var calendar = Calendar(identifier: .gregorian)
    let timeZone = TimeZone(identifier: session.schedule?.timezone ?? "Asia/Bangkok") ?? .current
    calendar.timeZone = timeZone

    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    formatter.dateFormat = "HH:mm"
    let time = formatter.string(from: target)

    let day = calendar.isDate(session.clock.now, inSameDayAs: target) ? "Tonight" : "Tomorrow"
    return "\(day) · \(time) Thailand Time"
  }

  @ViewBuilder
  private var feedContent: some View {
    switch loadState {
    case .loading:
      LoadingOrb(message: "Gathering today's pauses…")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    case .failed:
      VStack(spacing: 14) {
        Text("We couldn't gather today's content just now.")
          .font(DeepType.body)
          .foregroundStyle(.driftGrey)
          .multilineTextAlignment(.center)
        Button {
          Task { await load() }
        } label: {
          Text("Try again")
            .font(DeepType.body.weight(.medium))
            .foregroundStyle(.deepPlum)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .frostedCard(cornerRadius: .chip)
        }
        .buttonStyle(.softPress)
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, .edge)
      .padding(.vertical, 48)
    case .loaded:
      if let home {
        ForEach(home.sections) { section in
          if section.id == "forYou" {
            RecommendationsSection(title: section.title, collections: section.collections)
          } else {
            FeatureCarousel(
              title: section.title,
              collections: section.collections,
              seeAll: { openCollectionList(section.title, section.collections) }
            )
          }
        }

        ExploreByContentSection(categories: home.categories)
      }
    }
  }

  private func load() async {
    if home == nil { loadState = .loading }
    do {
      home = try await repository.pauseHome()
      loadState = .loaded
    } catch {
      loadState = home == nil ? .failed : .loaded
    }
  }
}

#Preview("Global Pause Home — off hours") {
  GlobalPauseHomeView(card: GlobalPauseCardView(scene: .preview))
    .environment(\.soundPlayer, MockSoundPlayer.idle)
    .environment(
      \.globalPauseSession,
      .preview(phase: .offHours(nextLobbyStart: Date().addingTimeInterval(4 * 3600)))
    )
    .environment(\.pauseReminder, MockPauseReminder())
}

#Preview("Global Pause Home — live") {
  GlobalPauseHomeView(card: GlobalPauseCardView(scene: .preview))
    .environment(\.soundPlayer, MockSoundPlayer.idle)
    .environment(\.globalPauseSession, .preview(phase: .lobby))
    .environment(\.pauseReminder, MockPauseReminder())
}
