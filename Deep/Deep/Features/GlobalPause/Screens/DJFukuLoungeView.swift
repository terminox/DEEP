import SwiftUI

/// Fuku's Lounge — the room the lobby card opens into, pushed onto the Global
/// Pause nav stack like any other leaf (system back button, no custom chrome).
/// Mirrors the home-screen recipe: DJ Fuku full-bleed in the stretchy hero
/// slot under the transparent bar, sections riding up over it, atmosphere
/// behind. The globe card lives only here now, and below it a live rail of
/// recent peace messages replaces the old mock programme.
///
/// Leaf screen, so it owns its screen-level styling (per the coordinator
/// rules); navigation chrome is the system bar the coordinator un-hides for
/// pushed screens.
struct DJFukuLoungeView: View {
  /// The shared Global Pause card. With the home-feed seat gone, the lounge
  /// is the card's only seat (see `GlobalPauseCardSlotView.Role.home`) —
  /// pushing here adopts the card immediately. `nil` keeps previews hermetic
  /// and Metal-free.
  var card: GlobalPauseCardView? = nil

  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.globalPauseSession) private var session
  @State private var recent: [PeaceMessage] = []

  private let heroHeight: CGFloat = 320
  private let heroOverlap: CGFloat = 80

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

          if !recent.isEmpty {
            PeaceMessagesSection(messages: recent)
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
    .task { recent = await session.recentMessages(limit: 20) }
  }

  private var onAir: some View {
    OnAirPill()
      .padding(.horizontal, .edge)
  }
}

#Preview("Fuku's Lounge") {
  DJFukuLoungeView()
    .environment(\.globalPauseSession, .preview(phase: .offHours(nextLobbyStart: Date().addingTimeInterval(3 * 3600))))
}

#Preview("Accessibility type") {
  DJFukuLoungeView()
    .environment(\.dynamicTypeSize, .accessibility2)
    .environment(\.globalPauseSession, .preview(phase: .offHours(nextLobbyStart: Date().addingTimeInterval(3 * 3600))))
}
