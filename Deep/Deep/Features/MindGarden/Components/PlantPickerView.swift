import SwiftUI

/// Choosing which plant the garden grows — a two-column grid of the catalog in
/// the `MindTreeCard` grammar, each plant pictured at its *own* earned stage
/// (sunlight stays with a plant; switching back resumes it). The current plant
/// wears the selection mark; tapping another switches optimistically, and a
/// refused switch surfaces as a quiet caption near the top, never an alert.
///
/// This is a leaf screen, so it owns its screen-level styling
/// (`AtmosphereBackground`); the coordinator pushes it via `GardenRoute`.
struct PlantPickerView: View {
  @Environment(\.gardenStore) private var gardenStore

  private let columns = [
    GridItem(.flexible(), spacing: 14),
    GridItem(.flexible(), spacing: 14),
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: .rhythm) {
        header

        if gardenStore.catalog.isEmpty {
          skeletonGrid
        } else {
          grid
        }

        Color.clear.frame(height: .rhythm)
      }
      .padding(.top, 12)
    }
    .scrollIndicators(.hidden)
    .scrollBounceBehavior(.basedOnSize)
    .background { AtmosphereBackground() }
    .toolbarBackground(.hidden, for: .navigationBar)
    .animation(.settle, value: gardenStore.switchFailure)
    .task { await gardenStore.loadCatalogIfNeeded() }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Choose your plant")
        .font(DeepType.displayTitle)
        .foregroundStyle(.deepPlum)
      Text("Sunlight stays with every plant — switch back any time and it grows on from where it left off.")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .fixedSize(horizontal: false, vertical: true)

      if let failure = gardenStore.switchFailure {
        Text(failure)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .padding(.top, 4)
          .transition(.opacity)
      }
    }
    .padding(.horizontal, .edge)
  }

  private var grid: some View {
    LazyVGrid(columns: columns, spacing: 14) {
      ForEach(gardenStore.catalog) { plant in
        PlantPickerCard(
          plant: plant,
          earned: GardenGrowth(
            plant: plant,
            sunlight: gardenStore.sunlightByPlant[plant.id] ?? 0
          ),
          isSelected: plant.id == gardenStore.plant?.id
        ) {
          guard plant.id != gardenStore.plant?.id else { return }
          Task { await gardenStore.selectPlant(plant) }
        }
      }
    }
    .padding(.horizontal, .edge)
  }

  /// Mirrors the loaded grid's geometry while the catalog fetches.
  private var skeletonGrid: some View {
    LazyVGrid(columns: columns, spacing: 14) {
      ForEach(0..<4, id: \.self) { _ in
        VStack(spacing: 10) {
          SkeletonBlock()
            .aspectRatio(1.2, contentMode: .fit)
          SkeletonTextLine(width: 70)
          SkeletonTextLine(width: 110)
        }
        .padding(10)
      }
    }
    .padding(.horizontal, .edge)
    .skeletonBreath()
  }
}

/// One selectable plant tile — the `MindTreeCard` grammar (artwork over the
/// branded gradient, name and caption beneath, selection mark blooming in),
/// re-grounded in the garden: the artwork is the plant's earned-stage portrait
/// and the caption says where that plant stands.
private struct PlantPickerCard: View {
  let plant: Plant
  /// The plant at its own banked sunlight — not the selected plant's.
  let earned: GardenGrowth
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 10) {
        ArtworkImage(
          url: earned.stage.mascotBgURL ?? earned.stage.mascotURL ?? plant.imageURL,
          colors: plant.palette.colors,
          cornerRadius: .tile,
          placeholderSystemImage: "leaf.fill"
        )
        .aspectRatio(1.2, contentMode: .fit)

        VStack(spacing: 2) {
          Text(plant.name)
            .font(DeepType.body)
            .foregroundStyle(.deepPlum)
          Text("Stage \(earned.stageIndex + 1) · \(earned.sunlight.formatted()) sunlight")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
        }
        .padding(.bottom, 6)
        .multilineTextAlignment(.center)
      }
      .padding(10)
      .frame(maxWidth: .infinity)
      .frostedCard(cornerRadius: .card)
      .overlay(
        RoundedRectangle(cornerRadius: .card, style: .continuous)
          .strokeBorder(.lavenderMist, lineWidth: isSelected ? 1.5 : 0)
      )
      .overlay(alignment: .topTrailing) { selectionMark }
      .contentShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
    }
    .buttonStyle(.softPress)
    .animation(.settle, value: isSelected)
    .accessibilityLabel(
      "\(plant.name), stage \(earned.stageIndex + 1), \(earned.sunlight) sunlight"
    )
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }

  @ViewBuilder
  private var selectionMark: some View {
    if isSelected {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 22))
        .foregroundStyle(.lavenderMist)
        .background(Circle().fill(.white).padding(2))
        .padding(16)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }
  }
}

#Preview("Plant picker") {
  PlantPickerView()
    .environment(\.gardenStore, .pickerSample)
    .environment(\.imageLoader, FixtureImageLoader())
}

#Preview("Plant picker — switch refused") {
  PlantPickerView()
    .environment(\.gardenStore, .switchFailed)
    .environment(\.imageLoader, FixtureImageLoader())
}

#Preview("Plant picker — loading catalog") {
  // An empty mock catalog keeps the fetch answering with nothing, so the
  // skeleton grid holds instead of flashing.
  PlantPickerView()
    .environment(
      \.gardenStore,
      GardenStore(
        remote: MockRewardsRemote(catalog: []),
        defaults: UserDefaults(suiteName: "deep.garden.preview.empty") ?? .standard
      )
    )
    .environment(\.imageLoader, FixtureImageLoader())
}
