package io.appbeyond.freelance.deep.feature.mindgarden.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.appshell.DeepIcons
import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenGrowth
import io.appbeyond.freelance.deep.feature.mindgarden.model.Plant
import io.appbeyond.freelance.deep.feature.mindgarden.store.GardenStore
import io.appbeyond.freelance.deep.feature.mindgarden.store.GardenStore.PlantCatalog
import io.appbeyond.freelance.deep.feature.onboarding.components.FilledCheckMark
import io.appbeyond.freelance.deep.feature.onboarding.components.HollowMark
import io.appbeyond.freelance.deep.feature.rewards.store.MockRewardsRemote
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.PlantGrowthHalo
import io.appbeyond.freelance.deep.shared.components.SkeletonBlock
import io.appbeyond.freelance.deep.shared.components.SkeletonTextLine
import io.appbeyond.freelance.deep.shared.components.SunlightFact
import io.appbeyond.freelance.deep.shared.components.skeletonBreath
import io.appbeyond.freelance.deep.shared.persistence.InMemoryBlobStore
import io.appbeyond.freelance.deep.theme.CONFIRMATION_HOLD_MILLIS
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.peachCloud
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.settle
import io.appbeyond.freelance.deep.theme.skyWash
import io.appbeyond.freelance.deep.theme.softLilac
import io.appbeyond.freelance.deep.theme.softPress
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// MARK: - Constants

/** Catalog rows, and skeleton rows — iOS's `VStack(spacing: 14)`. */
private val LIST_SPACING = 14.dp

/** Title to subtitle — iOS's `VStack(spacing: 6)`. */
private val HEADER_SPACING = 6.dp

/** The list's foot above the bar — iOS's `.padding(.bottom, 12)`. */
private val LIST_BOTTOM_PADDING = 12.dp

/** A row's inset — iOS's `.padding(.vertical, 14).padding(.horizontal, 16)`. */
private val ROW_PADDING_VERTICAL = 14.dp
private val ROW_PADDING_HORIZONTAL = 16.dp
private val ROW_SPACING = 16.dp

/** The staged row's ring — iOS's `strokeBorder(.lavenderMist, lineWidth: 1.5)`. */
private val STAGED_BORDER = 1.5.dp

/** The unstaged mark's ring — iOS's `driftGrey.opacity(0.5)`. */
private const val HOLLOW_MARK_ALPHA = 0.5f

/** The row's halo — portrait 56, gap 4, ring 3. */
private val ROW_PORTRAIT = 56.dp
private val ROW_RING_GAP = 4.dp
private val ROW_RING_WIDTH = 3.dp

/** The skeleton row's circle — iOS's 73pt block. */
private val SKELETON_CIRCLE = 73.dp

/** The confirm bar — iOS's `padding(.top, 12)`, `padding(.bottom, 6)`, and its two labels' insets. */
private val BAR_PADDING_TOP = 12.dp
private val BAR_PADDING_BOTTOM = 6.dp
private val BAR_SPACING = 8.dp
private val LABEL_PADDING_HORIZONTAL = 22.dp
private val LABEL_PADDING_VERTICAL = 16.dp
private val LABEL_GLYPH_SPACING = 10.dp
private val LABEL_GLYPH_SIZE = 18.dp

/** The capsule's bloom — iOS's `shadow(lavenderMist 0.35, radius: 18, y: 10)`. */
private const val CAPSULE_BLOOM_ALPHA = 0.35f
private val CAPSULE_BLOOM_RADIUS = 18.dp
private val CAPSULE_BLOOM_OFFSET_Y = 10.dp

/** The grabber's tint — the lyrics sheet's soft lavender pill. */
private const val HANDLE_ALPHA = 0.5f

/** The failed state's breathing room and its retry chip — DEEP Sound's shelves-failed shape. */
private val FAILED_PADDING_VERTICAL = 32.dp
private val FAILED_SPACING = 14.dp
private val RETRY_PADDING_HORIZONTAL = 22.dp
private val RETRY_PADDING_VERTICAL = 12.dp

private const val SKELETON_ROWS = 3

// MARK: - Sheet

/**
 * Choosing which plant the garden grows, raised as a sheet over the garden
 * itself. Every plant stands in the garden's own language — its current form
 * inside the growth halo, its name with that form named quietly beneath, and
 * the sunlight it has banked — because sunlight stays with a plant: switch back
 * and it grows on from where it left off.
 *
 * Nothing changes until it is confirmed. Tapping a row only stages a choice
 * (with a selection tick); the bar at the foot commits it, holds "Growing …"
 * for half a second, and lets the sheet go. A refused switch keeps the sheet
 * open with [GardenStore.State.switchFailed] as a quiet caption, and the
 * staged choice falls back to whatever is actually growing.
 *
 * Ported from Deep/Deep/Features/MindGarden/Components/PlantPickerSheet.swift,
 * on the lyrics sheet's frame (a Material3 [ModalBottomSheet] in DEEP's
 * tokens) but standing on the [AtmosphereBackground] rather than a flat
 * surface, as iOS's `presentationBackground` does. The grabber is drawn inside
 * the atmosphere so the sheet reads as one surface to its top edge. iOS opens
 * at a 560pt detent; here the sheet hugs its content, which for the seeded
 * catalog lands at about that height and grows to full height for a longer one.
 *
 * DIVERGENCE: [PlantCatalog.Failed] (or a catalog that came back empty) shows
 * a quiet line and a "Try again" chip instead of iOS's endless skeleton.
 *
 * @param garden the store the catalog, the banked tallies and the switch go
 *   through. The sheet asks it for the catalog when it opens.
 * @param onDismiss the sheet has gone — swiped away, kept, or switched.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlantPickerSheet(
  garden: GardenStore,
  onDismiss: () -> Unit,
) {
  val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
  val scope = rememberCoroutineScope()
  val haptics = LocalHapticFeedback.current
  val state by garden.state.collectAsStateWithLifecycle()

  // The plant the bar would grow. Null until something is tapped — which reads
  // as the plant already growing, so the sheet opens marked correctly even when
  // the first garden snapshot lands after it does.
  var draftId by remember { mutableStateOf<String?>(null) }
  // Set while the switch is in flight, so the bar finishes its sentence before
  // the sheet leaves.
  var isConfirming by remember { mutableStateOf(false) }

  LaunchedEffect(garden) { garden.loadCatalogIfNeeded() }

  fun close() {
    scope.launch {
      sheetState.hide()
      onDismiss()
    }
  }

  ModalBottomSheet(
    onDismissRequest = onDismiss,
    sheetState = sheetState,
    shape = RoundedCornerShape(topStart = Dp.card, topEnd = Dp.card),
    containerColor = Color.moonCream,
    contentColor = Color.deepPlum,
    tonalElevation = 0.dp,
    dragHandle = null,
  ) {
    PlantPickerBody(
      state = state,
      stagedId = draftId ?: state.plant?.id,
      isConfirming = isConfirming,
      onStage = { plant ->
        if (plant.id != (draftId ?: state.plant?.id)) {
          haptics.performHapticFeedback(HapticFeedbackType.SegmentTick)
        }
        draftId = plant.id
      },
      onConfirm = { plant ->
        isConfirming = true
        scope.launch {
          garden.selectPlant(plant)
          val settled = garden.state.value
          if (settled.switchFailed) {
            isConfirming = false
            draftId = settled.plant?.id
            return@launch
          }
          delay(CONFIRMATION_HOLD_MILLIS)
          close()
        }
      },
      onKeep = ::close,
      onRetry = { scope.launch { garden.retryCatalog() } },
    )
  }
}

/**
 * The sheet's body — header, catalog and the confirm bar — on the atmosphere.
 * Stateless, so previews can render each catalog state without a sheet window.
 *
 * The catalog scrolls above the bar rather than under it: the one act on this
 * sheet keeps its own ground, so no plant is ever half-hidden behind it.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PlantPickerBody(
  state: GardenStore.State,
  stagedId: String?,
  isConfirming: Boolean,
  onStage: (Plant) -> Unit,
  onConfirm: (Plant) -> Unit,
  onKeep: () -> Unit,
  onRetry: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val plants = state.catalog.plants
  val stagedPlant = plants.firstOrNull { it.id == stagedId }
  val isGrowingStaged = stagedId == state.plant?.id

  Box(modifier.fillMaxWidth()) {
    AtmosphereBackground(Modifier.matchParentSize())

    Column(Modifier.fillMaxWidth()) {
      BottomSheetDefaults.DragHandle(
        color = Color.lavenderMist.copy(alpha = HANDLE_ALPHA),
        modifier = Modifier.align(Alignment.CenterHorizontally),
      )

      Column(
        Modifier
          .weight(1f, fill = false)
          .verticalScroll(rememberScrollState())
          .padding(horizontal = Dp.edge)
          .padding(bottom = LIST_BOTTOM_PADDING),
        verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
      ) {
        PickerHeader()

        when (state.catalog) {
          PlantCatalog.Idle, PlantCatalog.Loading -> SkeletonList()
          // A catalog that came back empty is as unanswered as a failed one.
          PlantCatalog.Failed -> CatalogFailed(onRetry = onRetry)
          is PlantCatalog.Loaded -> if (plants.isEmpty()) {
            CatalogFailed(onRetry = onRetry)
          } else {
            PlantList(
              plants = plants,
              sunlightByPlant = state.sunlightByPlant,
              stagedId = stagedId,
              onStage = onStage,
            )
          }
        }
      }

      ConfirmBar(
        stagedPlant = stagedPlant,
        isGrowingStaged = isGrowingStaged,
        isConfirming = isConfirming,
        switchFailed = state.switchFailed,
        onConfirm = onConfirm,
        onKeep = onKeep,
      )
    }
  }
}

@Composable
private fun PickerHeader() {
  Column(
    Modifier.fillMaxWidth(),
    verticalArrangement = Arrangement.spacedBy(HEADER_SPACING),
  ) {
    Text(stringResource(R.string.picker_title), style = DeepType.displayTitle, color = Color.deepPlum)
    Text(stringResource(R.string.picker_subtitle), style = DeepType.caption, color = Color.driftGrey)
  }
}

// MARK: - Catalog

@Composable
private fun PlantList(
  plants: List<Plant>,
  sunlightByPlant: Map<String, Int>,
  stagedId: String?,
  onStage: (Plant) -> Unit,
) {
  Column(verticalArrangement = Arrangement.spacedBy(LIST_SPACING)) {
    plants.forEach { plant ->
      PlantChoiceRow(
        plant = plant,
        // Each plant at its OWN banked sunlight, so the portrait is that
        // plant's current form rather than the selected plant's.
        earned = GardenGrowth(plant = plant, sunlight = sunlightByPlant[plant.id] ?: 0),
        isStaged = plant.id == stagedId,
        onClick = { onStage(plant) },
      )
    }
  }
}

/**
 * One plant to choose from, told the way the growth card tells the selected
 * one: the current form in its halo, the plant's name with that form named
 * quietly under it, and the sunlight banked into it as a single gold mark.
 *
 * The card carries the plant's own palette as the frosted wash, so each row
 * reads as its plant before a word is read. Staged, it takes a lavender ring
 * and the filled check the onboarding pickers use.
 */
@Composable
private fun PlantChoiceRow(
  plant: Plant,
  earned: GardenGrowth,
  isStaged: Boolean,
  onClick: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val border by animateDpAsState(
    targetValue = if (isStaged) STAGED_BORDER else 0.dp,
    animationSpec = settle(),
    label = "plant-row-border",
  )
  val summary = stringResource(R.string.picker_row_summary, plant.name, earned.stage.name, earned.sunlight)
  val shape = RoundedCornerShape(Dp.card)

  Row(
    modifier
      .fillMaxWidth()
      .softPress()
      .frostedCard(cornerRadius = Dp.card, tint = paletteTint(plant.palette))
      .then(if (border > 0.dp) Modifier.border(border, Color.lavenderMist, shape) else Modifier)
      .clickable(interactionSource = null, indication = null, onClick = onClick)
      .clearAndSetSemantics {
        contentDescription = summary
        role = Role.RadioButton
        selected = isStaged
        onClick { onClick(); true }
      }
      .padding(vertical = ROW_PADDING_VERTICAL, horizontal = ROW_PADDING_HORIZONTAL),
    horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    PlantGrowthHalo(
      progress = earned.evolutionProgress.toFloat(),
      portraitUrl = earned.stage.mascotUrl ?: earned.stage.mascotBgUrl,
      fallbackUrl = plant.imageUrl,
      palette = plant.palette,
      portraitDiameter = ROW_PORTRAIT,
      ringGap = ROW_RING_GAP,
      ringWidth = ROW_RING_WIDTH,
    )

    // A greedy column rather than a Spacer: a Spacer would bid against the
    // text for width and wrap the name on a row with room to spare.
    Column(Modifier.weight(1f)) {
      Text(plant.name, style = DeepType.sectionTitle, color = Color.deepPlum)
      Text(
        earned.stage.name,
        style = DeepType.caption,
        color = Color.driftGrey,
        modifier = Modifier.padding(top = 2.dp),
      )
      SunlightFact(sunlight = earned.sunlight, modifier = Modifier.padding(top = 6.dp))
    }

    AnimatedContent(
      targetState = isStaged,
      transitionSpec = {
        (scaleIn(settle(), initialScale = 0.6f) + fadeIn(settle()))
          .togetherWith(scaleOut(settle(), targetScale = 0.6f) + fadeOut(settle()))
      },
      contentAlignment = Alignment.Center,
      label = "plant-row-mark",
    ) { staged ->
      if (staged) FilledCheckMark() else HollowMark(alpha = HOLLOW_MARK_ALPHA)
    }
  }
}

/**
 * The first stop of the plant's artwork palette — iOS's
 * `plant.palette.colors.first` — for the row's frosted wash. Mirrors the stops
 * `ArtworkImage` paints for the same names; an unknown name washes lavender,
 * as the artwork does.
 */
private fun paletteTint(palette: String): Color = when (palette.lowercase()) {
  "tide", "meadow" -> Color.skyWash
  "dawn", "ember" -> Color.peachCloud
  "bloom" -> Color.blushPowder
  "dusk", "mist" -> Color.softLilac
  else -> Color.lavenderMist
}

/**
 * Mirrors a loaded row's geometry while the catalog fetches, so the list
 * doesn't reflow when the plants arrive.
 */
@Composable
private fun SkeletonList() {
  Column(
    Modifier.skeletonBreath(),
    verticalArrangement = Arrangement.spacedBy(LIST_SPACING),
  ) {
    repeat(SKELETON_ROWS) {
      Row(
        Modifier
          .fillMaxWidth()
          .frostedCard(cornerRadius = Dp.card)
          .padding(vertical = ROW_PADDING_VERTICAL, horizontal = ROW_PADDING_HORIZONTAL),
        horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
        verticalAlignment = Alignment.CenterVertically,
      ) {
        SkeletonBlock(Modifier.size(SKELETON_CIRCLE), cornerRadius = SKELETON_CIRCLE / 2)
        Column(
          Modifier.weight(1f),
          verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
          SkeletonTextLine(width = 90.dp)
          SkeletonTextLine(width = 130.dp)
          SkeletonTextLine(width = 60.dp)
        }
      }
    }
  }
}

/**
 * DIVERGENCE: the catalog didn't come. iOS keeps breathing the skeleton
 * forever; here it says so, quietly, and offers the one thing that helps —
 * DEEP Sound's shelves-failed shape, a calm line over a frosted chip.
 */
@Composable
private fun CatalogFailed(onRetry: () -> Unit) {
  Column(
    Modifier
      .fillMaxWidth()
      .padding(vertical = FAILED_PADDING_VERTICAL),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(FAILED_SPACING),
  ) {
    Text(
      stringResource(R.string.picker_failed),
      style = DeepType.body,
      color = Color.driftGrey,
      textAlign = TextAlign.Center,
    )
    Box(
      Modifier
        .softPress()
        .frostedCard(cornerRadius = Dp.chip)
        .clickable(interactionSource = null, indication = null, role = Role.Button, onClick = onRetry)
        .padding(horizontal = RETRY_PADDING_HORIZONTAL, vertical = RETRY_PADDING_VERTICAL),
    ) {
      Text(stringResource(R.string.picker_retry), style = DeepType.bodyMedium, color = Color.deepPlum)
    }
  }
}

// MARK: - Confirm

/** What the foot of the sheet is saying. */
private sealed interface BarState {
  data class Growing(val name: String) : BarState
  data class Grow(val plant: Plant) : BarState
  data class Keep(val name: String) : BarState
  data object Waiting : BarState
}

/**
 * The one act on this sheet, standing on its own ground at the foot. It is
 * never a dimmed button: with nothing to switch to it becomes the way out
 * instead, and while the catalog is still coming it is a quiet note. A refused
 * switch rolled back quietly; its caption sits under the bar until the next
 * confirm clears it.
 */
@Composable
private fun ConfirmBar(
  stagedPlant: Plant?,
  isGrowingStaged: Boolean,
  isConfirming: Boolean,
  switchFailed: Boolean,
  onConfirm: (Plant) -> Unit,
  onKeep: () -> Unit,
) {
  val bar = when {
    stagedPlant == null -> BarState.Waiting
    isConfirming -> BarState.Growing(stagedPlant.name)
    !isGrowingStaged -> BarState.Grow(stagedPlant)
    else -> BarState.Keep(stagedPlant.name)
  }

  Column(
    Modifier
      .fillMaxWidth()
      .navigationBarsPadding()
      .padding(horizontal = Dp.edge)
      .padding(top = BAR_PADDING_TOP, bottom = BAR_PADDING_BOTTOM),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(BAR_SPACING),
  ) {
    AnimatedContent(
      targetState = bar,
      transitionSpec = { fadeIn(exhale()) togetherWith fadeOut(exhale()) },
      contentKey = { it::class },
      label = "picker-confirm-bar",
    ) { current ->
      when (current) {
        // Not a button any more: the switch is already on its way.
        is BarState.Growing -> CapsuleLabel(title = stringResource(R.string.picker_growing, current.name))
        is BarState.Grow -> {
          val hint = stringResource(R.string.picker_grow_hint)
          CapsuleLabel(
            title = stringResource(R.string.picker_grow, current.plant.name),
            modifier = Modifier
              .softPress()
              .clickable(
                interactionSource = null,
                indication = null,
                role = Role.Button,
                onClickLabel = hint,
                onClick = { onConfirm(current.plant) },
              ),
          )
        }
        is BarState.Keep -> QuietLabel(
          title = stringResource(R.string.picker_keep, current.name),
          tint = Color.deepPlum,
          modifier = Modifier
            .softPress()
            .clickable(interactionSource = null, indication = null, role = Role.Button, onClick = onKeep),
        )
        BarState.Waiting -> QuietLabel(title = stringResource(R.string.picker_title), tint = Color.driftGrey)
      }
    }

    AnimatedVisibility(
      visible = switchFailed,
      enter = fadeIn(settle()),
      exit = fadeOut(settle()),
      label = "picker-switch-failure",
    ) {
      Text(
        stringResource(R.string.picker_switch_failed),
        style = DeepType.caption,
        color = Color.driftGrey,
        textAlign = TextAlign.Center,
      )
    }
  }
}

/** The capsule the switch commits on — lavender into blush, lifted on its bloom. */
@Composable
private fun CapsuleLabel(title: String, modifier: Modifier = Modifier) {
  val shape = RoundedCornerShape(percent = 50)
  Row(
    Modifier
      .fillMaxWidth()
      .then(modifier)
      .dropShadow(
        shape = shape,
        shadow = Shadow(
          radius = CAPSULE_BLOOM_RADIUS,
          color = Color.lavenderMist.copy(alpha = CAPSULE_BLOOM_ALPHA),
          offset = DpOffset(0.dp, CAPSULE_BLOOM_OFFSET_Y),
        ),
      )
      .background(Brush.horizontalGradient(listOf(Color.lavenderMist, Color.blushPowder)), shape)
      .padding(horizontal = LABEL_PADDING_HORIZONTAL, vertical = LABEL_PADDING_VERTICAL),
    horizontalArrangement = Arrangement.spacedBy(LABEL_GLYPH_SPACING, Alignment.CenterHorizontally),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Icon(
      imageVector = DeepIcons.Leaf,
      contentDescription = null,
      tint = Color.White,
      modifier = Modifier.size(LABEL_GLYPH_SIZE),
    )
    Text(
      title,
      style = DeepType.sectionTitle,
      color = Color.White,
      maxLines = 1,
      overflow = TextOverflow.Ellipsis,
    )
  }
}

/** The bar when there is nothing to commit — frosted, never a dimmed CTA. */
@Composable
private fun QuietLabel(title: String, tint: Color, modifier: Modifier = Modifier) {
  Box(
    Modifier
      .fillMaxWidth()
      .then(modifier)
      .frostedCard(cornerRadius = Dp.chip)
      .padding(horizontal = LABEL_PADDING_HORIZONTAL, vertical = LABEL_PADDING_VERTICAL),
    contentAlignment = Alignment.Center,
  ) {
    Text(title, style = DeepType.sectionTitle, color = tint, maxLines = 1, overflow = TextOverflow.Ellipsis)
  }
}

// MARK: - Previews

/*
 * The sheet itself previews poorly — a ModalBottomSheet opens in its own
 * window — so most of these render its body on the sheet's surface instead.
 */

private val PreviewTallies = mapOf("oak" to 240, "sakura" to 160, "lotus" to 0)

private fun previewState(catalog: PlantCatalog, switchFailed: Boolean = false) = GardenStore.State(
  plant = Plant.oakFixture,
  sunlight = 240,
  sunlightByPlant = PreviewTallies,
  catalog = catalog,
  switchFailed = switchFailed,
)

@Composable
private fun PickerPreviewSurface(content: @Composable () -> Unit) {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream), contentAlignment = Alignment.BottomCenter) {
      content()
    }
  }
}

/** The real sheet over a mock garden — run it in interactive mode. */
@Preview(showBackground = true, name = "Plant picker — sheet (interactive)")
@Composable
private fun PlantPickerSheetPreview() {
  val garden = remember {
    GardenStore(remote = MockRewardsRemote(sunlightByPlant = PreviewTallies), blob = InMemoryBlobStore())
      .apply { seed(Plant.oakFixture, sunlight = 240, sunlightByPlant = PreviewTallies) }
  }
  DeepTheme { PlantPickerSheet(garden = garden, onDismiss = {}) }
}

@Preview(showBackground = true, name = "Plant picker — keep")
@Composable
private fun PlantPickerKeepPreview() {
  PickerPreviewSurface {
    PlantPickerBody(
      state = previewState(PlantCatalog.Loaded(Plant.fixtures)),
      stagedId = "oak",
      isConfirming = false,
      onStage = {}, onConfirm = {}, onKeep = {}, onRetry = {},
    )
  }
}

@Preview(showBackground = true, name = "Plant picker — grow")
@Composable
private fun PlantPickerGrowPreview() {
  PickerPreviewSurface {
    PlantPickerBody(
      state = previewState(PlantCatalog.Loaded(Plant.fixtures)),
      stagedId = "sakura",
      isConfirming = false,
      onStage = {}, onConfirm = {}, onKeep = {}, onRetry = {},
    )
  }
}

@Preview(showBackground = true, name = "Plant picker — switch refused")
@Composable
private fun PlantPickerRefusedPreview() {
  PickerPreviewSurface {
    PlantPickerBody(
      state = previewState(PlantCatalog.Loaded(Plant.fixtures), switchFailed = true),
      stagedId = "oak",
      isConfirming = false,
      onStage = {}, onConfirm = {}, onKeep = {}, onRetry = {},
    )
  }
}

@Preview(showBackground = true, name = "Plant picker — loading catalog")
@Composable
private fun PlantPickerLoadingPreview() {
  PickerPreviewSurface {
    PlantPickerBody(
      state = previewState(PlantCatalog.Loading),
      stagedId = "oak",
      isConfirming = false,
      onStage = {}, onConfirm = {}, onKeep = {}, onRetry = {},
    )
  }
}

@Preview(showBackground = true, name = "Plant picker — catalog failed")
@Composable
private fun PlantPickerFailedPreview() {
  PickerPreviewSurface {
    PlantPickerBody(
      state = previewState(PlantCatalog.Failed),
      stagedId = "oak",
      isConfirming = false,
      onStage = {}, onConfirm = {}, onKeep = {}, onRetry = {},
    )
  }
}

@Preview(showBackground = true, name = "Plant picker — large type", fontScale = 1.6f)
@Composable
private fun PlantPickerLargeTypePreview() {
  PickerPreviewSurface {
    PlantPickerBody(
      state = previewState(PlantCatalog.Loaded(Plant.fixtures)),
      stagedId = "sakura",
      isConfirming = true,
      onStage = {}, onConfirm = {}, onKeep = {}, onRetry = {},
    )
  }
}
