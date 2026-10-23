package io.appbeyond.freelance.deep.feature.rewards.screens

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.appshell.DeepIcons
import io.appbeyond.freelance.deep.feature.rewards.model.RewardReceipt
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.ENTRANCE_HOLD_MILLIS
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.duskRose
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.ripple
import io.appbeyond.freelance.deep.theme.softLilac
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

// MARK: - Constants

/** Artwork to copy — iOS's `VStack(spacing: 20)`; the copy's own `spacing: 7`. */
private val CARD_SPACING = 20.dp
private val COPY_SPACING = 7.dp

/** The sun's frame — iOS's 154pt. */
private val ART_SIZE = 154.dp

/** The ripple ring: lavender at 0.38, 3 wide, set loose from 0.88 to 1.3 as it fades from 0.7. */
private const val RIPPLE_ALPHA = 0.38f
private val RIPPLE_WIDTH = 3.dp
private const val RIPPLE_REST_SCALE = 0.88f
private const val RIPPLE_RELEASED_SCALE = 1.3f
private const val RIPPLE_REST_OPACITY = 0.7f

/** The white seat the sun rests on, 14 inside the frame, with its hairline rim. */
private val SEAT_INSET = 14.dp
private const val SEAT_ALPHA = 0.62f
private const val SEAT_RIM_ALPHA = 0.5f
private val SEAT_RIM_WIDTH = 0.5.dp

/** iOS's 48pt light `sun.max.fill` in duskRose at 0.82, measured to its box. */
private val SUN_SIZE = 52.dp
private const val SUN_ALPHA = 0.82f

private val COUNT_STYLE = DeepType.bigNumber.copy(fontFeatureSettings = "tnum")

// MARK: - Step

/**
 * The once-daily closing beat. It celebrates returning without introducing a
 * streak to defend: the count is continuity witnessed, never a warning.
 *
 * Ported from Deep/Deep/Features/Rewards/Screens/ContinuityRewardView.swift.
 * 350ms after the card blooms in, the day count rolls up on the exhale; once it
 * lands, a ring is set loose from the sun and calms outward on the ripple.
 * Under reduced motion the count opens settled and the ring stays at rest.
 * Always the ritual's last step, so its button always closes it.
 *
 * @param headline how the return is named — "You returned today" for a DEEP
 *   Session, "Your rhythm continues" for a Global Pause.
 */
@Composable
fun ContinuityRewardStep(
  receipt: RewardReceipt,
  headline: String,
  buttonTitle: String,
  onFinish: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val reduceMotion = rememberReduceMotion()
  val days = remember(receipt) {
    Animatable((if (reduceMotion) receipt.continuityAfter else receipt.continuityBefore).toFloat())
  }
  var haloReleased by remember(receipt) { mutableStateOf(false) }
  var hasArrived by remember(receipt) { mutableStateOf(false) }
  var announced by remember(receipt) { mutableStateOf(false) }

  LaunchedEffect(receipt) {
    hasArrived = true
    if (!reduceMotion) {
      delay(ENTRANCE_HOLD_MILLIS)
      launch {
        days.animateTo(receipt.continuityAfter.toFloat(), exhale())
        haloReleased = true
      }
    }
    announced = true
  }

  val rippleScale by animateFloatAsState(
    targetValue = if (haloReleased) RIPPLE_RELEASED_SCALE else RIPPLE_REST_SCALE,
    animationSpec = ripple(),
    label = "continuity-ripple-scale",
  )
  val rippleOpacity by animateFloatAsState(
    targetValue = if (haloReleased) 0f else RIPPLE_REST_OPACITY,
    animationSpec = ripple(),
    label = "continuity-ripple-opacity",
  )
  val shownDays = days.value.roundToInt()
  val summary = pluralStringResource(
    R.plurals.reward_continuity_summary,
    receipt.continuityAfter,
    headline,
    receipt.continuityAfter,
  )

  RewardStepLayout(
    eyebrow = stringResource(R.string.reward_continuity_eyebrow),
    title = headline,
    buttonTitle = buttonTitle,
    isFinal = true,
    hasArrived = hasArrived,
    onContinue = onFinish,
    modifier = modifier,
  ) {
    Column(
      Modifier
        .rewardCard(tint = Color.softLilac)
        .rewardSummary(summary, announced),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.spacedBy(CARD_SPACING),
    ) {
      Box(Modifier.size(ART_SIZE), contentAlignment = Alignment.Center) {
        Canvas(
          Modifier
            .fillMaxSize()
            .graphicsLayer {
              scaleX = rippleScale
              scaleY = rippleScale
              alpha = rippleOpacity
            },
        ) {
          val ring = RIPPLE_WIDTH.toPx()
          // iOS strokes a Circle centred on its path, so half the line rides
          // outside the frame.
          drawCircle(
            color = Color.lavenderMist.copy(alpha = RIPPLE_ALPHA),
            radius = size.minDimension / 2f,
            style = Stroke(width = ring),
          )
        }
        Box(
          Modifier
            .fillMaxSize()
            .padding(SEAT_INSET)
            .background(Color.White.copy(alpha = SEAT_ALPHA), CircleShape)
            .border(SEAT_RIM_WIDTH, Color.White.copy(alpha = SEAT_RIM_ALPHA), CircleShape),
        )
        Icon(
          imageVector = DeepIcons.SunFill,
          contentDescription = null,
          tint = Color.duskRose.copy(alpha = SUN_ALPHA),
          modifier = Modifier.size(SUN_SIZE),
        )
      }

      Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(COPY_SPACING),
      ) {
        Text(formatFigure(shownDays), style = COUNT_STYLE, color = Color.deepPlum)
        Text(
          pluralStringResource(R.plurals.reward_continuity_days, shownDays),
          style = DeepType.body,
          color = Color.deepPlum,
          textAlign = TextAlign.Center,
        )
        Text(
          stringResource(R.string.reward_continuity_enough),
          style = DeepType.caption,
          color = Color.driftGrey,
          textAlign = TextAlign.Center,
        )
      }
    }
  }
}

// MARK: - Previews

@Composable
private fun ContinuityStepPreview(receipt: RewardReceipt, headline: String) {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      ContinuityRewardStep(
        receipt = receipt,
        headline = headline,
        buttonTitle = "Carry this calm",
        onFinish = {},
      )
    }
  }
}

@Preview(showBackground = true, name = "Continuity reward")
@Composable
private fun ContinuityRewardPreview() {
  ContinuityStepPreview(
    receipt = RewardReceipt.sample,
    headline = stringResource(R.string.reward_continuity_headline_returned),
  )
}

@Preview(showBackground = true, name = "Continuity reward — pause night")
@Composable
private fun ContinuityRewardPauseNightPreview() {
  ContinuityStepPreview(
    receipt = RewardReceipt.pauseNight,
    headline = stringResource(R.string.reward_continuity_headline_continues),
  )
}

@Preview(showBackground = true, name = "Continuity reward — first day")
@Composable
private fun ContinuityRewardFirstDayPreview() {
  ContinuityStepPreview(
    receipt = RewardReceipt.evolving,
    headline = stringResource(R.string.reward_continuity_headline_returned),
  )
}

@Preview(showBackground = true, name = "Continuity reward — large type", fontScale = 1.6f)
@Composable
private fun ContinuityRewardLargeTypePreview() {
  ContinuityStepPreview(
    receipt = RewardReceipt.sample,
    headline = stringResource(R.string.reward_continuity_headline_returned),
  )
}
