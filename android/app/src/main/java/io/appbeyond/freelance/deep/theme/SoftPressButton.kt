package io.appbeyond.freelance.deep.theme

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** Scale a wearer depresses to on press — DESIGN.md's "pressing into foam". */
private const val DEFAULT_PRESSED_SCALE = 0.97f

/**
 * Foam-like press feedback: scales down on press and releases with [settle].
 *
 * Ported from Deep/Deep/Theme/SoftPressButtonStyle.swift. SwiftUI reads press
 * state straight off `ButtonStyleConfiguration`, a style protocol shared by
 * every button on that platform. Compose has no equivalent that a stock
 * [androidx.compose.material3.Button] and a bare `Modifier.clickable` both go
 * through, so this reads the raw pointer stream instead: it sits *before*
 * `.clickable()` (or a `Button`'s own click handling) in the modifier chain
 * and never consumes what it sees, so the tap underneath lands exactly as it
 * would without this modifier. That is what lets a plain
 * `Modifier.background(...).softPress().clickable(onClick = ...)` chain wear
 * it — see `BeginButton` in `DeepSessionIntroScreen.kt`.
 *
 * @param pressedScale the scale to depress to. Defaults to the app-wide 0.97.
 */
@Composable
fun Modifier.softPress(pressedScale: Float = DEFAULT_PRESSED_SCALE): Modifier {
  var pressed by remember { mutableStateOf(false) }
  val scale by animateFloatAsState(
    targetValue = if (pressed) pressedScale else 1f,
    animationSpec = settle(),
    label = "soft-press-scale",
  )

  return this
    .pointerInput(Unit) {
      awaitEachGesture {
        awaitFirstDown(requireUnconsumed = false)
        pressed = true
        waitForUpOrCancellation()
        pressed = false
      }
    }
    .graphicsLayer {
      scaleX = scale
      scaleY = scale
    }
}

@Preview(showBackground = true)
@Composable
private fun SoftPressPreview() {
  Box(
    modifier = Modifier
      .fillMaxSize()
      .background(Color.moonCream),
    contentAlignment = Alignment.Center,
  ) {
    Box(
      modifier = Modifier
        .clip(RoundedCornerShape(Dp.chip))
        .background(Color.lavenderMist)
        .softPress()
        .clickable(onClick = {})
        .padding(horizontal = 32.dp, vertical = 14.dp),
    ) {
      Text("Begin", style = DeepType.bodyMedium, color = Color.White)
    }
  }
}
