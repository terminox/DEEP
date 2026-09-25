package io.appbeyond.freelance.deep.feature.onboarding.transition

import android.graphics.RenderEffect
import android.graphics.RuntimeShader
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asComposeRenderEffect
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.IntSize
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.peachCloud
import io.appbeyond.freelance.deep.theme.ripple
import io.appbeyond.freelance.deep.theme.skyWash

private const val REDUCED_MOTION_FADE_MILLIS = 200

private const val FEATHER_POINTS = 150f
private const val WAVELENGTH_POINTS = 34f
private const val AMPLITUDE_POINTS = 9f
private const val REACH_POINTS = 120f
private const val CREST_WIDTH_POINTS = 60f

/**
 * A decorative freeze-frame of the outgoing welcome screen that dissolves from
 * [origin], revealing the destination already rendered underneath it.
 *
 * [origin] is expressed in window pixels, matching a pointer position converted
 * with `LayoutCoordinates.localToWindow`. When it is null, the wave starts at
 * the horizontal centre and 80 percent of the way down this layer. [content]
 * should be an inert still rather than the live welcome screen: this overlay
 * adds no pointer handling, so touches continue to the destination underneath.
 *
 * Android 13 and newer use AGSL for the radial refraction and dissolve. Older
 * releases fade the still over the same ripple motion curve. Reduced motion
 * always uses a short fade.
 */
@Composable
fun RippleRevealOverlay(
  origin: Offset?,
  onFinished: () -> Unit,
  modifier: Modifier = Modifier,
  content: @Composable () -> Unit,
) {
  val reduceMotion = rememberReduceMotion()
  val progress = remember { Animatable(0f) }
  val currentOnFinished by rememberUpdatedState(onFinished)

  LaunchedEffect(reduceMotion) {
    progress.snapTo(0f)
    progress.animateTo(
      targetValue = 1f,
      animationSpec = if (reduceMotion) {
        tween(durationMillis = REDUCED_MOTION_FADE_MILLIS)
      } else {
        ripple()
      },
    )
    currentOnFinished()
  }

  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !reduceMotion) {
    RippleShaderContent(
      origin = origin,
      progress = progress.value,
      modifier = modifier,
      content = content,
    )
  } else {
    Box(
      modifier = modifier
        .graphicsLayer { alpha = 1f - progress.value }
        .clearAndSetSemantics {},
    ) {
      content()
    }
  }
}

@RequiresApi(Build.VERSION_CODES.TIRAMISU)
@Composable
private fun RippleShaderContent(
  origin: Offset?,
  progress: Float,
  modifier: Modifier,
  content: @Composable () -> Unit,
) {
  val shader = remember { RuntimeShader(RIPPLE_REVEAL_SHADER) }
  val density = LocalDensity.current.density
  val glow = Color.moonCream
  var layerSize by remember { mutableStateOf(IntSize.Zero) }
  var layerPositionInWindow by remember { mutableStateOf(Offset.Zero) }

  Box(
    modifier = modifier
      .onSizeChanged { layerSize = it }
      .onGloballyPositioned { layerPositionInWindow = it.positionInWindow() }
      .graphicsLayer {
        val localOrigin = origin?.minus(layerPositionInWindow)
          ?: Offset(layerSize.width * 0.5f, layerSize.height * 0.8f)

        shader.setFloatUniform("origin", localOrigin.x, localOrigin.y)
        shader.setFloatUniform("size", layerSize.width.toFloat(), layerSize.height.toFloat())
        shader.setFloatUniform("progress", progress)
        shader.setFloatUniform("feather", FEATHER_POINTS * density)
        shader.setFloatUniform("wavelength", WAVELENGTH_POINTS * density)
        shader.setFloatUniform("amplitude", AMPLITUDE_POINTS * density)
        shader.setFloatUniform("reach", REACH_POINTS * density)
        shader.setFloatUniform("crestWidth", CREST_WIDTH_POINTS * density)
        shader.setFloatUniform("glow", glow.red, glow.green, glow.blue, glow.alpha)
        // Rebuilt after every uniform write: createRuntimeShaderEffect snapshots
        // the shader's uniforms when it is created, so an effect remembered once
        // renders with every uniform at zero (transparent) forever.
        this.renderEffect = RenderEffect.createRuntimeShaderEffect(shader, "content").asComposeRenderEffect()
      }
      .clearAndSetSemantics {},
  ) {
    content()
  }
}

private const val RIPPLE_REVEAL_SHADER = """
  uniform shader content;
  uniform float2 origin;
  uniform float2 size;
  uniform float progress;
  uniform float feather;
  uniform float wavelength;
  uniform float amplitude;
  uniform float reach;
  uniform float crestWidth;
  uniform float4 glow;

  half4 main(float2 position) {
    float2 farCorner = max(origin, size - origin);
    float travel = length(farCorner) + feather;
    float ahead = distance(position, origin) - progress * travel;

    if (ahead < -feather) {
      return half4(0.0);
    }

    float life = smoothstep(0.0, 0.08, progress)
      * (1.0 - smoothstep(0.7, 1.0, progress));
    float envelope = exp(-max(ahead, 0.0) / reach) * life;
    float2 delta = position - origin;
    float deltaLength = length(delta);
    float2 radial = deltaLength > 0.0001 ? delta / deltaLength : float2(0.0);
    float2 samplePosition = position
      + radial * sin(ahead / wavelength) * amplitude * envelope;
    half4 color = content.eval(samplePosition);

    float crest = exp(-abs(ahead) / crestWidth) * life;
    color.rgb = mix(color.rgb, half3(glow.rgb * color.a), half(crest * 0.22));

    float alpha = smoothstep(-feather, -feather * 0.12, ahead);
    return color * half(alpha);
  }
"""

@Preview(showBackground = true, name = "Ripple reveal")
@Composable
private fun RippleRevealOverlayPreview() {
  Box(
    modifier = Modifier
      .fillMaxSize()
      .background(
        Brush.verticalGradient(
          colors = listOf(Color.skyWash, Color.moonCream),
        ),
      ),
    contentAlignment = Alignment.Center,
  ) {
    Text(
      text = "Revealed screen",
      style = DeepType.sectionTitle,
      color = Color.deepPlum,
    )

    RippleRevealOverlay(
      origin = null,
      onFinished = {},
      modifier = Modifier.fillMaxSize(),
    ) {
      Box(
        modifier = Modifier
          .fillMaxSize()
          .background(
            Brush.verticalGradient(
              colors = listOf(Color.peachCloud, Color.blushPowder),
            ),
          ),
        contentAlignment = Alignment.Center,
      ) {
        Text(
          text = "Outgoing welcome screen",
          style = DeepType.sectionTitle,
          color = Color.deepPlum,
          textAlign = TextAlign.Center,
        )
      }
    }
  }
}
