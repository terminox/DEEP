import SwiftUI

/// The standalone home — one scroll combining a stretchy video hero, the
/// Breathe doorway into Deep Session, and the category carousels fetched from
/// the backend.
///
/// This is the leaf screen, so it owns its screen-level styling: the video hero
/// bleeds under the status bar and `AtmosphereBackground` sits behind the scroll
/// (per the project's coordinator rules, styling lives here, not in the
/// coordinator, so it actually renders).
struct DeepSoundHomeView: View {
  /// Extra bottom space so content clears the docked mini-player.
  var bottomInset: CGFloat

  @Environment(\.soundContentRepository) private var repository

  private enum LoadState: Equatable { case loading, loaded, failed }
  @State private var shelves: [SoundShelf] = []
  @State private var loadState: LoadState = .loading

  private let heroHeight: CGFloat = 320
  /// How far the content rides up over the hero.
  private let heroOverlap: CGFloat = 80

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        StretchyHero(media: .video(resource: "sky"), height: heroHeight)

        VStack(alignment: .leading, spacing: .rhythm) {
          BreatheHeroCard(session: DeepSessionLibrary.balancingBreath)
            .padding(.horizontal, .edge)

          shelvesContent

          Color.clear.frame(height: bottomInset)
        }
        .padding(.top, -heroOverlap)
      }
    }
    .scrollIndicators(.hidden)
    .scrollBounceBehavior(.always)
    .ignoresSafeArea(edges: .top)
    .background { AtmosphereBackground() }
    .collapsibleHomeHeader(
      title: "Deep Sound",
      subtitle: "Breathe and listen"
    )
    .task { await load() }
  }

  @ViewBuilder
  private var shelvesContent: some View {
    switch loadState {
    case .loading:
      LoadingOrb(message: "Gathering sounds…")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    case .failed:
      VStack(spacing: 14) {
        Text("We couldn't gather the sounds just now.")
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
      ForEach(shelves) { shelf in
        CollectionCarousel(title: shelf.title, collections: shelf.collections)
      }
    }
  }

  private func load() async {
    if shelves.isEmpty { loadState = .loading }
    do {
      shelves = try await repository.home()
      loadState = .loaded
    } catch {
      loadState = shelves.isEmpty ? .failed : .loaded
    }
  }
}

#Preview("Deep Sound — Home") {
  DeepSoundHomeView(bottomInset: .rhythm)
    .environment(\.soundPlayer, MockSoundPlayer.idle)
}
