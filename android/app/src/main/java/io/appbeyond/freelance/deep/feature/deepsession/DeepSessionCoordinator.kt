package io.appbeyond.freelance.deep.feature.deepsession

import android.content.Context
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSessionLength
import io.appbeyond.freelance.deep.feature.rewards.model.RewardReceipt
import io.appbeyond.freelance.deep.feature.rewards.screens.RewardRitualScreen
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.hush
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/** The stages of a practice: the threshold, the breath, and what it grew. */
private sealed interface SessionStage {
  data object Threshold : SessionStage
  data object Practice : SessionStage
  data class Completion(val receipt: RewardReceipt) : SessionStage
}

/**
 * Owns one visit to DEEP Session: the threshold, then the practice, then the
 * reward ritual, then out.
 *
 * A coordinator in the project's sense — it holds the stage and the chosen
 * length and wires the three screens together (threshold, practice, reward ritual), and carries no styling of its own.
 *
 * The chime is created here rather than inside [DeepSessionScreen] so it can be
 * warmed before the practice starts and can finish ringing after the practice
 * screen has gone. The bell outliving its screen is the whole reason the iOS
 * version owns it outside the presentation too.
 *
 * Only a practice that runs to its end is recorded — leaving early closes the
 * visit with nothing banked, as iOS's `finishSession` is reached only from
 * `.finished`. The completion is recorded once, through [onComplete], and the
 * ritual it returns replaces the practice on the same `hush` crossfade.
 *
 * @param onComplete records the finished practice and returns what it earned
 *   (`PracticeRewards.complete`). Null — previews — closes on finish instead.
 * @param onWitnessContinuity stamps today's continuity beat as the ritual shows it.
 */
@Composable
fun DeepSessionCoordinator(
  session: DeepSession,
  onFinish: () -> Unit,
  modifier: Modifier = Modifier,
  chime: ChimePlaying? = null,
  onComplete: (suspend (title: String, durationSeconds: Int) -> RewardReceipt)? = null,
  onWitnessContinuity: suspend () -> Unit = {},
) {
  val context = LocalContext.current
  val scope = rememberCoroutineScope()
  var stage by remember { mutableStateOf<SessionStage>(SessionStage.Threshold) }
  var didRecord by remember { mutableStateOf(false) }
  var minutes by remember { mutableStateOf(readMinutes(context)) }

  val resolvedChime = remember(chime) { chime ?: ChimePlayer(context) }
  DisposableEffect(resolvedChime) {
    onDispose { if (chime == null) resolvedChime.release() }
  }

  // The threshold's title and tagline are localised here, at the UI edge —
  // the model type in :core:model deliberately knows nothing about resources.
  val titled = session.copy(
    title = stringResource(R.string.home_session_card_title),
    tagline = stringResource(R.string.home_session_card_body),
  )

  // Back from the threshold leaves, as the iOS threshold's back swipe does.
  // Without it the press fell through to the shell underneath, which quietly
  // switched tabs (or closed the app from Home) while the threshold stayed
  // up with no way out. Registered as the visit opens, so it outranks the
  // shell's handler; the practice screen's own confirm-to-leave handler is
  // composed later still and takes over once the breath begins.
  BackHandler(enabled = stage == SessionStage.Threshold) { onFinish() }

  // The journal names the practice itself, not the card that opened it: iOS
  // records `DeepSessionLibrary.balancingBreath`'s title, and a member's pulled
  // history mixes both platforms' rows. One practice ships, so it is named here.
  val journalTitle = stringResource(R.string.deepsound_balancing_breath_title)

  AnimatedContent(
    targetState = stage,
    transitionSpec = { fadeIn(hush()) togetherWith fadeOut(hush()) },
    label = "session-stage",
    modifier = modifier,
  ) { current ->
    when (current) {
      SessionStage.Threshold -> DeepSessionIntroScreen(
        session = titled,
        minutes = minutes,
        onMinutesChange = {
          minutes = it
          writeMinutes(context, it)
        },
        onBegin = { stage = SessionStage.Practice },
      )

      SessionStage.Practice -> {
        val practice = titled.lasting(minutes)
        DeepSessionScreen(
          session = practice,
          onFinished = {
            val record = onComplete
            if (record == null) {
              onFinish()
            } else if (!didRecord) {
              didRecord = true
              scope.launch {
                val seconds = (practice.duration.inWholeMilliseconds / 1000.0).roundToInt()
                stage = SessionStage.Completion(record(journalTitle, seconds))
              }
            }
          },
          onLeave = onFinish,
          chime = resolvedChime,
        )
      }

      is SessionStage.Completion -> RewardRitualScreen(
        receipt = current.receipt,
        continuityHeadline = stringResource(R.string.reward_continuity_headline_returned),
        onWitnessContinuity = onWitnessContinuity,
        onFinish = onFinish,
      )
    }
  }
}

/*
 * The chosen length persists across visits — every visit after the first opens
 * on whatever was last chosen. One integer, so it stays in SharedPreferences
 * rather than earning a DataStore; the key matches the iOS @AppStorage key so
 * the two platforms describe the same setting.
 */

private const val PREFS = "deep.session"
private const val KEY_MINUTES = "deep.session.minutes"

private fun readMinutes(context: Context): Int =
  context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    .getInt(KEY_MINUTES, DeepSessionLength.opening)
    .coerceIn(DeepSessionLength.range)

private fun writeMinutes(context: Context, minutes: Int) {
  context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    .edit()
    .putInt(KEY_MINUTES, minutes)
    .apply()
}

@Preview(showBackground = true)
@Composable
private fun DeepSessionCoordinatorPreview() {
  DeepTheme {
    DeepSessionCoordinator(
      session = DeepSession(id = "preview", title = "", tagline = "", cycles = 6),
      onFinish = {},
      chime = SilentChime(),
    )
  }
}
