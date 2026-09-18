package io.appbeyond.freelance.deep.feature.deepsession

import android.content.Context
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSession
import io.appbeyond.freelance.deep.feature.deepsession.model.DeepSessionLength
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.hush

/** The two stages of a practice. */
private enum class SessionStage { Threshold, Practice }

/**
 * Owns one visit to Deep Session: the threshold, then the practice, then out.
 *
 * A coordinator in the project's sense — it holds the stage and the chosen
 * length and wires the two screens together, and carries no styling of its own.
 *
 * The chime is created here rather than inside [DeepSessionScreen] so it can be
 * warmed before the practice starts and can finish ringing after the practice
 * screen has gone. The bell outliving its screen is the whole reason the iOS
 * version owns it outside the presentation too.
 */
@Composable
fun DeepSessionCoordinator(
  session: DeepSession,
  onFinish: () -> Unit,
  modifier: Modifier = Modifier,
  chime: ChimePlaying? = null,
) {
  val context = LocalContext.current
  var stage by remember { mutableStateOf(SessionStage.Threshold) }
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

      SessionStage.Practice -> DeepSessionScreen(
        session = titled.lasting(minutes),
        onFinished = onFinish,
        onLeave = onFinish,
        chime = resolvedChime,
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
