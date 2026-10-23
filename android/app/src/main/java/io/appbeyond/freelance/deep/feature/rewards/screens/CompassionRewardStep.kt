package io.appbeyond.freelance.deep.feature.rewards.screens

import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.GenericShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.compassion.store.HeartLedger
import io.appbeyond.freelance.deep.feature.rewards.model.RewardReceipt
import io.appbeyond.freelance.deep.shared.components.ArtworkImage
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.CompassionRing
import io.appbeyond.freelance.deep.shared.components.HeartBurst
import io.appbeyond.freelance.deep.shared.components.RingSegment
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.ENTRANCE_HOLD_MILLIS
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.duskRose
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

// MARK: - Constants

private val CARD_SPACING = 18.dp
private val COPY_SPACING = 7.dp

/** Today's ring — iOS's 154pt frame, 6 stroke — with the motif seated 17 inside it. */
private val RING_SIZE = 154.dp
private val RING_WIDTH = 6.dp
private val MOTIF_INSET = 17.dp

/** The motif's heart: 0.38 of the motif's 120dp edge, white at 0.92. */
private val HEART_SIZE = DpSize(46.dp, 43.dp)
private const val HEART_ALPHA = 0.92f

/** The plum seat under the heart — iOS's `shadow(deepPlum 0.18, radius: 8, y: 3)`. */
private const val HEART_SEAT_ALPHA = 0.18f
private val HEART_SEAT_RADIUS = 8.dp
private val HEART_SEAT_OFFSET_Y = 3.dp

/** The motif's artwork palette — iOS's `.dusk`. */
private const val MOTIF_PALETTE = "dusk"

private val FIGURE_BODY_STYLE = DeepType.body.copy(fontFeatureSettings = "tnum")
private val FIGURE_CAPTION_STYLE = DeepType.caption.copy(fontFeatureSettings = "tnum")

/**
 * A filled heart drawn to its box — the same outline [HeartBurst] floats, so
 * the heart at rest and the heart that rises from it are one shape.
 */
private val HeartShape = GenericShape { size, _ ->
  val minX = 3.75f
  val minY = 3.75f
  val sx = size.width / (20.25f - minX)
  val sy = size.height / (20f - minY)
  fun x(v: Float) = (v - minX) * sx
  fun y(v: Float) = (v - minY) * sy
  moveTo(x(12f), y(20f))
  cubicTo(x(12f), y(20f), x(3.75f), y(14.5f), x(3.75f), y(9f))
  cubicTo(x(3.75f), y(6.1f), x(6.1f), y(3.75f), x(9f), y(3.75f))
  cubicTo(x(10.7f), y(3.75f), x(12f), y(4.7f), x(12f), y(6.3f))
  cubicTo(x(12f), y(4.7f), x(13.3f), y(3.75f), x(15f), y(3.75f))
  cubicTo(x(17.9f), y(3.75f), x(20.25f), y(6.1f), x(20.25f), y(9f))
  cubicTo(x(20.25f), y(14.5f), x(12f), y(20f), x(12f), y(20f))
  close()
}

// MARK: - Step

/**
 * The second reward: practice becomes a heart the member can give outward.
 * The portfolio's daily halo is reduced to the earned change and the live
 * balance.
 *
 * Ported from Deep/Deep/Features/Rewards/Screens/CompassionRewardView.swift.
 * 350ms after the card blooms in, the balance and today's tally count up on the
 * exhale and today's ring fills toward the daily ceiling; once they land, a
 * heart rises out of the ring (with a light haptic) when hearts were earned.
 * Under reduced motion the figures open settled and the heart only buzzes.
 *
 * @param isFinal whether this step closes the ritual — the button's spoken
 *   hint reads from this.
 */
@Composable
fun CompassionRewardStep(
  receipt: RewardReceipt,
  buttonTitle: String,
  onContinue: () -> Unit,
  modifier: Modifier = Modifier,
  isFinal: Boolean = false,
) {
  val reduceMotion = rememberReduceMotion()
  val balance = remember(receipt) {
    Animatable((if (reduceMotion) receipt.heartBalanceAfter else receipt.heartBalanceBefore).toFloat())
  }
  val today = remember(receipt) {
    Animatable((if (reduceMotion) receipt.heartsEarnedTodayAfter else receipt.heartsEarnedTodayBefore).toFloat())
  }
  // The ring eases on its own; it is handed the target, not the running count.
  var ringToday by remember(receipt) {
    mutableIntStateOf(if (reduceMotion) receipt.heartsEarnedTodayAfter else receipt.heartsEarnedTodayBefore)
  }
  var flourish by remember(receipt) { mutableIntStateOf(0) }
  var hasArrived by remember(receipt) { mutableStateOf(false) }
  var announced by remember(receipt) { mutableStateOf(false) }

  LaunchedEffect(receipt) {
    hasArrived = true
    if (reduceMotion) {
      if (receipt.heartsAwarded > 0) flourish += 1
    } else {
      delay(ENTRANCE_HOLD_MILLIS)
      ringToday = receipt.heartsEarnedTodayAfter
      launch {
        coroutineScope {
          launch { balance.animateTo(receipt.heartBalanceAfter.toFloat(), exhale()) }
          launch { today.animateTo(receipt.heartsEarnedTodayAfter.toFloat(), exhale()) }
        }
        if (receipt.heartsAwarded > 0) flourish += 1
      }
    }
    announced = true
  }

  val awarded = receipt.heartsAwarded > 0
  val shownBalance = balance.value.roundToInt()
  val shownToday = today.value.roundToInt()
  val summary = compassionSummary(receipt)

  RewardStepLayout(
    eyebrow = stringResource(R.string.reward_compassion_eyebrow),
    title = stringResource(
      if (awarded) R.string.reward_compassion_title_carried else R.string.reward_compassion_title_full,
    ),
    buttonTitle = buttonTitle,
    isFinal = isFinal,
    hasArrived = hasArrived,
    onContinue = onContinue,
    modifier = modifier,
  ) {
    Column(
      Modifier
        .rewardCard(tint = Color.blushPowder)
        .rewardSummary(summary, announced),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.spacedBy(CARD_SPACING),
    ) {
      HeartBurst(trigger = flourish) {
        CompassionRing(
          segments = listOf(
            RingSegment(
              share = ringToday.toFloat() / HeartLedger.dailyEarnCeiling,
              colors = listOf(Color.lavenderMist, Color.blushPowder),
            ),
          ),
          lineWidth = RING_WIDTH,
          gap = 0f,
          modifier = Modifier.size(RING_SIZE),
        ) {
          HeartMotif(Modifier.padding(MOTIF_INSET))
        }
      }

      Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(COPY_SPACING),
      ) {
        Text(
          if (awarded) {
            pluralStringResource(R.plurals.reward_compassion_awarded, receipt.heartsAwarded, receipt.heartsAwarded)
          } else {
            stringResource(R.string.reward_today_full)
          },
          style = DeepType.displayTitle,
          color = if (awarded) Color.duskRose else Color.deepPlum,
          textAlign = TextAlign.Center,
        )
        Text(
          pluralStringResource(R.plurals.reward_compassion_balance, shownBalance, formatFigure(shownBalance)),
          style = FIGURE_BODY_STYLE,
          color = Color.deepPlum,
          textAlign = TextAlign.Center,
        )
        Text(
          stringResource(R.string.reward_compassion_today, formatFigure(shownToday), HeartLedger.dailyEarnCeiling),
          style = FIGURE_CAPTION_STYLE,
          color = Color.driftGrey,
          textAlign = TextAlign.Center,
        )
      }
    }
  }
}

/**
 * iOS's `CompassionMotif` with `heart.fill` on the dusk palette, as a disc: the
 * palette's gradient with a white heart seated on a soft plum shadow.
 */
@Composable
private fun HeartMotif(modifier: Modifier = Modifier) {
  Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
    ArtworkImage(
      url = null,
      palette = MOTIF_PALETTE,
      modifier = Modifier
        .fillMaxSize()
        .clip(CircleShape),
    )
    Box(
      Modifier
        .size(HEART_SIZE)
        .dropShadow(
          shape = HeartShape,
          shadow = Shadow(
            radius = HEART_SEAT_RADIUS,
            color = Color.deepPlum.copy(alpha = HEART_SEAT_ALPHA),
            offset = DpOffset(0.dp, HEART_SEAT_OFFSET_Y),
          ),
        )
        .background(Color.White.copy(alpha = HEART_ALPHA), HeartShape),
    )
  }
}

/** The card in one sentence — the settled truth, never a mid-count figure. */
@Composable
private fun compassionSummary(receipt: RewardReceipt): String {
  val balance = pluralStringResource(
    R.plurals.reward_compassion_balance,
    receipt.heartBalanceAfter,
    formatFigure(receipt.heartBalanceAfter),
  )
  return if (receipt.heartsAwarded > 0) {
    val received = pluralStringResource(
      R.plurals.reward_compassion_received,
      receipt.heartsAwarded,
      receipt.heartsAwarded,
    )
    stringResource(R.string.reward_compassion_summary_awarded, received, balance)
  } else {
    stringResource(R.string.reward_compassion_summary_full, balance)
  }
}

// MARK: - Previews

@Composable
private fun CompassionStepPreview(receipt: RewardReceipt, buttonTitle: String, isFinal: Boolean = false) {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      CompassionRewardStep(receipt = receipt, buttonTitle = buttonTitle, isFinal = isFinal, onContinue = {})
    }
  }
}

@Preview(showBackground = true, name = "Compassion reward")
@Composable
private fun CompassionRewardPreview() {
  CompassionStepPreview(RewardReceipt.sample, buttonTitle = "Continue")
}

@Preview(showBackground = true, name = "Compassion reward — final")
@Composable
private fun CompassionRewardFinalPreview() {
  CompassionStepPreview(RewardReceipt.laterToday, buttonTitle = "Carry this calm", isFinal = true)
}

@Preview(showBackground = true, name = "Compassion reward — capped")
@Composable
private fun CompassionRewardCappedPreview() {
  CompassionStepPreview(RewardReceipt.capped, buttonTitle = "Carry this calm", isFinal = true)
}

@Preview(showBackground = true, name = "Compassion reward — pause night")
@Composable
private fun CompassionRewardPauseNightPreview() {
  CompassionStepPreview(RewardReceipt.pauseNight, buttonTitle = "Continue")
}
