package io.appbeyond.freelance.deep.feature.globalpause.globe.earth

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.SurfaceTexture
import android.view.MotionEvent
import android.view.TextureView
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
import kotlin.math.roundToInt

/**
 * The view the Earth draws into — a `TextureView`, not a `GLSurfaceView`
 * (EARTH3D_SPIKE.md §2.6): it clips to the card's rounded corners, sits in the
 * z-order between the night sky and the card's chrome, rides the card lift's
 * transforms without reallocating, and never lags its card while it scrolls.
 *
 * Renders at [EarthTarget.renderScale] of its size, the cheapest lever on the
 * raymarch's cost (§4.3 Fix C): the `TextureView` inside is LAID OUT that
 * much smaller and scaled back up to fill this view, and the compositor
 * upscales its buffer bilinearly.
 *
 * Why a smaller layout and not `SurfaceTexture.setDefaultBufferSize`: the
 * `TextureView` owns that size. Whenever it rebuilds its hardware layer —
 * after every window stop (Home, lock), with the SAME texture and no listener
 * callback — it resets the buffer to its own width and height. A smaller
 * buffer set from the listener silently became a full-size one while the
 * engine kept drawing the small viewport into its bottom-left corner: the
 * session's globe shrank into the corner and the card's dropped below its
 * clip (QA round 1, B1/B2). Laid out at the render size, the view's own
 * reset is the size the engine draws at, on every path.
 *
 * [interactive] views (the session's) turn under a finger and name a tapped
 * country; the card's is inert, so the whole card stays the tap target.
 * Touch is read here, at full size, so drag and tap maths see the globe as
 * the member does.
 */
@SuppressLint("ViewConstructor")
internal class EarthGlobeView(
  context: Context,
  private val engine: EarthEngine,
  val target: EarthTarget,
  private val interactive: Boolean,
) : ViewGroup(context) {

  private val tapSlop = ViewConfiguration.get(context).scaledTouchSlop.toFloat()

  private val surface = TextureView(context).apply {
    isOpaque = false
    surfaceTextureListener = SurfaceListener()
    pivotX = 0f
    pivotY = 0f
  }

  init {
    // Read aloud by the composable around it, not by the surface.
    importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
    addView(surface)
  }

  override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
    val width = getDefaultSize(suggestedMinimumWidth, widthMeasureSpec)
    val height = getDefaultSize(suggestedMinimumHeight, heightMeasureSpec)
    setMeasuredDimension(width, height)
    surface.measure(
      exactly(EarthRenderSize.of(width, target.renderScale)),
      exactly(EarthRenderSize.of(height, target.renderScale)),
    )
  }

  override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
    val renderWidth = surface.measuredWidth
    val renderHeight = surface.measuredHeight
    surface.layout(0, 0, renderWidth, renderHeight)
    // Pivot at the origin: the render-sized view grows to cover this one exactly.
    surface.scaleX = EarthRenderSize.upscale(right - left, renderWidth)
    surface.scaleY = EarthRenderSize.upscale(bottom - top, renderHeight)
  }

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

  private fun exactly(size: Int): Int = View.MeasureSpec.makeMeasureSpec(size, View.MeasureSpec.EXACTLY)

  /** The texture's size is the inner view's layout size, so it is passed on as given. */
  private inner class SurfaceListener : TextureView.SurfaceTextureListener {
    override fun onSurfaceTextureAvailable(texture: SurfaceTexture, width: Int, height: Int) {
      engine.surfaceAvailable(target, texture, width, height)
    }

    override fun onSurfaceTextureSizeChanged(texture: SurfaceTexture, width: Int, height: Int) {
      engine.surfaceResized(target, width, height)
    }

    /** False: the engine releases the texture once its EGL surface is gone. */
    override fun onSurfaceTextureDestroyed(texture: SurfaceTexture): Boolean {
      engine.surfaceDestroyed(target, texture)
      return false
    }

    /** Called as the view latches a frame into the draw that shows it: presented, not just submitted. */
    override fun onSurfaceTextureUpdated(texture: SurfaceTexture) {
      if (!target.presented.value) target.presented.value = true
    }
  }
}

/** The render-size arithmetic of [EarthGlobeView]. */
internal object EarthRenderSize {
  /** The pixels rendered along a side [viewSize] long, never zero. */
  fun of(viewSize: Int, renderScale: Float): Int = (viewSize * renderScale).roundToInt().coerceAtLeast(1)

  /** The scale that stretches [renderSize] back over [viewSize] exactly (not 1 / renderScale, which rounding breaks). */
  fun upscale(viewSize: Int, renderSize: Int): Float = if (renderSize > 0 && viewSize > 0) viewSize.toFloat() / renderSize else 1f
}
