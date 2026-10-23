package io.appbeyond.freelance.deep.feature.deepsound.components

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.setProgress
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.settle

// MARK: - Constants

/** The resting track — iOS's `trackHeight: 6`. */
private val TRACK_HEIGHT = 6.dp

/** How much the track swells under the finger — iOS's `trackHeight + 4`. */
private val DRAG_SWELL = 4.dp

/** The whole slider's height, and so its touch target — iOS's `.frame(height: 28)`. */
private val HIT_HEIGHT = 28.dp

/** The unfilled track — iOS's `lavenderMist.opacity(0.22)`. */
private const val TRACK_ALPHA = 0.22f

// MARK: - Slider

/**
 * A draggable 0…1 track, used for both the scrubber and the volume on Now
 * Playing. Ported from `Deep/Deep/Features/DeepSound/Components/SoundSlider.swift`.
 *
 * Apple Music's behaviour, which Material's `Slider` doesn't have: no thumb,
 * the track thickens while you hold it, and the fill jumps to wherever the
 * finger lands — a zero-distance drag, so a tap is a seek. Timing is DEEP's
 * [settle], not the platform's.
 *
 * The drag consumes every pointer change it sees, so a parent's own vertical
 * drag (Now Playing's swipe-down) never starts from a finger that began here.
 *
 * @param value the position, 0…1; values outside are drawn clamped.
 * @param onValueChange called on every move with the finger's new 0…1 position.
 * @param onValueChangeFinished called once when the finger lifts — the
 *   scrubber seeks here rather than on every move.
 * @param activeColor the filled part of the track.
 */
@Composable
fun SoundSlider(
  value: Float,
  onValueChange: (Float) -> Unit,
  modifier: Modifier = Modifier,
  onValueChangeFinished: () -> Unit = {},
  activeColor: Color = Color.lavenderMist,
) {
  var isDragging by remember { mutableStateOf(false) }
  val trackHeight by animateDpAsState(
    targetValue = if (isDragging) TRACK_HEIGHT + DRAG_SWELL else TRACK_HEIGHT,
    animationSpec = settle(),
    label = "sound-slider-track",
  )
  val currentValue by rememberUpdatedState(value.coerceIn(0f, 1f))
  val onChange by rememberUpdatedState(onValueChange)
  val onFinished by rememberUpdatedState(onValueChangeFinished)

  Box(
    modifier
      .fillMaxWidth()
      .height(HIT_HEIGHT)
      .semantics {
        progressBarRangeInfo = ProgressBarRangeInfo(currentValue, 0f..1f)
        setProgress { target ->
          onChange(target.coerceIn(0f, 1f))
          onFinished()
          true
        }
      }
      .pointerInput(Unit) {
        awaitEachGesture {
          val down = awaitFirstDown()
          val width = size.width.toFloat().coerceAtLeast(1f)
          down.consume()
          isDragging = true
          onChange((down.position.x / width).coerceIn(0f, 1f))
          while (true) {
            val event = awaitPointerEvent()
            val change = event.changes.firstOrNull { it.id == down.id } ?: break
            if (!change.pressed) {
              change.consume()
              break
            }
            if (change.positionChange() != Offset.Zero) {
              onChange((change.position.x / width).coerceIn(0f, 1f))
            }
            change.consume()
          }
          isDragging = false
          onFinished()
        }
      }
      .drawBehind {
        val height = trackHeight.toPx()
        val top = (size.height - height) / 2f
        val radius = CornerRadius(height / 2f)
        val track = RoundRect(0f, top, size.width, top + height, radius)
        clipPath(Path().apply { addRoundRect(track) }) {
          drawRect(Color.lavenderMist.copy(alpha = TRACK_ALPHA), Offset(0f, top), Size(size.width, height))
          drawRect(activeColor, Offset(0f, top), Size(size.width * currentValue, height))
        }
      },
  )
}

// MARK: - Preview

@Preview(showBackground = true, name = "Sound slider")
@Composable
private fun SoundSliderPreview() {
  DeepTheme {
    Column(
      Modifier.fillMaxSize().background(Color.moonCream).padding(Dp.edge),
      verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
    ) {
      var scrub by remember { mutableFloatStateOf(0.4f) }
      SoundSlider(value = scrub, onValueChange = { scrub = it })

      var volume by remember { mutableFloatStateOf(0.6f) }
      SoundSlider(
        value = volume,
        onValueChange = { volume = it },
        activeColor = Color.lavenderMist.copy(alpha = 0.8f),
      )
    }
  }
}
