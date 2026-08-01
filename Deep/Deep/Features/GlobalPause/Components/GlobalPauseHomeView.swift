import SwiftUI

/// The Global Pause tab's content home — a stretchy video hero with a content
/// feed riding up over it (a Deep Session doorway, then server-composed
/// shelves and the Explore grid fetched from the backend). Modeled on the
/// Calm iOS Home reference, themed in the Deep design system. Leaf screens
/// route via the `openCollection` / `openCollectionList` actions the
/// coordinator injects; this view hosts no navigation container itself.
struct GlobalPauseHomeView: View {
  @Environment(\.soundContentRepository) private var repository
  @Environment(\.openCollectionList) private var openCollectionList

  private enum LoadState: Equatable { case loading, loaded, failed }
  @State private var home: PauseHome?
  @State private var loadState: LoadState = .loading

  private let heroHeight: CGFloat = 320
  private let heroOverlap: CGFloat = 80

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        StretchyHero(media: .video(resource: "sky"), height: heroHeight)

        VStack(alignment: .leading, spacing: .rhythm) {
          DJFukuLoungeCard()
            .padding(.horizontal, .edge)

          DeepSessionEntryCard(session: DeepSessionLibrary.balancingBreath)
            .padding(.horizontal, .edge)

          feedContent
            .animation(.bloom, value: loadState)

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
      title: "Home",
      subtitle: "Take a breath with the world today"
    )
    .task { await load() }
  }

  @ViewBuilder
  private var feedContent: some View {
    switch loadState {
    case .loading:
      PauseFeedSkeleton()
        .transition(.opacity)
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

#Preview("Global Pause Home") {
  GlobalPauseHomeView()
    .environment(\.soundPlayer, MockSoundPlayer.idle)
}
