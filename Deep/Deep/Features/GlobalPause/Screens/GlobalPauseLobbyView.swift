import SwiftUI

/// The Global Pause lobby (Fuku's Lounge) — the room the lobby card opens
/// into, pushed onto the Global Pause nav stack like any other leaf (system
/// back button, no custom chrome). Mirrors the home-screen recipe: DJ Fuku
/// full-bleed in the stretchy hero slot under the transparent bar, sections
/// riding up over it, atmosphere behind. The globe card lives only here now,
/// and below it the peace-message feed scrolls on forever — pages append as
/// the last card comes into view.
///
/// The hero follows the member's own hour, so the room looks like the time of
/// day they are actually in. Once a night, at the top of the lobby phase, Fuku
/// goes on air: the intro clip plays aloud, hands off to that same ambient
/// footage, and the lounge track streams underneath until it runs out. It is a
/// broadcast, not a playlist — every part of it is keyed to the synced clock,
/// so walking in late drops you into the middle of the set rather than starting
/// it over, and the ON AIR badge burns for exactly the minutes the music plays.
///
/// Leaf screen, so it owns its screen-level styling (per the coordinator
/// rules); navigation chrome is the system bar the coordinator un-hides for
/// pushed screens.
struct GlobalPauseLobbyView: View {
  /// The shared Global Pause card. With the home-feed seat gone, the lobby
  /// is the card's only seat (see `GlobalPauseCardSlotView.Role.home`) —
  /// pushing here adopts the card immediately. `nil` keeps previews hermetic
  /// and Metal-free.
  var card: GlobalPauseCardView? = nil

  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.pauseEventRepository) private var repository
  @Environment(\.globalPauseSession) private var globalPauseSession
  @Environment(\.loungeRadio) private var radio
  @Environment(\.soundPlayer) private var soundPlayer

  /// Where the broadcast has got to, recomputed whenever the session says the
  /// set started or ended and when the intro hands off. Held rather than
  /// derived on every body pass so the hero keeps one identity per stage —
  /// re-deriving it against a live clock would restart the clip on every
  /// scroll frame.
  @State private var stage: LoungeBroadcast.Stage = .off
  @State private var isMuted = false
  /// The ambient clip for the member's hour. Re-read whenever the screen
  /// appears and on every boundary flip, so a lounge left open across the hour
  /// changes with it.
  @State private var ambientClip: FukuClip = .ambient()

  @State private var messages: [PeaceMessage] = []
  @State private var nextCursor: String?
  @State private var isLoadingMore = false
  /// Bumped whenever a refresh replaces the feed wholesale, so an in-flight
  /// loadMore from the previous feed can tell its page is stale.
  @State private var feedEpoch = 0

  /// The feed as shown: whatever has been paged in, with the member's own
  /// message from tonight seated at the head. It was written after this feed
  /// was fetched, and the session is presented *over* this screen — which is
  /// never removed — so there is no lifecycle moment to insert it on. Deriving
  /// it keeps the lounge honest whenever the body runs, and the de-dupe means
  /// a later page that catches up with it changes nothing.
  private var feedMessages: [PeaceMessage] {
    guard let mine = globalPauseSession.postedMessage,
          !messages.contains(where: { $0.id == mine.id })
    else { return messages }
    return [mine] + messages
  }

  private let heroHeight: CGFloat = 320
  private let heroOverlap: CGFloat = 80
  private let pageSize = 20

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        StretchyHero(media: heroMedia, height: heroHeight)

        VStack(alignment: .leading, spacing: .rhythm) {
          // Follows what the room is actually doing rather than the clock, so
          // the badge never claims a set that failed to load or that the member
          // has taken back with their own music.
          if stage != .off {
            onAir
          }

          if let card {
            GlobalPauseCardSlot(card: card, role: .home)
              .frame(height: 200)
              .padding(.horizontal, .edge)
          }

          if !feedMessages.isEmpty {
            PeaceMessagesSection(
              messages: feedMessages,
              intentions: globalPauseSession.schedule?.intentions ?? [],
              isLoadingMore: isLoadingMore,
              onReachEnd: { Task { await loadMore() } }
            )
          }

          Color.clear.frame(height: .rhythm)
        }
        .padding(.top, -heroOverlap)
      }
    }
    .scrollIndicators(.hidden)
    .scrollBounceBehavior(.always)
    .ignoresSafeArea(edges: .top)
    .background {
      ZStack {
        // Opaque base under the atmosphere's translucent stops: nothing beneath
        // this screen may ever show through.
        Color.moonCream.ignoresSafeArea()
        AtmosphereBackground()
      }
    }
    .overlay(alignment: .top) {
      // Progressive blur keeps the status bar, inline title, and back chevron
      // legible over the bright hero art.
      if !reduceTransparency {
        VariableBlurView(maxBlurRadius: 4, direction: .blurredTopClearBottom)
          .frame(height: 80)
          .ignoresSafeArea(edges: .top)
          .allowsHitTesting(false)
      }
    }
    .navigationTitle("Fuku's Lounge")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .task { await loadInitial() }
    // Re-entering the lounge re-resolves tonight's schedule against the synced
    // clock, so a server-side time jump goes live without a relaunch.
    .task { await globalPauseSession.start() }
    .heroRefreshable { await refresh() }
    // The session flips this at the set's edges off its own boundary timer, so
    // the lounge only has to follow — no polling, no clock of its own.
    .onChange(of: globalPauseSession.isFukuOnAir) { _, _ in resolveStage() }
    .onAppear {
      ambientClip = .ambient()
      resolveStage()
    }
    .onDisappear {
      // Leaving the room leaves the broadcast. The session keeps running it;
      // coming back rejoins wherever it has got to.
      radio.stop()
      stage = .off
    }
    // Their own music wins if they choose it: entering an on-air lounge pauses
    // the shared player, and pressing play again takes the room back — set off,
    // badge down, rather than two pieces of music at once.
    .onChange(of: soundPlayer.isPlaying) { _, isPlaying in
      guard isPlaying, stage != .off else { return }
      radio.stop()
      withAnimation(.exhale) { stage = .off }
    }
  }

  private var onAir: some View {
    OnAirPill(isMuted: isMuted) {
      isMuted.toggle()
      radio.setMuted(isMuted)
    }
    .padding(.horizontal, .edge)
  }

  // MARK: - The broadcast

  /// The hero: Fuku's intro while it is playing, the member's own time of day
  /// the rest of the time. The intro is a different view type, so handing off
  /// tears it down and builds the loop cleanly.
  private var heroMedia: StretchyHero.Media {
    if case .intro(let elapsed) = stage {
      return .oneShotVideo(
        resource: FukuClip.intro.resource,
        startAt: elapsed,
        isMuted: isMuted,
        onEnded: { resolveStage(afterIntro: true) }
      )
    }
    return .video(resource: ambientClip.resource)
  }

  /// Reads the clock once and puts the room where it belongs. Called at the
  /// set's edges, when the intro finishes, and on appear — never per frame.
  private func resolveStage(afterIntro: Bool = false) {
    ambientClip = .ambient()
    let now = globalPauseSession.clock.now
    let broadcast = globalPauseSession.loungeBroadcast
    let next = afterIntro
      ? (broadcast?.stageAfterIntro(at: now) ?? .off)
      : (broadcast?.stage(at: now) ?? .off)
    // The intro is one clip playing through; re-entering `.intro` from itself
    // would seek it back and replay the opening.
    if case .intro = next, case .intro = stage { return }
    withAnimation(.exhale) { stage = next }

    switch next {
    case .off:
      radio.stop()
    case .intro:
      // Fuku is talking over his own clip; the track waits its turn.
      radio.stop()
      soundPlayer.pause()
    case .music(let offset):
      soundPlayer.pause()
      let session = globalPauseSession
      radio.liveOffsetProvider = { [weak session] in session?.loungeElapsed ?? 0 }
      guard let url = session.schedule?.lobbyAudioURL else { return }
      radio.join(url: url, at: offset)
      radio.setMuted(isMuted)
    }
  }

  // MARK: - Feed paging

  private func loadInitial() async {
    guard messages.isEmpty else { return }
    do {
      let page = try await repository.messages(limit: pageSize, cursor: nil)
      messages = page.messages
      nextCursor = page.nextCursor
    } catch {
      // Nothing loaded — the section stays hidden; the next visit retries.
    }
  }

  private func loadMore() async {
    guard let cursor = nextCursor, !isLoadingMore else { return }
    isLoadingMore = true
    defer { isLoadingMore = false }
    let epoch = feedEpoch
    do {
      let page = try await repository.messages(limit: pageSize, cursor: cursor)
      guard epoch == feedEpoch else { return } // a refresh replaced the feed mid-flight
      let known = Set(messages.map(\.id))
      messages += page.messages.filter { !known.contains($0.id) }
      nextCursor = page.nextCursor
    } catch {
      // Keep the cursor: the next time the tail scrolls into view we retry.
    }
  }

  private func refresh() async {
    async let liveness: Void = globalPauseSession.start()
    do {
      let page = try await repository.messages(limit: pageSize, cursor: nil)
      messages = page.messages
      nextCursor = page.nextCursor
      feedEpoch += 1
    } catch {
      // Keep the feed we have; the schedule refresh still lands.
    }
    await liveness
  }
}

#if DEBUG
#Preview("Global Pause lobby") {
  GlobalPauseLobbyView()
    .environment(\.pauseEventRepository, FixturePauseEventRepository())
    .environment(\.loungeRadio, MockLoungeRadioPlayer())
    .environment(\.soundPlayer, MockSoundPlayer.idle)
}

#Preview("On air") {
  GlobalPauseLobbyView()
    .environment(\.pauseEventRepository, FixturePauseEventRepository())
    .environment(\.globalPauseSession, GlobalPauseSession.previewOnAir())
    .environment(\.loungeRadio, MockLoungeRadioPlayer.onAir)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
}

// The muted pill is previewed where it lives, in `OnAirPill`: muting is the
// member's own choice, held here as view state, so a preview could only fake it
// by lying about the radio's.

#Preview("Accessibility type") {
  GlobalPauseLobbyView()
    .environment(\.dynamicTypeSize, .accessibility2)
    .environment(\.pauseEventRepository, FixturePauseEventRepository())
    .environment(\.loungeRadio, MockLoungeRadioPlayer())
    .environment(\.soundPlayer, MockSoundPlayer.idle)
}
#endif
