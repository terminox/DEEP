import SwiftUI

/// Choosing which plant the garden grows, raised as a sheet over the garden
/// itself. Every plant stands in the garden's own language — its current form
/// inside the growth halo, its name with that form named quietly beneath, and
/// the sunlight it has banked — because sunlight stays with a plant: switch
/// back and it grows on from where it left off.
///
/// Nothing changes until it is confirmed. Tapping a row only stages a choice;
/// the bar at the foot commits it, and a refused switch keeps the sheet open
/// with a quiet caption rather than an alert.
struct PlantPickerSheet: View {
  @Environment(\.gardenStore) private var gardenStore
  @Environment(\.dismiss) private var dismiss

  /// The plant the confirm bar would grow. Nil until something is tapped —
  /// which reads as the plant already growing, so the sheet opens marked
  /// correctly even when the first garden snapshot lands after it does.
  @State private var draftID: String?
  /// Set while the switch is in flight, so the bar finishes its sentence before
  /// the sheet leaves.
  @State private var isConfirming = false

  private var stagedID: String? { draftID ?? gardenStore.plant?.id }
  private var stagedPlant: Plant? { gardenStore.catalog.first { $0.id == stagedID } }
  private var isGrowingStaged: Bool { stagedID == gardenStore.plant?.id }

  var body: some View {
    // The catalog scrolls above the bar rather than under it: the one act on
    // this sheet keeps its own ground, so no plant is ever half-hidden behind
    // it.
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: .rhythm) {
          header

          if gardenStore.catalog.isEmpty {
            skeletonList
          } else {
            list
          }
        }
        .padding(.horizontal, .edge)
        .padding(.top, .rhythm)
        .padding(.bottom, 12)
      }
      .scrollIndicators(.hidden)
      .scrollBounceBehavior(.basedOnSize)

      confirmBar
    }
    .sensoryFeedback(.selection, trigger: stagedID)
    .presentationDetents([.height(560), .large])
    .presentationBackground { AtmosphereBackground() }
    .task { await gardenStore.loadCatalogIfNeeded() }
  }

  // MARK: - Catalog

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Choose your plant")
        .font(DeepType.displayTitle)
        .foregroundStyle(.deepPlum)
      Text("Sunlight stays with every plant — switch back any time and it grows on from where it left off.")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var list: some View {
    VStack(spacing: 14) {
      ForEach(gardenStore.catalog) { plant in
        PlantChoiceRow(
          plant: plant,
          // Each plant at its OWN banked sunlight, so the portrait is that
          // plant's current form rather than the selected plant's.
          earned: GardenGrowth(
            plant: plant,
            sunlight: gardenStore.sunlightByPlant[plant.id] ?? 0
          ),
          isStaged: plant.id == stagedID
        ) {
          withAnimation(.settle) { draftID = plant.id }
        }
      }
    }
  }

  /// Mirrors a loaded row's geometry while the catalog fetches, so the list
  /// doesn't reflow when the plants arrive.
  private var skeletonList: some View {
    VStack(spacing: 14) {
      ForEach(0..<3, id: \.self) { _ in
        HStack(spacing: 16) {
          SkeletonBlock(cornerRadius: 36.5)
            .frame(width: 73, height: 73)

          VStack(alignment: .leading, spacing: 8) {
            SkeletonTextLine(width: 90)
            SkeletonTextLine(width: 130)
            SkeletonTextLine(width: 60)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frostedCard(cornerRadius: .card)
      }
    }
    .skeletonBreath()
  }

  // MARK: - Confirm

  /// The one act on this sheet, standing on its own ground at the foot. It is
  /// never a dimmed button: with nothing to switch to it becomes the way out
  /// instead, and while the catalog is still coming it is a quiet note.
  private var confirmBar: some View {
    VStack(spacing: 8) {
      Group {
        if isConfirming, let staged = stagedPlant {
          capsuleLabel {
            Image(systemName: "leaf.fill")
              .font(.system(size: 16, weight: .semibold))
            Text("Growing \(staged.name)")
          }
          .allowsHitTesting(false)
          .accessibilityAddTraits(.isStaticText)
        } else if let staged = stagedPlant, !isGrowingStaged {
          Button {
            confirm(staged)
          } label: {
            capsuleLabel {
              Image(systemName: "leaf.fill")
                .font(.system(size: 16, weight: .semibold))
              Text("Grow \(staged.name)")
            }
          }
          .buttonStyle(.softPress)
          .accessibilityLabel("Grow \(staged.name)")
          .accessibilityHint("Switches your garden to this plant")
        } else if let staged = stagedPlant {
          Button {
            dismiss()
          } label: {
            quietLabel("Keep \(staged.name)", tint: .deepPlum)
          }
          .buttonStyle(.softPress)
          .accessibilityLabel("Keep \(staged.name)")
        } else {
          // The catalog hasn't landed yet — a note, never a dimmed CTA.
          quietLabel("Choose your plant", tint: .driftGrey)
            .accessibilityAddTraits(.isStaticText)
        }
      }
      .animation(.exhale, value: stagedID)
      .animation(.exhale, value: isConfirming)

      // A refused switch rolled back quietly; the next confirm clears it.
      if let failure = gardenStore.switchFailure {
        Text(failure)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .multilineTextAlignment(.center)
          .transition(.opacity)
      }
    }
    .animation(.settle, value: gardenStore.switchFailure)
    .padding(.horizontal, .edge)
    .padding(.top, 12)
    .padding(.bottom, 6)
  }

  /// Switches, then holds for a beat so the bar can say what happened before
  /// the sheet leaves. A refusal keeps the sheet open and falls the staged
  /// choice back to whatever is actually growing.
  private func confirm(_ plant: Plant) {
    isConfirming = true
    Task {
      await gardenStore.selectPlant(plant)
      guard gardenStore.switchFailure == nil else {
        isConfirming = false
        draftID = gardenStore.plant?.id
        return
      }
      try? await Task.sleep(for: .seconds(0.5))
      dismiss()
    }
  }

  private func capsuleLabel<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    HStack(spacing: 10) {
      content()
    }
    .font(DeepType.sectionTitle)
    .foregroundStyle(.white)
    .lineLimit(1)
    .minimumScaleFactor(0.8)
    .padding(.horizontal, 22)
    .padding(.vertical, 16)
    .frame(maxWidth: .infinity)
    .background {
      Capsule().fill(
        LinearGradient(colors: [.lavenderMist, .blushPowder], startPoint: .leading, endPoint: .trailing)
      )
    }
    .shadow(color: Color.lavenderMist.opacity(0.35), radius: 18, y: 10)
  }

  private func quietLabel(_ title: String, tint: Color) -> some View {
    Text(title)
      .font(DeepType.sectionTitle)
      .foregroundStyle(tint)
      .lineLimit(1)
      .minimumScaleFactor(0.8)
      .padding(.horizontal, 22)
      .padding(.vertical, 16)
      .frame(maxWidth: .infinity)
      .frostedCard(cornerRadius: .chip)
  }
}

/// One plant to choose from, told the way the growth card tells the selected
/// one: the current form in its halo, the plant's name with that form named
/// quietly under it, and the sunlight banked into it as a single gold mark.
///
/// The card carries the plant's own palette as the frosted wash, so each row
/// reads as its plant before a word is read.
private struct PlantChoiceRow: View {
  let plant: Plant
  /// The plant at its own banked sunlight — not the selected plant's.
  let earned: GardenGrowth
  /// Whether the confirm bar would grow this plant. Staged, not committed.
  let isStaged: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 16) {
        PlantGrowthHalo(
          stage: earned.stage,
          palette: plant.palette,
          progress: earned.evolutionProgress,
          fallbackURL: plant.imageURL,
          portraitDiameter: 56,
          ringGap: 4,
          ringWidth: 3
        )

        VStack(alignment: .leading, spacing: 2) {
          Text(plant.name)
            .font(DeepType.sectionTitle)
            .foregroundStyle(.deepPlum)
          Text(earned.stage.name)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)

          SunlightFact {
            Text(earned.sunlight.formatted())
              .font(DeepType.caption.weight(.semibold))
              .foregroundStyle(GardenColor.sunbeam)
              .monospacedDigit()
          }
          .padding(.top, 4)
        }
        .multilineTextAlignment(.leading)
        // A `Spacer` here would bid against the text column and wrap the name
        // on a row with room to spare; a greedy frame leaves it its width.
        .frame(maxWidth: .infinity, alignment: .leading)

        selectionMark
      }
      .padding(.vertical, 14)
      .padding(.horizontal, 16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .frostedCard(cornerRadius: .card, tint: plant.palette.colors.first)
      .overlay(
        RoundedRectangle(cornerRadius: .card, style: .continuous)
          .strokeBorder(.lavenderMist, lineWidth: isStaged ? 1.5 : 0)
      )
      .contentShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
    }
    .buttonStyle(.softPress)
    .animation(.settle, value: isStaged)
    .accessibilityLabel(
      "\(plant.name), \(earned.stage.name), \(earned.sunlight) sunlight"
    )
    .accessibilityAddTraits(isStaged ? [.isSelected] : [])
  }

  @ViewBuilder
  private var selectionMark: some View {
    if isStaged {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 22))
        .foregroundStyle(.lavenderMist)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    } else {
      Circle()
        .strokeBorder(Color.driftGrey.opacity(0.5), lineWidth: 1.5)
        .frame(width: 22, height: 22)
    }
  }
}

#Preview("Plant picker — sheet") {
  @Previewable @State var open = true
  Color.clear
    .background { AtmosphereBackground() }
    .sheet(isPresented: $open) { PlantPickerSheet() }
    .environment(\.gardenStore, .pickerSample)
    .environment(\.imageLoader, FixtureImageLoader())
}

#Preview("Plant picker — switch refused") {
  @Previewable @State var open = true
  Color.clear
    .background { AtmosphereBackground() }
    .sheet(isPresented: $open) { PlantPickerSheet() }
    .environment(\.gardenStore, .switchFailed)
    .environment(\.imageLoader, FixtureImageLoader())
}

#Preview("Plant picker — loading catalog") {
  @Previewable @State var open = true
  // An empty mock catalog keeps the fetch answering with nothing, so the
  // skeleton list holds instead of flashing.
  Color.clear
    .background { AtmosphereBackground() }
    .sheet(isPresented: $open) { PlantPickerSheet() }
    .environment(
      \.gardenStore,
      GardenStore(
        remote: MockRewardsRemote(catalog: []),
        defaults: UserDefaults(suiteName: "deep.garden.preview.empty") ?? .standard
      )
    )
    .environment(\.imageLoader, FixtureImageLoader())
}

#Preview("Plant picker — large type") {
  @Previewable @State var open = true
  Color.clear
    .background { AtmosphereBackground() }
    .sheet(isPresented: $open) { PlantPickerSheet() }
    .environment(\.gardenStore, .pickerSample)
    .environment(\.imageLoader, FixtureImageLoader())
    .environment(\.dynamicTypeSize, .accessibility2)
}
