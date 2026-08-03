import SwiftUI

/// The Global Pause lobby (Fuku's Lounge) — the room the lobby card opens
/// into, pushed onto the Global Pause nav stack like any other leaf (system
/// back button, no custom chrome). Mirrors the home-screen recipe: DJ Fuku
/// full-bleed in the stretchy hero slot under the transparent bar, sections
/// riding up over it, atmosphere behind. The globe card lives only here now,
/// and below it the peace-message feed scrolls on forever — pages append as
/// the last card comes into view.
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

  @State private var messages: [PeaceMessage] = []
  @State private var nextCursor: String?
  @State private var isLoadingMore = false

  private let heroHeight: CGFloat = 320
  private let heroOverlap: CGFloat = 80
  private let pageSize = 20

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        StretchyHero(media: .image(name: "DJFukuHero"), height: heroHeight)

        VStack(alignment: .leading, spacing: .rhythm) {
          onAir

          if let card {
            GlobalPauseCardSlot(card: card, role: .home)
              .frame(height: 200)
              .padding(.horizontal, .edge)
          }

          if !messages.isEmpty {
            PeaceMessagesSection(
              messages: messages,
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
  }

  private var onAir: some View {
    OnAirPill()
      .padding(.horizontal, .edge)
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
    do {
      let page = try await repository.messages(limit: pageSize, cursor: cursor)
      let known = Set(messages.map(\.id))
      messages += page.messages.filter { !known.contains($0.id) }
      nextCursor = page.nextCursor
    } catch {
      // Keep the cursor: the next time the tail scrolls into view we retry.
    }
  }
}

#Preview("Global Pause lobby") {
  GlobalPauseLobbyView()
    .environment(\.pauseEventRepository, FixturePauseEventRepository())
}

#Preview("Accessibility type") {
  GlobalPauseLobbyView()
    .environment(\.dynamicTypeSize, .accessibility2)
    .environment(\.pauseEventRepository, FixturePauseEventRepository())
}
