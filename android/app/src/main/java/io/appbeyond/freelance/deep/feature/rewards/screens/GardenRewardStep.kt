package io.appbeyond.freelance.deep.feature.rewards.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.appshell.DeepIcons
import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenGrowth
import io.appbeyond.freelance.deep.feature.rewards.model.RewardReceipt
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.PlantGrowthHalo
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.ENTRANCE_HOLD_MILLIS
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.meadow
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.sage
import io.appbeyond.freelance.deep.theme.sunbeam
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

// MARK: - Constants

/** The card's column — iOS's `VStack(spacing: 18)` and the copy's `spacing: 7`. */
private val CARD_SPACING = 18.dp
private val COPY_SPACING = 7.dp

/** The reward's halo, larger than the home's — portrait 126, gap 7, ring 5. */
private val PORTRAIT = 126.dp
private val RING_GAP = 7.dp
private val RING_WIDTH = 5.dp

/** The new form arriving — iOS's `.scale(scale: 0.94)` with opacity. */
private const val SWAP_SCALE = 0.94f

/** The catching-up artwork — a 150 ring of meadow, a white seat, a gold sun. */
private val CATCHING_UP_SIZE = 150.dp
private val CATCHING_UP_RING = 5.dp
private val CATCHING_UP_SEAT_INSET = 12.dp
private const val CATCHING_UP_RING_ALPHA = 0.55f
private const val SEAT_ALPHA = 0.62f

/** iOS's 44pt light `sun.max.fill`, measured to its box. */
private val CATCHING_UP_SUN = 48.dp

private val REWARD_LINE_STYLE = DeepType.body.copy(fontWeight = FontWeight.SemiBold)
private val PROGRESS_STYLE = DeepType.caption.copy(fontFeatureSettings = "tnum")

// MARK: - Step

/**
 * What the halo shows: a form and how far round its ring is. One value, so the
 * leaving form keeps its own arc as it fades rather than sweeping to the next
 * form's.
 */
private data class HaloFrame(val growth: GardenGrowth, val progress: Float)

/**
 * The first reward: the member's chosen plant receives this session's
 * sunlight. It borrows the garden's portrait halo, stripped to one calm fact.
 *
 * Ported from Deep/Deep/Features/Rewards/Screens/GardenRewardView.swift. The
 * card opens on the plant as it stood before the session; 350ms after it
 * blooms in, the sunlight counts up on the exhale and the arc fills with it.
 * When the session carried the plant into a new form, the arc first closes all
 * the way, then the new form blooms in over the old one and its own arc takes
 * over. Under reduced motion it opens already settled. A receipt with no
 * garden at all (the server is catching up) shows a quiet sun instead.
 *
 * @param isFinal whether this step closes the ritual — the button's spoken
 *   hint reads from this.
 */
@Composable
fun GardenRewardStep(
  receipt: RewardReceipt,
  buttonTitle: String,
  onContinue: () -> Unit,
  modifier: Modifier = Modifier,
  isFinal: Boolean = false,
) {
  val reduceMotion = rememberReduceMotion()
  val settled = receipt.gardenAfter ?: receipt.gardenBefore
  val opening = if (reduceMotion) settled else receipt.gardenBefore ?: receipt.gardenAfter

  var frame by remember(receipt) {
    mutableStateOf(opening?.let { HaloFrame(it, it.evolutionProgress.toFloat()) })
  }
  val sunlight = remember(receipt) { Animatable((opening?.sunlight ?: 0).toFloat()) }
  var hasArrived by remember(receipt) { mutableStateOf(false) }
  var announced by remember(receipt) { mutableStateOf(false) }

  LaunchedEffect(receipt) {
    hasArrived = true
    if (!reduceMotion) {
      delay(ENTRANCE_HOLD_MILLIS)
      val before = receipt.gardenBefore
      val after = receipt.gardenAfter
      if (receipt.sunlightAwarded > 0 && before != null && after != null) {
        launch {
          if (before.stageIndex != after.stageIndex) {
            // Close the old form's ring as the count lands, then let the new
            // form bloom in on its own arc.
            frame = HaloFrame(before, 1f)
            sunlight.animateTo(after.sunlight.toFloat(), exhale())
            frame = HaloFrame(after, after.evolutionProgress.toFloat())
          } else {
            frame = HaloFrame(after, after.evolutionProgress.toFloat())
            sunlight.animateTo(after.sunlight.toFloat(), exhale())
          }
        }
      } else {
        frame = settled?.let { HaloFrame(it, it.evolutionProgress.toFloat()) }
        sunlight.snapTo((settled?.sunlight ?: 0).toFloat())
      }
    }
    announced = true
  }

  val title = stringResource(
    when {
      receipt.gardenIsCatchingUp -> R.string.reward_garden_title_catching_up
      receipt.sunlightAwarded > 0 -> R.string.reward_garden_title_grew
      else -> R.string.reward_garden_title_resting
    },
  )
  val summary = gardenSummary(receipt)

  RewardStepLayout(
    eyebrow = stringResource(R.string.reward_garden_eyebrow),
    title = title,
    buttonTitle = buttonTitle,
    isFinal = isFinal,
    hasArrived = hasArrived,
    onContinue = onContinue,
    modifier = modifier,
  ) {
    Column(
      Modifier
        .rewardCard(tint = Color.sage)
        .rewardSummary(summary, announced),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.spacedBy(CARD_SPACING),
    ) {
      val current = frame
      if (current != null) {
        GrowthHalo(current)
        GrowthCopy(receipt = receipt, growth = current.growth, sunlight = sunlight.value.roundToInt())
      } else {
        CatchingUp()
      }
    }
  }
}

/**
 * The plant's portrait in its halo. A new form blooms in over the old one
 * (opacity and a 0.94 scale on [bloom]); the same form simply lets its arc
 * ease round.
 */
@Composable
private fun GrowthHalo(frame: HaloFrame) {
  AnimatedContent(
    targetState = frame,
    contentKey = { it.growth.stage.id },
    transitionSpec = {
      (fadeIn(bloom()) + scaleIn(bloom(), initialScale = SWAP_SCALE))
        .togetherWith(fadeOut(bloom()) + scaleOut(bloom(), targetScale = SWAP_SCALE))
    },
    contentAlignment = Alignment.Center,
    label = "reward-halo",
  ) { shown ->
    val stage = shown.growth.stage
    PlantGrowthHalo(
      progress = shown.progress,
      portraitUrl = stage.mascotUrl ?: stage.mascotBgUrl,
      fallbackUrl = shown.growth.plant.imageUrl,
      palette = shown.growth.plant.palette,
      portraitDiameter = PORTRAIT,
      ringGap = RING_GAP,
      ringWidth = RING_WIDTH,
    )
  }
}

/**
 * The form's name, what this session gave, and the count toward the next
 * form. The gold is the sunlight's own; a day already full says so in grey.
 */
@Composable
private fun GrowthCopy(receipt: RewardReceipt, growth: GardenGrowth, sunlight: Int) {
  val awarded = receipt.sunlightAwarded > 0
  val next = growth.nextStage
  val goal = growth.sunlightToEvolve
  val progressLine = if (next != null && goal != null) {
    stringResource(R.string.reward_garden_progress, formatFigure(sunlight), formatFigure(goal), next.name)
  } else {
    stringResource(R.string.reward_garden_progress_fully_grown, formatFigure(sunlight))
  }

  Column(
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(COPY_SPACING),
  ) {
    Crossfade(targetState = growth.stage.name, animationSpec = bloom(), label = "reward-stage-name") { name ->
      Text(name, style = DeepType.displayTitle, color = Color.deepPlum, textAlign = TextAlign.Center)
    }
    Text(
      if (awarded) {
        stringResource(R.string.reward_garden_sunlight_awarded, receipt.sunlightAwarded)
      } else {
        stringResource(R.string.reward_today_full)
      },
      style = REWARD_LINE_STYLE,
      color = if (awarded) Color.sunbeam else Color.driftGrey,
      textAlign = TextAlign.Center,
    )
    Text(progressLine, style = PROGRESS_STYLE, color = Color.driftGrey, textAlign = TextAlign.Center)
  }
}

/** No garden on the receipt yet: a quiet sun, and the reassurance that nothing was lost. */
@Composable
private fun CatchingUp() {
  Box(Modifier.size(CATCHING_UP_SIZE), contentAlignment = Alignment.Center) {
    Canvas(Modifier.fillMaxSize()) {
      val ring = CATCHING_UP_RING.toPx()
      drawCircle(
        color = Color.meadow.copy(alpha = CATCHING_UP_RING_ALPHA),
        radius = size.minDimension / 2f - ring / 2f,
        style = Stroke(width = ring),
      )
    }
    Box(
      Modifier
        .fillMaxSize()
        .padding(CATCHING_UP_SEAT_INSET)
        .background(Color.White.copy(alpha = SEAT_ALPHA), CircleShape),
    )
    Icon(
      imageVector = DeepIcons.SunFill,
      contentDescription = null,
      tint = Color.sunbeam,
      modifier = Modifier.size(CATCHING_UP_SUN),
    )
  }
  Column(
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(COPY_SPACING),
  ) {
    Text(
      stringResource(R.string.reward_garden_catching_up_title),
      style = DeepType.displayTitle,
      color = Color.deepPlum,
      textAlign = TextAlign.Center,
    )
    Text(
      stringResource(R.string.reward_garden_catching_up_body),
      style = DeepType.caption,
      color = Color.driftGrey,
      textAlign = TextAlign.Center,
    )
  }
}

/** The card in one sentence — always the settled truth, never a mid-count figure. */
@Composable
private fun gardenSummary(receipt: RewardReceipt): String {
  val growth = receipt.gardenAfter ?: return stringResource(R.string.reward_garden_summary_catching_up)
  return if (receipt.sunlightAwarded > 0) {
    stringResource(R.string.reward_garden_summary_awarded, growth.stage.name, receipt.sunlightAwarded)
  } else {
    stringResource(R.string.reward_garden_summary_full, growth.stage.name)
  }
}

// MARK: - Previews

@Composable
private fun GardenStepPreview(receipt: RewardReceipt) {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      GardenRewardStep(receipt = receipt, buttonTitle = "Continue", onContinue = {})
    }
  }
}

@Preview(showBackground = true, name = "Garden reward")
@Composable
private fun GardenRewardPreview() {
  GardenStepPreview(RewardReceipt.sample)
}

@Preview(showBackground = true, name = "Garden reward — evolution")
@Composable
private fun GardenRewardEvolvingPreview() {
  GardenStepPreview(RewardReceipt.evolving)
}

@Preview(showBackground = true, name = "Garden reward — capped")
@Composable
private fun GardenRewardCappedPreview() {
  GardenStepPreview(RewardReceipt.capped)
}

@Preview(showBackground = true, name = "Garden reward — catching up")
@Composable
private fun GardenRewardCatchingUpPreview() {
  GardenStepPreview(RewardReceipt.catchingUp)
}

@Preview(showBackground = true, name = "Garden reward — large type", fontScale = 1.6f)
@Composable
private fun GardenRewardLargeTypePreview() {
  GardenStepPreview(RewardReceipt.sample)
}

@Preview(showBackground = true, name = "Garden reward — pause night")
@Composable
private fun GardenRewardPauseNightPreview() {
  GardenStepPreview(RewardReceipt.pauseNight)
}
