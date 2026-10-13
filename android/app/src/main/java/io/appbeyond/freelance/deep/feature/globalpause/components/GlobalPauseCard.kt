package io.appbeyond.freelance.deep.feature.globalpause.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.globalpause.globe.GlobeMode
import io.appbeyond.freelance.deep.feature.globalpause.globe.GlobeScene
import io.appbeyond.freelance.deep.feature.globalpause.globe.LocalGlobeRendering
import io.appbeyond.freelance.deep.feature.globalpause.model.GlobalPauseCardState
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseScheduleLine
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.nightVeil
import io.appbeyond.freelance.deep.theme.softPress
import kotlinx.coroutines.delay
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import kotlin.math.roundToInt

/**
 * The Global Pause card in Fuku's Lounge: the night sky, the globe cresting
 * its bottom-right corner, and the chrome that says when the world pauses
 * next. Three faces ([GlobalPauseCardState]): the schedule line alone; in the
 * final fifteen minutes a grey pill ticking "Live in 13:44"; live, "The world
 * is pausing", a LIVE badge and the "Join now" pill. Only the live card opens
 * the session — the rest of the time its caption already carries the answer.
 *
 * Ported from iOS's `GlobalPauseCardView` + `GlobalPauseCardChromeView`. The
 * globe and sky come through [LocalGlobeRendering], and the whole surface
 * through the card lift's `cardLiftSource` the caller applies — week 7 lifts
 * exactly this.
 *
 * @param now the synced clock — the countdown must tick on server time, which
 *   dev time travel moves arbitrarily far from the wall clock.
 * @param zone the zone the schedule line is read in: the member's own.
 */
@Composable
fun GlobalPauseCard(
  state: GlobalPauseCardState,
  scene: GlobeScene,
  now: () -> Instant,
  onJoin: () -> Unit,
  modifier: Modifier = Modifier,
  zone: ZoneId = ZoneId.systemDefault(),
) {
  val rendering = LocalGlobeRendering.current
  val isLive = state == GlobalPauseCardState.Live
  val caption = captionFor(state, now, zone)
  val title = stringResource(R.string.pause_card_title)
  val joinLabel = stringResource(R.string.pause_card_join)
  val spoken = stringResource(R.string.pause_card_a11y, title, caption)

  Box(
    modifier
      .fillMaxWidth()
      .height(CARD_HEIGHT)
      .then(if (isLive) Modifier.softPress() else Modifier)
      .clip(RoundedCornerShape(Dp.card))
      .clickable(
        enabled = isLive,
        interactionSource = remember { MutableInteractionSource() },
        indication = null,
        onClick = onJoin,
      )
      .clearAndSetSemantics {
        contentDescription = spoken
        if (isLive) {
          role = Role.Button
          onClick(label = joinLabel) { onJoin(); true }
        }
      },
  ) {
    rendering.NightSky(Modifier.fillMaxSize())
    rendering.Globe(scene, GlobeMode.Card, Modifier.cardGlobeSeat())

    // The night scrim, centre to foot: deepens the sky under the text rather
    // than hazing it the way a plum wash would.
    Box(
      Modifier
        .fillMaxSize()
        .background(
          Brush.verticalGradient(
            0.5f to Color.nightVeil.copy(alpha = 0f),
            1f to Color.nightVeil.copy(alpha = SCRIM_ALPHA),
          ),
        ),
    )

    AnimatedVisibility(
      visible = isLive,
      enter = fadeIn(exhale()),
      exit = fadeOut(exhale()),
      modifier = Modifier
        .align(Alignment.TopStart)
        .padding(CHROME_INSET),
    ) {
      LiveBadge()
    }

    Column(
      Modifier
        .align(Alignment.BottomStart)
        .padding(CHROME_INSET),
    ) {
      Text(title, style = DeepType.displayTitle, color = Color.moonCream)
      Spacer(Modifier.height(4.dp))
      AnimatedContent(
        targetState = caption,
        transitionSpec = { fadeIn(exhale()) togetherWith fadeOut(exhale()) },
        label = "card-caption",
      ) { text ->
        // moonCream, not driftGrey — the caption sits on the night sky.
        Text(text, style = DeepType.caption, color = Color.moonCream.copy(alpha = 0.75f))
      }
      AnimatedVisibility(
        visible = state is GlobalPauseCardState.Countdown,
        enter = fadeIn(exhale()) + expandVertically(exhale()),
        exit = fadeOut(exhale()) + shrinkVertically(exhale()),
      ) {
        val target = (state as? GlobalPauseCardState.Countdown)?.target
        CountdownPill(target = target, now = now, modifier = Modifier.padding(top = 10.dp))
      }
      AnimatedVisibility(
        visible = isLive,
        enter = fadeIn(exhale()) + expandVertically(exhale()),
        exit = fadeOut(exhale()) + shrinkVertically(exhale()),
      ) {
        JoinPill(label = joinLabel, modifier = Modifier.padding(top = 10.dp))
      }
    }
  }
}

/** The card's caption for [state], in the member's language and clock. */
@Composable
private fun captionFor(state: GlobalPauseCardState, now: () -> Instant, zone: ZoneId): String {
  val next = when (state) {
    is GlobalPauseCardState.Off -> state.next
    is GlobalPauseCardState.Countdown -> state.target
    GlobalPauseCardState.Live -> return stringResource(R.string.pause_card_live_caption)
  } ?: return stringResource(R.string.pause_card_resting)
  val line = PauseScheduleLine.of(next, now(), zone)
  val locale = LocalConfiguration.current.locales[0]
  val time = DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT).withLocale(locale).format(line.time)
  return stringResource(
    when (line.day) {
      PauseScheduleLine.Day.Today -> R.string.pause_schedule_today
      PauseScheduleLine.Day.Tomorrow -> R.string.pause_schedule_tomorrow
    },
    time,
  )
}

/**
 * The grey sibling of "Join now": same geometry, a resting colour, ticking
 * "Live in MM:SS". Every tick re-derives from `target − now`, so time away
 * accumulates no drift. Rounding up shows "15:00" on entry and holds "00:01"
 * through the last second; at zero it clamps until the session flips live.
 */
@Composable
private fun CountdownPill(target: Instant?, now: () -> Instant, modifier: Modifier = Modifier) {
  var remaining by remember { mutableLongStateOf(0L) }
  LaunchedEffect(target) {
    while (target != null) {
      val millis = Duration.between(now(), target).toMillis().coerceAtLeast(0L)
      remaining = (millis / 1000.0).let { kotlin.math.ceil(it) }.roundToInt().toLong()
      delay(TICK_MILLIS)
    }
  }
  val minutes = remaining / 60
  val seconds = remaining % 60
  Box(
    modifier
      .clip(RoundedCornerShape(Dp.chip))
      .background(Color.driftGrey)
      .padding(horizontal = 22.dp, vertical = 11.dp),
  ) {
    Text(
      stringResource(R.string.pause_card_countdown, minutes.toInt(), seconds.toInt()),
      style = DeepType.countdown,
      color = Color.White,
    )
  }
}

/** A styled label, not a button: the whole card is the tap target. */
@Composable
private fun JoinPill(label: String, modifier: Modifier = Modifier) {
  Box(
    modifier
      .clip(RoundedCornerShape(Dp.chip))
      .background(Brush.horizontalGradient(listOf(Color.lavenderMist, Color.blushPowder)))
      .padding(horizontal = 22.dp, vertical = 11.dp),
  ) {
    // deepPlum, not white — white on the pastel gradient vanishes.
    Text(label, style = DeepType.bodyMedium, color = Color.deepPlum)
  }
}

/**
 * The globe's corner seat: larger than the card can show, its centre inset a
 * quarter-radius from the bottom-right corner, so the orb crests the corner
 * instead of sitting centred. iOS's `CardGlobeSeat` (radius 0.70 × the card's
 * height). The renderer fills the square it is given; the card clips it.
 */
private fun Modifier.cardGlobeSeat(): Modifier = layout { measurable, constraints ->
  val width = constraints.maxWidth
  val height = constraints.maxHeight
  val radius = ORB_RADIUS_OF_HEIGHT * height
  val side = (radius * 2f / ORB_FILL_OF_SIDE).roundToInt()
  val inset = CORNER_INSET_RADII * radius
  val centreX = width - inset
  val centreY = height - inset
  val placeable = measurable.measure(Constraints.fixed(side, side))
  layout(width, height) {
    placeable.place((centreX - side / 2f).roundToInt(), (centreY - side / 2f).roundToInt())
  }
}

private val CARD_HEIGHT = 200.dp
private val CHROME_INSET = 24.dp
private const val SCRIM_ALPHA = 0.75f
private const val TICK_MILLIS = 1_000L
private const val ORB_RADIUS_OF_HEIGHT = 0.70f
private const val CORNER_INSET_RADII = 0.25f

/** The share of its square a renderer's orb fills — the placeholder's [ORB_FILL]. */
private const val ORB_FILL_OF_SIDE = 0.92f

@Preview(showBackground = true, name = "Card — off")
@Composable
private fun GlobalPauseCardOffPreview() {
  DeepTheme {
    GlobalPauseCard(
      state = GlobalPauseCardState.Off(Instant.now().plus(Duration.ofHours(3))),
      scene = remember { GlobeScene() },
      now = { Instant.now() },
      onJoin = {},
      modifier = Modifier.padding(Dp.edge),
    )
  }
}

@Preview(showBackground = true, name = "Card — countdown")
@Composable
private fun GlobalPauseCardCountdownPreview() {
  DeepTheme {
    GlobalPauseCard(
      state = GlobalPauseCardState.Countdown(Instant.now().plusSeconds(899)),
      scene = remember { GlobeScene() },
      now = { Instant.now() },
      onJoin = {},
      modifier = Modifier.padding(Dp.edge),
    )
  }
}

@Preview(showBackground = true, name = "Card — live")
@Composable
private fun GlobalPauseCardLivePreview() {
  DeepTheme {
    GlobalPauseCard(
      state = GlobalPauseCardState.Live,
      scene = remember { GlobeScene() },
      now = { Instant.now() },
      onJoin = {},
      modifier = Modifier.padding(Dp.edge),
    )
  }
}
