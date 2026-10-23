package io.appbeyond.freelance.deep.feature.onboarding.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.onboarding.components.DeepLogoMark
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingPrimaryButton
import io.appbeyond.freelance.deep.feature.onboarding.components.OnboardingPreviewBackdrop
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.LoopingVideoFrameGrabber
import io.appbeyond.freelance.deep.shared.components.LoopingVideoView
import io.appbeyond.freelance.deep.shared.components.rememberReduceMotion
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.irisDusk
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm

// MARK: - Constants

/** welcome.mp4 is 1080 × 1920; the footage is aspect-filled against this. */
private const val VIDEO_ASPECT = 1080f / 1920f

private val MARK_SIZE = 80.dp
private val LOGO_TEXT_MAX_WIDTH = 300.dp
private val ACTION_SPACING = 14.dp
private val LINK_MIN_HEIGHT = 44.dp

private const val TOP_VEIL_ALPHA = 0.55f
private const val BOTTOM_VEIL_MID_ALPHA = 0.85f
private const val BOTTOM_VEIL_MID_STOP = 0.55f

// MARK: - State

/**
 * Where the server-driven onboarding config has got to. The whole flow is
 * server-driven from its very first question, so "Begin" stays dimmed until the
 * config lands and turns into a retry if the fetch gives up — the screen never
 * pretends to be ready over content that isn't there.
 */
enum class WelcomeConfigState { Loading, Ready, Failed }

/**
 * How the sunrise footage renders. [Live] plays the loop (the optional grabber
 * lets the coordinator freeze the frame on a CTA tap); [Still] redraws the whole
 * screen around that frozen frame, which is what the ripple send-off dissolves
 * — a render effect can't sample a `TextureView`'s decoder surface mid-frame
 * any more than iOS's layer shader can sample an `AVPlayerLayer`.
 */
sealed interface WelcomeVideo {
  data class Live(val frameGrabber: LoopingVideoFrameGrabber? = null) : WelcomeVideo
  data class Still(val frame: ImageBitmap?) : WelcomeVideo
}

// MARK: - Screen

/**
 * The opening of onboarding — a sunrise over a still mountain lake, looping
 * softly behind the logo. MoonCream veils keep the logo and actions legible
 * over the footage; the footage holds its first frame under reduced motion.
 *
 * Ported from Deep/Deep/Features/Onboarding/Screens/OnboardingIntroView.swift.
 * Unlike every other onboarding screen this one draws edge to edge (the video
 * and veils run under the system bars) and insets only its content.
 *
 * [WelcomeVideo.Still] also makes the screen inert — no pointer handling
 * anywhere — because the ripple overlay sits above the destination, and in
 * Compose the topmost sibling with any pointer node under a finger takes the
 * touch. iOS gets the same from `allowsHitTesting(false)` on the overlay.
 *
 * Not ported: iOS's Increase Contrast branch (solid veils, irisDusk mark).
 * Android exposes high-contrast text only through a hidden API, so there is no
 * signal to follow; the cream mark and translucent veils always apply.
 */
@Composable
fun WelcomeScreen(
  configState: WelcomeConfigState,
  onBegin: () -> Unit,
  onLogIn: () -> Unit,
  onRetry: () -> Unit,
  modifier: Modifier = Modifier,
  video: WelcomeVideo = WelcomeVideo.Live(),
) {
  val isStill = video is WelcomeVideo.Still

  Box(modifier.fillMaxSize()) {
    if (isStill) {
      // The still renders inside the ripple overlay and must be opaque: the
      // destination is already drawn underneath, and nothing of it may show
      // before the wave passes. A driftless atmosphere stands in wherever the
      // frame grab came back empty.
      Box(Modifier.fillMaxSize().background(Color.moonCream))
      AtmosphereBackground(animated = false)
    }

    Footage(video = video, modifier = Modifier.fillMaxSize().clearAndSetSemantics {})

    Veils(Modifier.fillMaxSize())

    Column(
      modifier = Modifier
        .fillMaxSize()
        .safeDrawingPadding()
        .padding(horizontal = Dp.edge)
        // The mark's halo needs room off the status bar.
        .padding(vertical = Dp.rhythm),
      verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
      horizontalAlignment = Alignment.CenterHorizontally,
    ) {
      DeepLogoMark(size = MARK_SIZE, tint = Color.moonCream, isGlowing = true)

      OnboardingLogoText()

      Spacer(Modifier.weight(1f))

      AnimatedContent(
        targetState = configState == WelcomeConfigState.Failed,
        transitionSpec = { fadeIn(exhale()) togetherWith fadeOut(exhale()) },
        label = "welcome-cta",
      ) { failed ->
        Column(
          modifier = Modifier.fillMaxWidth(),
          verticalArrangement = Arrangement.spacedBy(ACTION_SPACING),
          horizontalAlignment = Alignment.CenterHorizontally,
        ) {
          if (failed) {
            Text(
              text = stringResource(R.string.onboarding_config_failed),
              style = DeepType.caption,
              color = Color.driftGrey,
              textAlign = TextAlign.Center,
            )
            OnboardingPrimaryButton(
              title = stringResource(R.string.onboarding_try_again),
              onClick = onRetry,
              interactive = !isStill,
            )
          } else {
            OnboardingPrimaryButton(
              title = stringResource(R.string.onboarding_begin),
              enabled = configState == WelcomeConfigState.Ready,
              onClick = onBegin,
              interactive = !isStill,
            )
          }

          HaveAccountLink(onClick = onLogIn, interactive = !isStill)
        }
      }
    }
  }
}

/** The "DEEP — peace begins within" lockup, tinted from its alpha like an SF template image. */
@Composable
internal fun OnboardingLogoText(modifier: Modifier = Modifier) {
  val description = stringResource(R.string.onboarding_logo_description)
  Image(
    painter = painterResource(R.drawable.onboarding_logo_text),
    contentDescription = null,
    colorFilter = ColorFilter.tint(Color.irisDusk),
    contentScale = ContentScale.Fit,
    modifier = modifier
      .widthIn(max = LOGO_TEXT_MAX_WIDTH)
      .fillMaxWidth()
      .semantics {
        contentDescription = description
        heading()
      },
  )
}

/** "Already have an account? **Log in**" — one tappable line at least 44dp tall. */
@Composable
internal fun HaveAccountLink(onClick: () -> Unit, modifier: Modifier = Modifier, interactive: Boolean = true) {
  val link = stringResource(R.string.onboarding_log_in_link)
  val template = stringResource(R.string.onboarding_have_account)
  val text: AnnotatedString = buildAnnotatedString {
    val at = template.indexOf("%1\$s")
    if (at < 0) {
      append(template)
    } else {
      append(template.substring(0, at))
      withStyle(SpanStyle(fontWeight = FontWeight.Medium, textDecoration = TextDecoration.Underline)) {
        append(link)
      }
      append(template.substring(at + "%1\$s".length))
    }
  }

  Box(
    modifier = modifier
      .defaultMinSize(minHeight = LINK_MIN_HEIGHT)
      .then(
        if (interactive) {
          Modifier.clickable(role = Role.Button, interactionSource = null, indication = null, onClick = onClick)
        } else {
          Modifier
        },
      ),
    contentAlignment = Alignment.Center,
  ) {
    Text(text = text, style = DeepType.caption, color = Color.deepPlum, textAlign = TextAlign.Center)
  }
}

/**
 * The footage, aspect-filled and centred — or its frozen frame at exactly the
 * same size and position, so the still lines up with the live video pixel for
 * pixel. A `TextureView` stretches to its bounds, so the fill is done here by
 * sizing it past the screen and clipping.
 */
@Composable
private fun Footage(video: WelcomeVideo, modifier: Modifier = Modifier) {
  val reduceMotion = rememberReduceMotion()

  BoxWithConstraints(modifier.clipToBounds(), contentAlignment = Alignment.Center) {
    val scale = maxOf(maxWidth / VIDEO_ASPECT, maxHeight)
    val fill = Modifier.requiredSize(width = scale * VIDEO_ASPECT, height = scale)

    when (video) {
      // A preview must not spin up a real ExoPlayer; the atmosphere shows through instead.
      is WelcomeVideo.Live -> if (!LocalInspectionMode.current) LoopingVideoView(
        resource = R.raw.welcome,
        isAnimating = !reduceMotion,
        frameGrabber = video.frameGrabber,
        modifier = fill,
      )
      is WelcomeVideo.Still -> video.frame?.let { frame ->
        Image(bitmap = frame, contentDescription = null, contentScale = ContentScale.FillBounds, modifier = fill)
      }
    }
  }
}

/**
 * Soft moonCream gradients that guarantee contrast against the footage: a
 * light wash over the sky behind the logo, and a near-solid scrim under the
 * actions.
 */
@Composable
private fun Veils(modifier: Modifier = Modifier) {
  Column(modifier.clearAndSetSemantics {}) {
    Box(
      Modifier
        .weight(1f)
        .fillMaxWidth()
        .background(
          Brush.verticalGradient(listOf(Color.moonCream.copy(alpha = TOP_VEIL_ALPHA), Color.Transparent)),
        ),
    )
    Spacer(Modifier.weight(1f))
    Box(
      Modifier
        .weight(1f)
        .fillMaxWidth()
        .background(
          Brush.verticalGradient(
            0f to Color.Transparent,
            BOTTOM_VEIL_MID_STOP to Color.moonCream.copy(alpha = BOTTOM_VEIL_MID_ALPHA),
            1f to Color.moonCream,
          ),
        ),
    )
  }
}

// MARK: - Previews

/*
 * Live mode is preview-safe: under `LocalInspectionMode` the footage is skipped
 * (no ExoPlayer is ever built) and the preview atmosphere shows through.
 */

@Preview(showBackground = true, name = "Welcome")
@Composable
private fun WelcomeScreenPreview() {
  OnboardingPreviewBackdrop {
    WelcomeScreen(
      configState = WelcomeConfigState.Ready,
      onBegin = {},
      onLogIn = {},
      onRetry = {},
    )
  }
}

@Preview(showBackground = true, name = "Welcome — config loading")
@Composable
private fun WelcomeScreenLoadingPreview() {
  OnboardingPreviewBackdrop {
    WelcomeScreen(
      configState = WelcomeConfigState.Loading,
      onBegin = {},
      onLogIn = {},
      onRetry = {},
    )
  }
}

@Preview(showBackground = true, name = "Welcome — config failed")
@Composable
private fun WelcomeScreenFailedPreview() {
  OnboardingPreviewBackdrop {
    WelcomeScreen(
      configState = WelcomeConfigState.Failed,
      onBegin = {},
      onLogIn = {},
      onRetry = {},
    )
  }
}
