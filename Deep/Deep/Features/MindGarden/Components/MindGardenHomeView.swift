import SwiftUI

/// The Mind Garden home — a personal calm space. One quiet scroll: an
/// atmospheric video header, a greeting with the oak's growth toward its next
/// form, and a nudge into today's practice carrying today's progress.
///
/// This is the leaf screen, so it owns its screen-level styling: the video hero
/// bleeds under the status bar and `AtmosphereBackground` sits behind the scroll
/// (per the project's coordinator rules, styling lives here, not in the
/// coordinator, so it actually renders).
struct MindGardenHomeView: View {
  var state: GardenState = .sample
  var greeting: GardenGreeting = .current()
  /// Extra bottom space so content clears the tab bar / any docked chrome.
  var bottomInset: CGFloat = .rhythm

  /// Today's practice is a guided breath. The card stays a dumb button; the
  /// screen decides what tapping it does — here, pushing the Deep Session
  /// threshold through the coordinator.
  @Environment(\.openDeepSession) private var openDeepSession

  /// The growth card's quiet "Change" affordance pushes the plant picker —
  /// again through the coordinator.
  @Environment(\.openPlantPicker) private var openPlantPicker

  /// The plant's growth — server-backed sunlight, persisted offline. The
  /// practice snapshot above stays a plain value; growth is the one live thing.
  @Environment(\.gardenStore) private var gardenStore

  /// The oak owns half the screen on this screen only, so the garden opens on
  /// the tree. Measured rather than hardcoded — half of 852pt is not half of
  /// 956pt — and the hero bleeds under the status bar, so the fraction is of
  /// the whole screen, safe areas included.
  private let heroScreenFraction: CGFloat = 0.5

  /// How far the greeting card rides up over the hero.
  private let heroOverlap: CGFloat = 52

  var body: some View {
    // An outer reader, not told to ignore anything, sees the true safe-area
    // insets; the scroll below ignores the top edge, so a reader inside it
    // would under-report (the same trick `CollapsibleHomeHeader` uses to find
    // the status-bar height). Size plus both insets is the whole screen.
    GeometryReader { proxy in
      garden(
        heroHeight: (proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
          * heroScreenFraction
      )
    }
  }

  /// What the hero plays: the selected plant's current form, as the catalog
  /// authored it — its stage video when one exists, else its stage portrait as
  /// a poster. The oak keeps the bundled mature-oak loop wherever the catalog
  /// has no footage for its stage (and while the garden is still loading), so
  /// the flagship scene — and every preview on fixtures — never goes flat.
  private var heroMedia: StretchyHero.Media {
    guard let growth = gardenStore.growth else {
      return .video(resource: "deep_oak_mature")
    }
    let stage = growth.stage
    if stage.heroVideoURL == nil, growth.plant.id == "oak" {
      return .video(resource: "deep_oak_mature")
    }
    return .remoteVideo(
      url: stage.heroVideoURL,
      posterURL: stage.mascotBgURL ?? stage.mascotURL
    )
  }

  private func garden(heroHeight: CGFloat) -> some View {
    ScrollView {
      VStack(spacing: 0) {
        StretchyHero(media: heroMedia, height: heroHeight)

        VStack(alignment: .leading, spacing: .rhythm) {
          if let growth = gardenStore.growth {
            GardenGrowthCard(
              greeting: greeting,
              growth: growth,
              onChangePlant: openPlantPicker
            )
            .padding(.horizontal, .edge)
          } else {
            growthSkeleton
              .padding(.horizontal, .edge)
          }

          DailyPracticeCard(state: state, plantName: gardenStore.growth?.plant.name) {
            openDeepSession(DeepSessionLibrary.balancingBreath)
          }
          .padding(.horizontal, .edge)

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
      title: "Mind Garden",
      subtitle: "Tend to your calm"
    )
  }

  /// Mirrors the growth card's geometry — salutation lines, the halo's circle
  /// with the change pill beneath it, the name and fact lines — while the first
  /// garden snapshot is still on its way, so the page doesn't reflow when the
  /// plant arrives.
  private var growthSkeleton: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 8) {
        SkeletonTextLine(width: 150)
        SkeletonTextLine(width: 230)
      }

      HStack(spacing: 16) {
        VStack(spacing: 10) {
          SkeletonBlock(cornerRadius: 50.5)
            .frame(width: 101, height: 101)
          SkeletonBlock(cornerRadius: .chip)
            .frame(width: 92, height: 30)
        }

        VStack(alignment: .leading, spacing: 8) {
          SkeletonTextLine(width: 130)
          SkeletonTextLine(width: 160)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(20)
    .frostedCard()
    .skeletonBreath()
  }
}

#Preview("Mind Garden — Home") {
  MindGardenHomeView(state: .sample, greeting: .sample)
    .environment(\.gardenStore, .sample)
}

#Preview("Mind Garden — Fresh start") {
  MindGardenHomeView(state: .fresh, greeting: .sample)
    .environment(\.gardenStore, .fresh)
}

#Preview("Mind Garden — Flourishing") {
  MindGardenHomeView(state: .flourishing, greeting: .evening)
    .environment(\.gardenStore, .flourishing)
}

#Preview("Mind Garden — Loading") {
  MindGardenHomeView(state: .fresh, greeting: .sample)
    .environment(\.gardenStore, .loading)
}
