package io.appbeyond.freelance.deep.shared.components

import android.graphics.Bitmap
import android.view.TextureView
import androidx.annotation.OptIn
import androidx.annotation.RawRes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer

/**
 * Bundled looping footage, muted, filling its bounds.
 *
 * A `TextureView` rather than a `SurfaceView`, because the hero is translated,
 * scaled and faded as the page scrolls — a SurfaceView punches a hole in the
 * window and does not participate in those transforms, so the video would sit
 * still while everything around it moved.
 *
 * Under reduced motion the first frame is held rather than played, matching the
 * iOS behaviour for a sustained atmospheric loop.
 *
 * @param frameGrabber optional handle a caller keeps to freeze the frame on
 *   screen right now — the onboarding welcome screen's ripple send-off
 *   dissolves a still of it (see [LoopingVideoFrameGrabber]).
 */
@OptIn(UnstableApi::class)
@Composable
fun LoopingVideoView(
  @RawRes resource: Int,
  modifier: Modifier = Modifier,
  isAnimating: Boolean = true,
  frameGrabber: LoopingVideoFrameGrabber? = null,
) {
  val context = LocalContext.current

  val player = remember {
    ExoPlayer.Builder(context).build().apply {
      setMediaItem(MediaItem.fromUri("android.resource://${context.packageName}/$resource"))
      repeatMode = Player.REPEAT_MODE_ALL
      volume = 0f
      playWhenReady = true
      prepare()
    }
  }

  // Decoding stops when the app leaves the foreground. Without this the loop
  // keeps running behind the launcher, burning battery to draw a surface nobody
  // is looking at — and on a software renderer it starves everything else on the
  // device.
  val lifecycleOwner = LocalLifecycleOwner.current
  var isResumed by remember { mutableStateOf(true) }
  DisposableEffect(lifecycleOwner) {
    val observer = LifecycleEventObserver { _, event ->
      when (event) {
        Lifecycle.Event.ON_START -> isResumed = true
        Lifecycle.Event.ON_STOP -> isResumed = false
        else -> Unit
      }
    }
    lifecycleOwner.lifecycle.addObserver(observer)
    onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
  }

  LaunchedEffect(isAnimating, isResumed) {
    if (isAnimating && isResumed) player.play() else player.pause()
  }

  DisposableEffect(Unit) {
    onDispose { player.release() }
  }

  DisposableEffect(frameGrabber) {
    onDispose { frameGrabber?.view = null }
  }

  AndroidView(
    modifier = modifier,
    factory = { ctx ->
      TextureView(ctx).also { view ->
        player.setVideoTextureView(view)
        frameGrabber?.view = view
      }
    },
  )
}

/**
 * Freezes whatever frame a [LoopingVideoView] is showing, as a bitmap the size
 * of the view — so drawing it back over the same bounds lines up pixel for
 * pixel.
 *
 * The Android twin of iOS's `LoopingVideoFrameGrabber`. iOS has to copy a pixel
 * buffer out of `AVPlayerItemVideoOutput` asynchronously (and bounds the wait,
 * since a layer shader cannot sample an `AVPlayerLayer`); a `TextureView` hands
 * its current contents back synchronously, so there is nothing to wait on.
 */
class LoopingVideoFrameGrabber {
  internal var view: TextureView? = null

  /** The frame on screen now, or null before the first frame has rendered. */
  fun currentFrame(): Bitmap? = view?.takeIf { it.isAvailable }?.bitmap
}
