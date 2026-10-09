package io.appbeyond.freelance.deep.shared.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.settle
import io.appbeyond.freelance.deep.theme.softLilac
import io.appbeyond.freelance.deep.theme.softPress

// MARK: - Constants

/** The capsule's floor — iOS's `frame(minHeight: 56)`. */
private val MIN_HEIGHT = 56.dp

/** The bloom beneath the pill — iOS's `shadow(lavenderMist 0.4, radius: 12, y: 6)`. */
private const val BLOOM_ALPHA = 0.4f
private val BLOOM_RADIUS = 12.dp
private val BLOOM_OFFSET_Y = 6.dp

/** The whole button while its work is in flight — iOS's `opacity(isBusy ? 0.72 : 1)`. */
private const val BUSY_ALPHA = 0.72f

/** The white spinner standing in for the label — iOS's regular `ProgressView`. */
private val SPINNER_SIZE = 20.dp
private val SPINNER_STROKE = 2.dp

private val LABEL_STYLE = DeepType.body.copy(fontWeight = FontWeight.SemiBold)

// MARK: - Button

/**
 * The one forward affordance shared by every reward step. Its label changes
 * at the edge of the ritual, while its shape and placement remain familiar.
 *
 * Ported from Deep/Deep/Features/Rewards/Components/RewardContinueButton.swift:
 * a full-width lavenderMist → softLilac capsule at least 56dp tall, white
 * semibold label, lifted on a lavender bloom (`Modifier.dropShadow` — a real
 * coloured blur on every API level). The whole capsule is the hit target and
 * depresses with [softPress].
 *
 * Busy, the label gives way to a white spinner in the same footprint, the
 * button dims to 0.72 and ignores taps — it holds still and says so, rather
 * than looking live and silently eating taps.
 *
 * iOS's accessibility hint becomes the click action's label, which TalkBack
 * reads as "Double tap to …" — the platform's hint.
 *
 * @param isFinal whether this tap closes the ritual rather than advancing it —
 *   the spoken hint reads from this, never from the label.
 * @param isBusy true while the tap's work is still in flight.
 */
@Composable
fun RewardContinueButton(
  title: String,
  onClick: () -> Unit,
  modifier: Modifier = Modifier,
  isFinal: Boolean = false,
  isBusy: Boolean = false,
) {
  val alpha by animateFloatAsState(
    targetValue = if (isBusy) BUSY_ALPHA else 1f,
    animationSpec = settle(),
    label = "reward-continue-alpha",
  )
  val labelAlpha by animateFloatAsState(
    targetValue = if (isBusy) 0f else 1f,
    animationSpec = settle(),
    label = "reward-continue-label",
  )
  val hint = stringResource(
    if (isFinal) R.string.reward_continue_hint_final else R.string.reward_continue_hint_next,
  )
  val shape = RoundedCornerShape(percent = 50)

  Box(
    modifier = modifier
      .fillMaxWidth()
      // ModulateAlpha, not an offscreen layer: a layer is clipped to the
      // button's bounds, which would cut the bloom into a hard rectangle while busy.
      .graphicsLayer {
        this.alpha = alpha
        compositingStrategy = CompositingStrategy.ModulateAlpha
      }
      .softPress()
      .dropShadow(
        shape = shape,
        shadow = Shadow(
          radius = BLOOM_RADIUS,
          color = Color.lavenderMist.copy(alpha = BLOOM_ALPHA),
          offset = DpOffset(0.dp, BLOOM_OFFSET_Y),
        ),
      )
      .background(Brush.linearGradient(listOf(Color.lavenderMist, Color.softLilac)), shape)
      .clickable(
        enabled = !isBusy,
        onClickLabel = hint,
        role = Role.Button,
        interactionSource = null,
        indication = null,
        onClick = onClick,
      )
      .heightIn(min = MIN_HEIGHT),
    contentAlignment = Alignment.Center,
  ) {
    Text(
      text = title,
      style = LABEL_STYLE,
      color = Color.White,
      textAlign = TextAlign.Center,
      modifier = Modifier
        .padding(horizontal = Dp.edge)
        .alpha(labelAlpha),
    )
    if (isBusy) {
      CircularProgressIndicator(
        color = Color.White,
        strokeWidth = SPINNER_STROKE,
        modifier = Modifier.size(SPINNER_SIZE),
      )
    }
  }
}

// MARK: - Previews

@Preview(showBackground = true, name = "Reward continue")
@Composable
private fun RewardContinueButtonPreview() {
  Box(Modifier.fillMaxSize().background(Color.moonCream)) {
    Column(
      modifier = Modifier.padding(Dp.edge),
      verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
    ) {
      RewardContinueButton(title = "Continue", onClick = {})
      RewardContinueButton(title = "Send & continue", isBusy = true, onClick = {})
      RewardContinueButton(title = "Carry this calm", isFinal = true, onClick = {})
    }
  }
}
