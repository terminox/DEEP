package io.appbeyond.freelance.deep.feature.rewards.screens

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.updateTransition
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.rewards.model.RewardReceipt
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.RewardContinueButton
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.shared.transition.rememberSoftDrift
import io.appbeyond.freelance.deep.shared.transition.softDriftVeil
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext
import java.text.NumberFormat

// MARK: - Constants

/** The card's entrance: from 0.92 scale and 14dp low, to rest. */
private const val ENTRANCE_SCALE = 0.92f
private val ENTRANCE_DROP = 14.dp

/** Eyebrow to headline — iOS's `VStack(spacing: 7)`. */
private val HEADER_SPACING = 7.dp

/** The card's inset — iOS's `.padding(.vertical, 28).padding(.horizontal, 20)`. */
private val CARD_PADDING_VERTICAL = 28.dp
private val CARD_PADDING_HORIZONTAL = 20.dp

// MARK: - Ritual

/** The ritual's beats, in the only order they ever play. */
private enum class RitualStep { Garden, Compassion, Continuity }

/**
 * Conducts the rewarding end of a finished practice. The sequence only moves
 * forward: garden, compassion, then the once-daily continuity beat (when
 * [RewardReceipt.showsContinuity]) — shared by every ending, with only the
 * closing words changing between them. The last step's button reads "Carry
 * this calm"; every other reads "Continue".
 *
 * Ported from Deep/Deep/Features/Rewards/Screens/RewardRitualView.swift. Steps
 * hand off on the soft drift (its [io.appbeyond.freelance.deep.theme.hush]
 * tempo), and a tap while one is still handing off is ignored, as iOS's
 * `isTransitioning` guard does — read straight off the transition here rather
 * than kept in a flag.
 *
 * The day's one witnessing is spent as the continuity step is shown rather than
 * when the receipt was composed, so an ending the member walks away from leaves
 * the beat waiting for their next practice. It runs to completion even if the
 * ritual leaves mid-write.
 *
 * Back: iOS has no back gesture here. On Android, back closes the ritual — the
 * same [onFinish] the closing button calls, never a step backward (the sequence
 * has no "previous") and never a skip to the next beat (a member pressing back
 * wants out, not more). The rewards were banked before the ritual began, so
 * leaving early loses nothing; an unreached continuity beat stays unspent.
 *
 * @param continuityHeadline how the continuity beat names the return — a DEEP
 *   Session credits today ("You returned today"); a Global Pause, which adds no
 *   practice day, witnesses the run ("Your rhythm continues"). See the
 *   `reward_continuity_headline_*` strings.
 * @param onWitnessContinuity stamps today's continuity — `ContinuityWitness.witnessToday`.
 * @param onFinish the member closed the ritual. Called once.
 * @param paintsBackground whether the ritual paints its own atmosphere. False
 *   when an owner spans a longer ending and already holds one — two
 *   independently drifting atmospheres crossfading against each other visibly
 *   slide.
 */
@Composable
fun RewardRitualScreen(
  receipt: RewardReceipt,
  continuityHeadline: String,
  onWitnessContinuity: suspend () -> Unit,
  onFinish: () -> Unit,
  modifier: Modifier = Modifier,
  paintsBackground: Boolean = true,
) {
  var step by rememberSaveable { mutableStateOf(RitualStep.Garden) }
  var finished by remember { mutableStateOf(false) }
  val transition = updateTransition(targetState = step, label = "reward-ritual")
  val drift = rememberSoftDrift()
  val witness by rememberUpdatedState(onWitnessContinuity)
  val finalTitle = stringResource(R.string.reward_carry_this_calm)
  val continueTitle = stringResource(R.string.reward_continue)

  LaunchedEffect(step) {
    if (step == RitualStep.Continuity) withContext(NonCancellable) { witness() }
  }

  fun isTransitioning() = transition.currentState != transition.targetState

  fun move(to: RitualStep) {
    if (isTransitioning() || finished) return
    step = to
  }

  fun finish() {
    if (finished) return
    finished = true
    onFinish()
  }

  BackHandler(enabled = !finished) { finish() }

  Box(
    modifier
      .fillMaxSize()
      .then(if (paintsBackground) Modifier.background(Color.moonCream) else Modifier),
  ) {
    if (paintsBackground) AtmosphereBackground()

    transition.AnimatedContent(
      transitionSpec = { drift.transform() },
      modifier = Modifier.fillMaxSize(),
    ) { current ->
      val veiled = Modifier.softDriftVeil(this)
      when (current) {
        RitualStep.Garden -> GardenRewardStep(
          receipt = receipt,
          buttonTitle = continueTitle,
          onContinue = { move(RitualStep.Compassion) },
          modifier = veiled,
        )

        RitualStep.Compassion -> if (receipt.showsContinuity) {
          CompassionRewardStep(
            receipt = receipt,
            buttonTitle = continueTitle,
            onContinue = { move(RitualStep.Continuity) },
            modifier = veiled,
          )
        } else {
          CompassionRewardStep(
            receipt = receipt,
            buttonTitle = finalTitle,
            isFinal = true,
            onContinue = { if (!isTransitioning()) finish() },
            modifier = veiled,
          )
        }

        RitualStep.Continuity -> ContinuityRewardStep(
          receipt = receipt,
          headline = continuityHeadline,
          buttonTitle = finalTitle,
          onFinish = { if (!isTransitioning()) finish() },
          modifier = veiled,
        )
      }
    }
  }
}

// MARK: - Shared step layout

/**
 * Every step's frame: a tracked micro eyebrow over one serif headline, the
 * step's card centred in the space above the button, and the one forward
 * button standing in the bottom inset. The card blooms in — opacity 0 → 1,
 * scale 0.92 → 1, 14dp low → at rest — once [hasArrived] flips; under reduced
 * motion it only fades.
 *
 * The column is at least the viewport tall and centres its content, so a short
 * card sits mid-screen and a tall one (large type) scrolls — iOS's
 * `containerRelativeFrame(.vertical, alignment: .center)` inside a ScrollView.
 */
@Composable
internal fun RewardStepLayout(
  eyebrow: String,
  title: String,
  buttonTitle: String,
  isFinal: Boolean,
  hasArrived: Boolean,
  onContinue: () -> Unit,
  modifier: Modifier = Modifier,
  card: @Composable () -> Unit,
) {
  val reduceMotion = rememberReduceMotion()
  val density = LocalDensity.current
  val rested = hasArrived || reduceMotion
  val opacity by animateFloatAsState(if (hasArrived) 1f else 0f, bloom(), label = "reward-card-opacity")
  val scale by animateFloatAsState(if (rested) 1f else ENTRANCE_SCALE, bloom(), label = "reward-card-scale")
  val drop by animateFloatAsState(
    targetValue = if (rested) 0f else with(density) { ENTRANCE_DROP.toPx() },
    animationSpec = bloom(),
    label = "reward-card-drop",
  )

  Column(modifier.fillMaxSize()) {
    BoxWithConstraints(
      Modifier
        .weight(1f)
        .fillMaxWidth(),
    ) {
      val viewport = maxHeight
      Column(
        Modifier
          .fillMaxSize()
          .verticalScroll(rememberScrollState()),
      ) {
        Column(
          Modifier
            .fillMaxWidth()
            .heightIn(min = viewport)
            .statusBarsPadding()
            .padding(horizontal = Dp.edge, vertical = Dp.rhythm),
          horizontalAlignment = Alignment.CenterHorizontally,
          verticalArrangement = Arrangement.spacedBy(Dp.rhythm * 1.5f, Alignment.CenterVertically),
        ) {
          Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(HEADER_SPACING),
          ) {
            Text(eyebrow, style = DeepType.micro, color = Color.driftGrey)
            Text(
              title,
              style = DeepType.displayTitle,
              color = Color.deepPlum,
              textAlign = TextAlign.Center,
              modifier = Modifier.semantics { heading() },
            )
          }

          Box(
            Modifier.graphicsLayer {
              alpha = opacity
              scaleX = scale
              scaleY = scale
              translationY = drop
            },
          ) {
            card()
          }
        }
      }
    }

    RewardContinueButton(
      title = buttonTitle,
      isFinal = isFinal,
      onClick = onContinue,
      modifier = Modifier
        .navigationBarsPadding()
        .padding(horizontal = Dp.edge)
        .padding(bottom = Dp.rhythm),
    )
  }
}

/**
 * A step's card surface: the frosted card with the step's identity wash, at
 * the reward cards' roomier 28 / 20 inset.
 */
internal fun Modifier.rewardCard(tint: Color): Modifier = this
  .fillMaxWidth()
  .frostedCard(tint = tint)
  .padding(vertical = CARD_PADDING_VERTICAL, horizontal = CARD_PADDING_HORIZONTAL)

/**
 * The card speaks as one sentence, and is announced once its numbers start to
 * move — iOS's `AccessibilityNotification.Announcement` after the entrance.
 * A polite live region whose description fills in at that moment is what makes
 * TalkBack say it unprompted; before then the card is still invisible.
 */
internal fun Modifier.rewardSummary(summary: String, announced: Boolean): Modifier =
  clearAndSetSemantics {
    contentDescription = if (announced) summary else ""
    liveRegion = LiveRegionMode.Polite
  }

/** The app locale's grouped integer — iOS's `.formatted()`. */
internal fun formatFigure(value: Int): String = NumberFormat.getIntegerInstance().format(value)

// MARK: - Previews

@Composable
private fun RitualPreview(
  receipt: RewardReceipt,
  headline: String = stringResource(R.string.reward_continuity_headline_returned),
) {
  DeepTheme {
    RewardRitualScreen(
      receipt = receipt,
      continuityHeadline = headline,
      onWitnessContinuity = {},
      onFinish = {},
    )
  }
}

@Preview(showBackground = true, name = "Reward sequence")
@Composable
private fun RewardRitualPreview() {
  RitualPreview(RewardReceipt.sample)
}

@Preview(showBackground = true, name = "Reward sequence — later today")
@Composable
private fun RewardRitualLaterTodayPreview() {
  RitualPreview(RewardReceipt.laterToday)
}

@Preview(showBackground = true, name = "Reward sequence — capped")
@Composable
private fun RewardRitualCappedPreview() {
  RitualPreview(RewardReceipt.capped)
}

@Preview(showBackground = true, name = "Reward sequence — pause night")
@Composable
private fun RewardRitualPauseNightPreview() {
  RitualPreview(
    receipt = RewardReceipt.pauseNight,
    headline = stringResource(R.string.reward_continuity_headline_continues),
  )
}
