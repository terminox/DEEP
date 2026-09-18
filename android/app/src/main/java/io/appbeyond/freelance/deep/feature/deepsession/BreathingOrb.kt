package io.appbeyond.freelance.deep.feature.deepsession

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.skyWash
import io.appbeyond.freelance.deep.theme.softLilac

/**
 * The session's centrepiece — a luminous orb inside a fixed halo ring.
 *
 * Purely visual. The caller decides [swell] (0 to 1) and owns the animation that
 * carries it between phases, so the orb can render any moment of the breath
 * without a clock of its own. That is what lets a preview pin it, and what lets
 * a paused practice freeze it exactly where it stood.
 *
 * Ported from Deep/Deep/Features/DeepSession/Components/BreathingOrb.swift.
 *
 * @param swell how full the breath is. 0 rests well inside the ring; 1 meets it.
 * @param glow the orb's opacity. Under reduced motion the practice breathes
 *   through this instead of through scale, so the light still moves with the
 *   breath but nothing grows.
 */
@Composable
fun BreathingOrb(
  swell: Float,
  modifier: Modifier = Modifier,
  glow: Float = 1f,
) {
  Box(modifier.aspectRatio(1f), contentAlignment = Alignment.Center) {
    Canvas(Modifier.fillMaxSize()) {
      val ring = size.minDimension / 2f
      val centre = Offset(size.width / 2f, size.height / 2f)
      val strokePx = HALO_STROKE.toPx()

      // The halo the breath swells towards.
      drawCircle(
        color = Color.White.copy(alpha = 0.65f * glow),
        radius = ring - strokePx / 2f,
        center = centre,
        style = Stroke(width = strokePx),
      )

      // A single bead resting on it, so the ring reads as a path rather than
      // an outline, and so the top of the breath has somewhere to arrive.
      drawCircle(
        color = Color.White.copy(alpha = glow),
        radius = BEAD_DIAMETER.toPx() / 2f,
        center = Offset(centre.x, centre.y - ring + BEAD_INSET.toPx()),
      )

      // The orb itself. The gradient's centre sits above the middle, which is
      // what gives the sphere a light source instead of a flat disc.
      val orbRadius = (ring - ORB_INSET.toPx()) * (0.55f + 0.45f * swell)
      val orbCentre = Offset(centre.x, centre.y)

      // The bloom beneath, standing in for the iOS shadow — a real shadow would
      // need a blur, which is a no-op below API 31.
      drawCircle(
        brush = Brush.radialGradient(
          colorStops = arrayOf(
            0f to Color.lavenderMist.copy(alpha = 0.40f * glow),
            0.55f to Color.lavenderMist.copy(alpha = 0.18f * glow),
            1f to Color.lavenderMist.copy(alpha = 0f),
          ),
          center = orbCentre,
          radius = orbRadius * 1.75f,
        ),
        radius = orbRadius * 1.75f,
        center = orbCentre,
      )

      drawCircle(
        brush = Brush.radialGradient(
          colorStops = arrayOf(
            0f to Color.White.copy(alpha = 0.95f * glow),
            0.42f to Color.softLilac.copy(alpha = 0.75f * glow),
            0.75f to Color.lavenderMist.copy(alpha = 0.45f * glow),
            1f to Color.skyWash.copy(alpha = 0.25f * glow),
          ),
          // Slightly above centre, matching the iOS UnitPoint(0.5, 0.42).
          center = Offset(orbCentre.x, orbCentre.y - orbRadius * 0.16f),
          radius = orbRadius,
        ),
        radius = orbRadius,
        center = orbCentre,
      )
    }
  }
}

private val HALO_STROKE = 1.5.dp
private val BEAD_DIAMETER = 10.dp
private val BEAD_INSET = 1.dp
private val ORB_INSET = 14.dp

@Preview(showBackground = true, name = "Rest and full")
@Composable
private fun BreathingOrbPreview() {
  Box(Modifier.fillMaxSize()) {
    AtmosphereBackground(animated = false)
    Column(
      Modifier.fillMaxSize(),
      verticalArrangement = Arrangement.spacedBy(Dp.rhythm, Alignment.CenterVertically),
      horizontalAlignment = Alignment.CenterHorizontally,
    ) {
      BreathingOrb(swell = 0f, modifier = Modifier.size(220.dp))
      BreathingOrb(swell = 1f, modifier = Modifier.size(220.dp))
    }
  }
}
