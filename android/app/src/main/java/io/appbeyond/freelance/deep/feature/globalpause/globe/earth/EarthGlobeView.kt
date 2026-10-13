package io.appbeyond.freelance.deep.feature.globalpause.globe.earth

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.SurfaceTexture
import android.view.MotionEvent
import android.view.TextureView
import android.view.ViewConfiguration
import kotlin.math.roundToInt

/**
 * The view the Earth draws into — a `TextureView`, not a `GLSurfaceView`
 * (EARTH3D_SPIKE.md §2.6): it clips to the card's rounded corners, sits in the
 * z-order between the night sky and the card's chrome, rides the card lift's
 * transforms without reallocating, and never lags its card while it scrolls.
 *
 * Renders at [renderScale] of its size — the buffer is set smaller than the
 * view and the compositor upscales it bilinearly — which is the cheapest
 * lever on the raymarch's cost (§4.3 Fix C).
 *
 * [interactive] views (the session's) turn under a finger and name a tapped
 * country; the card's is inert, so the whole card stays the tap target.
 */
@SuppressLint("ViewConstructor")
internal class EarthGlobeView(
  context: Context,
  private val engine: EarthEngine,
  val target: EarthTarget,
  private val interactive: Boolean,
) : TextureView(context), TextureView.SurfaceTextureListener {

  private val tapSlop = ViewConfiguration.get(context).scaledTouchSlop.toFloat()

  init {
    isOpaque = false
    surfaceTextureListener = this
    // Read aloud by the composable around it, not by the surface.
    importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
  }

  private fun scaled(size: Int): Int = (size * target.renderScale).roundToInt().coerceAtLeast(1)

  override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
    // TextureView has just sized the buffer to the view; render smaller.
    surface.setDefaultBufferSize(scaled(width), scaled(height))
    engine.surfaceAvailable(target, surface, scaled(width), scaled(height))
  }

  override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {
    surface.setDefaultBufferSize(scaled(width), scaled(height))
    engine.surfaceResized(target, scaled(width), scaled(height))
  }

  /** False: the engine releases the texture once its EGL surface is gone. */
  override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
    engine.surfaceDestroyed(target, surface)
    return false
  }

  override fun onSurfaceTextureUpdated(surface: SurfaceTexture) = Unit

  @SuppressLint("ClickableViewAccessibility")
  override fun onTouchEvent(event: MotionEvent): Boolean {
    if (!interactive) return false
    when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        parent?.requestDisallowInterceptTouchEvent(true)
        engine.touchDown(event.x, event.y, seconds(event.eventTime))
      }
      MotionEvent.ACTION_MOVE -> {
        // The batched samples too, oldest first — dropping them makes a drag
        // chunky and a flick's velocity wrong (§5.2).
        val count = event.historySize + 1
        val xs = FloatArray(count)
        val ys = FloatArray(count)
        val times = DoubleArray(count)
        for (i in 0 until event.historySize) {
          xs[i] = event.getHistoricalX(i)
          ys[i] = event.getHistoricalY(i)
          times[i] = seconds(event.getHistoricalEventTime(i))
        }
        xs[count - 1] = event.x
        ys[count - 1] = event.y
        times[count - 1] = seconds(event.eventTime)
        engine.touchMove(xs, ys, times, height.toFloat())
      }
      MotionEvent.ACTION_UP ->
        engine.touchUp(event.x, event.y, seconds(event.eventTime), width.toFloat(), height.toFloat(), tapSlop)
      MotionEvent.ACTION_CANCEL -> engine.touchCancel()
    }
    return true
  }

  private fun seconds(uptimeMillis: Long): Double = uptimeMillis / 1000.0
}
