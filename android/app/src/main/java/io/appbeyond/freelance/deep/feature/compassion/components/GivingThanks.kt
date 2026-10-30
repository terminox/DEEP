package io.appbeyond.freelance.deep.feature.compassion.components

import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.compassion.CompassionCause
import io.appbeyond.freelance.deep.feature.compassion.CompassionIcons
import io.appbeyond.freelance.deep.feature.compassion.rememberCompassionContent
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.ripple
import io.appbeyond.freelance.deep.theme.tile
import kotlinx.coroutines.delay

// MARK: - Constants

/** The cause's motif — iOS's 88pt square. */
private val MOTIF_SIZE = 88.dp

/** The gaps — iOS's `VStack(spacing: 22)`, 8 inside the words, 12 more above "Done". */
private val SPACING = 22.dp
private val WORDS_SPACING = 8.dp
private val DONE_EXTRA_TOP = 12.dp

/** The blush heart beside the count. */
private val HEART_SIZE = 15.dp

/**
 * The halo waits for the words to bloom in, then rings out once — iOS's 0.3s
 * sleep, and a 2pt blush ring scaling 1 → 1.35 as it fades from 0.9.
 */
private const val HALO_HOLD_MILLIS = 300L
private val HALO_STROKE = 2.dp
private const val HALO_END_SCALE = 1.35f
private const val HALO_START_ALPHA = 0.9f

// MARK: - Thanks

/**
 * What the donate sheet becomes once hearts have gone: the cause's own motif
 * with a single halo pulse, the app's thank-you, what was given, and a way
 * out. The member closes it themselves — a thank-you that leaves on a timer
 * reads as a receipt, and this is the one moment in the feature worth
 * staying in.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/GivingThanksView.swift.
 * iOS posts its announcement from the sheet as the thanks blooms in; here the
 * words are a polite live region that fills in as the halo rings out, the
 * reward steps' pattern — TalkBack only speaks a live region whose words
 * change after it has appeared, and the halo's beat is long enough for that.
 *
 * @param amount what was actually given, which may be less than was asked.
 */
@Composable
fun GivingThanks(
  cause: CompassionCause,
  amount: Int,
  onDone: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val reduceMotion = rememberReduceMotion()
  val halo = remember { Animatable(0f) }
  var announced by remember { mutableStateOf(false) }
  var ringing by remember { mutableStateOf(false) }

  LaunchedEffect(Unit) {
    delay(HALO_HOLD_MILLIS)
    announced = true
    if (reduceMotion) return@LaunchedEffect
    ringing = true
    halo.animateTo(1f, ripple())
  }

  val title = stringResource(R.string.donate_thanks_title, cause.name)
  val given = pluralStringResource(R.plurals.donate_amount_hearts, amount, amount)

  Column(
    modifier.fillMaxWidth().padding(horizontal = Dp.edge),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(SPACING),
  ) {
    Box(Modifier.size(MOTIF_SIZE)) {
      CompassionMotif(
        symbol = cause.symbol,
        palette = cause.palette,
        cornerRadius = Dp.tile,
        modifier = Modifier.matchParentSize(),
      )
      // DESIGN.md's halo pulse: one slow ring outward from the motif, once.
      if (ringing) {
        Box(
          Modifier
            .matchParentSize()
            .graphicsLayer {
              val scale = 1f + (HALO_END_SCALE - 1f) * halo.value
              scaleX = scale
              scaleY = scale
              alpha = HALO_START_ALPHA * (1f - halo.value)
            }
            .border(HALO_STROKE, Color.blushPowder, RoundedCornerShape(Dp.tile)),
        )
      }
    }

    Column(
      Modifier.clearAndSetSemantics {
        contentDescription = if (announced) "$title, $given" else ""
        liveRegion = LiveRegionMode.Polite
      },
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.spacedBy(WORDS_SPACING),
    ) {
      Text(title, style = DeepType.displayTitle, color = Color.deepPlum, textAlign = TextAlign.Center)
      Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(CompassionIcons.HeartFill, contentDescription = null, tint = Color.blushPowder, modifier = Modifier.size(HEART_SIZE))
        Text(
          given,
          style = DeepType.caption.copy(fontWeight = FontWeight.Medium, fontFeatureSettings = "tnum"),
          color = Color.driftGrey,
        )
      }
    }

    HeartCapsule(
      title = stringResource(R.string.donate_thanks_done),
      onClick = onDone,
      modifier = Modifier.padding(top = DONE_EXTRA_TOP),
      icon = null,
    )
  }
}

// MARK: - Previews

@Composable
private fun ThanksPreview(causeId: String, amount: Int) {
  DeepTheme {
    val cause = rememberCompassionContent().cause(causeId)!!
    Box(Modifier.fillMaxSize().background(Color.moonCream), contentAlignment = Alignment.Center) {
      AtmosphereBackground(animated = false)
      GivingThanks(cause = cause, amount = amount, onDone = {})
    }
  }
}

@Preview(showBackground = true, name = "Giving thanks", heightDp = 700)
@Composable
private fun GivingThanksPreview() = ThanksPreview("healthcare", 10)

@Preview(showBackground = true, name = "Giving thanks — one heart", heightDp = 700)
@Composable
private fun GivingThanksOneHeartPreview() = ThanksPreview("peace", 1)

@Preview(showBackground = true, name = "Giving thanks — large type", heightDp = 800, fontScale = 1.4f)
@Composable
private fun GivingThanksLargeTypePreview() = ThanksPreview("nature", 100)
