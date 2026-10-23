package io.appbeyond.freelance.deep.shared.components

import android.graphics.Bitmap
import android.graphics.Matrix
import android.view.TextureView
import androidx.annotation.OptIn
import androidx.annotation.RawRes
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.net.toUri
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.networking.LocalVideoCache
import io.appbeyond.freelance.deep.networking.VideoCache
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.moonCream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

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

  val isResumed = rememberIsStarted()

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

// MARK: - Remote footage

/** The poster's gradient when there is no poster — iOS's `ArtworkPalette.mist`. */
private const val POSTER_FALLBACK_PALETTE = "mist"

/** URI schemes that are already on the device: played directly, never cached. */
private val LocalSchemes = setOf("file", "android.resource", "content", "asset", "rawresource")

/**
 * A muted, looping video whose footage lives on the server: the catalog-driven
 * counterpart to the bundled overload above.
 *
 * Ported from Deep/Deep/Shared/Components/RemoteLoopingVideoView.swift. The
 * poster paints first, through [ArtworkImage] (its gradient standing in while
 * it loads, or when there is no poster), so the hero never opens on a black
 * hole. A local URI (`android.resource://…`, which fixture stages use for
 * bundled footage) or a fully cached copy plays straight away; otherwise the
 * remote URL streams through [LocalVideoCache] — filling it as it plays — and
 * the cache finishes the download in the background so the next mount plays
 * from disk. The footage fades in over the poster on [bloom] once its first
 * frame renders.
 *
 * A null [url] is simply the poster. When [isAnimating] is false (reduced
 * motion, by default) cached or local footage freezes on its first frame and
 * remote footage never streams at all — spinning up a stream just to freeze
 * its first frame wastes the network. The footage re-resolves when [url] or
 * [isAnimating] changes, so turning reduced motion off mid-session starts the
 * stream it previously declined.
 *
 * Aspect-fill, cropped to its bounds; muted; paused while the app is in the
 * background.
 *
 * @param posterPalette the [ArtworkImage] palette behind the poster.
 */
@OptIn(UnstableApi::class)
@Composable
fun LoopingVideoView(
  url: String?,
  modifier: Modifier = Modifier,
  posterUrl: String? = null,
  posterPalette: String? = POSTER_FALLBACK_PALETTE,
  isAnimating: Boolean = !rememberReduceMotion(),
) {
  val cache = LocalVideoCache.current
  var playback by remember { mutableStateOf<VideoPlayback?>(null) }

  LaunchedEffect(url, isAnimating, cache) {
    playback = resolvePlayback(url, isAnimating, cache)
  }

  Box(modifier.clipToBounds()) {
    ArtworkImage(url = posterUrl, palette = posterPalette, modifier = Modifier.matchParentSize())

    playback?.let { resolved ->
      // The player is built once per resolution; a changed one rebuilds it
      // rather than mutating it, as iOS re-ids its surface.
      key(resolved) {
        RemoteVideoSurface(
          playback = resolved,
          cache = cache,
          isAnimating = isAnimating,
          modifier = Modifier.matchParentSize(),
        )
      }
    }
  }
}

/** What to play, and whether it has to come through the cache. */
private data class VideoPlayback(val url: String, val viaCache: Boolean)

/**
 * Local footage plays directly; cached footage plays from disk whatever the
 * motion setting; remote footage streams (and warms the cache) only while
 * animating. Null means the poster alone.
 */
private suspend fun resolvePlayback(url: String?, isAnimating: Boolean, cache: VideoCache?): VideoPlayback? {
  if (url == null) return null
  if (url.toUri().scheme?.lowercase() in LocalSchemes) return VideoPlayback(url, viaCache = false)
  if (cache == null) return if (isAnimating) VideoPlayback(url, viaCache = false) else null

  val cached = withContext(Dispatchers.IO) { cache.isFullyCached(url) }
  return when {
    cached -> VideoPlayback(url, viaCache = true)
    isAnimating -> {
      cache.warm(url)
      VideoPlayback(url, viaCache = true)
    }
    else -> null
  }
}

/** The player and its texture, faded in on its first rendered frame. */
@OptIn(UnstableApi::class)
@Composable
private fun RemoteVideoSurface(
  playback: VideoPlayback,
  cache: VideoCache?,
  isAnimating: Boolean,
  modifier: Modifier = Modifier,
) {
  val context = LocalContext.current
  var isReady by remember { mutableStateOf(false) }
  val alpha by animateFloatAsState(
    targetValue = if (isReady) 1f else 0f,
    animationSpec = bloom(),
    label = "video-bloom",
  )
  var frameSize by remember { mutableStateOf(VideoSize.UNKNOWN) }

  val player = remember {
    val builder = ExoPlayer.Builder(context)
    if (playback.viaCache && cache != null) {
      builder.setMediaSourceFactory(DefaultMediaSourceFactory(cache.dataSourceFactory))
    }
    builder.build().apply {
      setMediaItem(MediaItem.fromUri(playback.url))
      repeatMode = Player.REPEAT_MODE_ALL
      volume = 0f
      prepare()
    }
  }

  DisposableEffect(player) {
    // A paused player still renders its first frame, so the still path blooms in too.
    val listener = object : Player.Listener {
      override fun onRenderedFirstFrame() {
        isReady = true
      }

      override fun onVideoSizeChanged(videoSize: VideoSize) {
        frameSize = videoSize
      }
    }
    player.addListener(listener)
    onDispose {
      player.removeListener(listener)
      player.release()
    }
  }

  val isStarted = rememberIsStarted()
  LaunchedEffect(isAnimating, isStarted) {
    if (isAnimating && isStarted) player.play() else player.pause()
  }

  AndroidView(
    modifier = modifier.graphicsLayer { this.alpha = alpha },
    factory = { ctx ->
      TextureView(ctx).also { view ->
        player.setVideoTextureView(view)
        view.addOnLayoutChangeListener { changed, _, _, _, _, _, _, _, _ ->
          (changed as TextureView).aspectFill(player.videoSize)
        }
      }
    },
    update = { view -> view.aspectFill(frameSize) },
  )
}

/**
 * Crops the video to fill the view without distortion — iOS's
 * `.resizeAspectFill`. A `TextureView` stretches its content to its bounds, so
 * the axis with room to spare is scaled back up past the edge about the centre.
 */
private fun TextureView.aspectFill(size: VideoSize) {
  if (width == 0 || height == 0 || size.width == 0 || size.height == 0) return
  val videoAspect = size.width * size.pixelWidthHeightRatio / size.height
  val viewAspect = width.toFloat() / height
  val matrix = Matrix()
  if (videoAspect > viewAspect) {
    matrix.setScale(videoAspect / viewAspect, 1f, width / 2f, height / 2f)
  } else {
    matrix.setScale(1f, viewAspect / videoAspect, width / 2f, height / 2f)
  }
  setTransform(matrix)
}

// MARK: - Lifecycle

/**
 * Whether the host is in the foreground. Decoding stops when the app leaves
 * it: without this the loop keeps running behind the launcher, burning battery
 * to draw a surface nobody is looking at — and on a software renderer it
 * starves everything else on the device.
 */
@Composable
private fun rememberIsStarted(): Boolean {
  val lifecycleOwner = LocalLifecycleOwner.current
  var isStarted by remember { mutableStateOf(true) }
  DisposableEffect(lifecycleOwner) {
    val observer = LifecycleEventObserver { _, event ->
      when (event) {
        Lifecycle.Event.ON_START -> isStarted = true
        Lifecycle.Event.ON_STOP -> isStarted = false
        else -> Unit
      }
    }
    lifecycleOwner.lifecycle.addObserver(observer)
    onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
  }
  return isStarted
}

// MARK: - Previews

private val PreviewHeroHeight = 360.dp

@Preview(showBackground = true, name = "Remote video — bundled file")
@Composable
private fun RemoteVideoBundledPreview() {
  val context = LocalContext.current
  LoopingVideoView(
    url = "android.resource://${context.packageName}/${R.raw.deep_oak_mature}",
    isAnimating = true,
    modifier = Modifier
      .background(Color.moonCream)
      .padding(16.dp)
      .fillMaxWidth()
      .height(PreviewHeroHeight)
      .clip(RoundedCornerShape(Dp.card)),
  )
}

@Preview(showBackground = true, name = "Remote video — no footage, no poster")
@Composable
private fun RemoteVideoPosterOnlyPreview() {
  // No cache is provided, so nothing here touches disk or the network.
  LoopingVideoView(
    url = null,
    modifier = Modifier
      .background(Color.moonCream)
      .padding(16.dp)
      .fillMaxWidth()
      .height(PreviewHeroHeight)
      .clip(RoundedCornerShape(Dp.card)),
  )
}
