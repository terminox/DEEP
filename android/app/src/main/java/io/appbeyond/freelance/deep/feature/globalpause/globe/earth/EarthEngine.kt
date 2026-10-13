package io.appbeyond.freelance.deep.feature.globalpause.globe.earth

import android.app.ActivityManager
import android.content.Context
import android.graphics.SurfaceTexture
import android.opengl.EGL14
import android.opengl.EGLSurface
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Choreographer
import io.appbeyond.freelance.deep.feature.globalpause.earth.CountryLookup
import io.appbeyond.freelance.deep.feature.globalpause.earth.EarthGlowSnapshot
import io.appbeyond.freelance.deep.feature.globalpause.earth.EarthGlowStore
import io.appbeyond.freelance.deep.feature.globalpause.earth.EarthHaloRipples
import io.appbeyond.freelance.deep.feature.globalpause.earth.EarthInteraction
import io.appbeyond.freelance.deep.feature.globalpause.earth.EarthTuning
import io.appbeyond.freelance.deep.feature.globalpause.earth.JoinQueue
import io.appbeyond.freelance.deep.feature.globalpause.earth.Mat4
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseJoinPoint
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseLiveSnapshot
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * The one Earth behind every globe on screen: a render thread holding one GL
 * context, the simulation it advances (glow, orientation, ripples, arrivals),
 * and the `TextureView` surfaces it draws into. iOS's `GlobalPauseEarthScene`
 * plus `EarthRenderer`'s frame loop.
 *
 * One instance per process ([get]), hoisted above the composition on purpose:
 * the lounge card and the live session draw the SAME world — same
 * orientation, same lights — which is what lets the card lift hand the globe
 * from one surface to the other without a blink; and a `LazyColumn` scrolling
 * the card away and back must not rebuild a context and recompile a
 * 900-line shader each time (EARTH3D_SPIKE.md §2.6).
 *
 * Threading: every field below the public API is confined to the render
 * thread. The UI thread talks to it only by posting ([post]); what the UI
 * reads back — [status], [ripples], [reveals], a target's `firstFrame`, the
 * [orientation] snapshot — is published thread-safely.
 *
 * Lifecycle: the context is built when the first globe attaches and released
 * [RELEASE_GRACE_MILLIS] after the last one detaches (a scroll or a tab
 * switch back within it costs nothing). Frames run only while some surface is
 * attached, sized and active — never for a globe on another tab, behind the
 * session, or with the app in the background — and never above 60 fps (30
 * for the resting card, whose drift is 0.05 rad/s).
 */
internal class EarthEngine private constructor(private val appContext: Context) {

  sealed interface Status {
    /** Nothing built yet, or released after the last globe left. */
    data object Idle : Status

    data object Starting : Status

    /** Rendering. [hdr] false means the bloom-less fallback (no RGBA16F target). */
    data class Ready(val hdr: Boolean) : Status

    /** This device can't run the Earth — the 2D globe stands in. */
    data class Unavailable(val reason: String) : Status
  }

  private val _status = MutableStateFlow<Status>(
    if (supportsGles3(appContext)) Status.Idle else Status.Unavailable("OpenGL ES 3.0 is not supported"),
  )
  val status: StateFlow<Status> = _status.asStateFlow()

  private val _ripples = MutableStateFlow<List<EarthHaloRipples.Ripple>>(emptyList())

  /** The rings in flight, stamped on the [System.nanoTime] clock in seconds. */
  val ripples: StateFlow<List<EarthHaloRipples.Ripple>> = _ripples.asStateFlow()

  private val _reveals = MutableSharedFlow<CountryLookup.Country>(
    extraBufferCapacity = 1,
    onBufferOverflow = BufferOverflow.DROP_OLDEST,
  )

  /** A tap landed on a country: name it. */
  val reveals: SharedFlow<CountryLookup.Country> = _reveals.asSharedFlow()

  /** The orientation as last rendered — read-only, for the ripple overlay. */
  @Volatile
  var orientation: Mat4 = Mat4()
    private set

  /** Sphere-local ripple projection constants, shared with the overlay. */
  val rippleTuning: EarthHaloRipples.Tuning get() = rippleStore.tuning

  // MARK: - Render-thread state

  private val thread = HandlerThread("DEEP Earth").apply { start() }
  private val handler = Handler(thread.looper)
  private var choreographer: Choreographer? = null
  private var frameScheduled = false

  private var egl: EglCore? = null
  private var renderer: EarthRenderer? = null
  private val targets = ArrayList<EarthTarget>()
  private var registered = 0

  private val glow = EarthGlowStore()
  private val interaction = EarthInteraction()
  private val rippleStore = EarthHaloRipples()
  private val joins = JoinQueue()
  private val tuning = EarthTuning.Shipped
  private val startNanos = System.nanoTime()
  private var snapshot = EarthGlowSnapshot.Empty
  private var nextJoinNanos = 0L

  private var sessionActive = false
  private var arrivalDeadlineNanos: Long? = null
  private var arrivalTarget: PauseJoinPoint? = null
  private var pendingOwnJoin: PauseJoinPoint? = null
  private var home: PauseJoinPoint? = null

  private val frameCallback = Choreographer.FrameCallback { onFrame(it) }
  private val releaseRunnable = Runnable { releaseGl() }

  init {
    handler.post { choreographer = Choreographer.getInstance() }
  }

  private fun post(block: () -> Unit) {
    handler.post(block)
  }

  // MARK: - Targets (UI thread)

  /** A globe view now exists: build the context if it isn't already. */
  fun register(target: EarthTarget) = post {
    registered++
    handler.removeCallbacks(releaseRunnable)
    targets += target
    ensureStarted()
  }

  /** A globe view went away for good. */
  fun unregister(target: EarthTarget) = post {
    registered--
    dropSurface(target)
    targets -= target
    if (registered <= 0) {
      registered = 0
      handler.removeCallbacks(releaseRunnable)
      handler.postDelayed(releaseRunnable, RELEASE_GRACE_MILLIS)
    }
  }

  fun surfaceAvailable(target: EarthTarget, texture: SurfaceTexture, width: Int, height: Int) = post {
    target.texture = texture
    target.width = width
    target.height = height
    attachSurface(target)
    scheduleFrame()
  }

  fun surfaceResized(target: EarthTarget, width: Int, height: Int) = post {
    target.width = width
    target.height = height
    scheduleFrame()
  }

  /**
   * The view's surface is going (scrolled away, backgrounded, navigated off).
   * The view returns false from `onSurfaceTextureDestroyed`, so the texture
   * is released HERE — after its EGL surface is gone — and the UI thread
   * never blocks on the render thread.
   */
  fun surfaceDestroyed(target: EarthTarget, texture: SurfaceTexture) = post {
    if (target.texture === texture) dropSurface(target)
    texture.release()
  }

  /** Whether [target] should be drawing now (lifecycle, visibility, cover). */
  fun setActive(target: EarthTarget, active: Boolean) = post {
    target.active = active
    if (active) scheduleFrame()
  }

  // MARK: - Scene (UI thread)

  /** The room as the live poll last saw it. Unchanged inputs are no-ops. */
  fun setScene(
    locations: List<PauseLiveSnapshot.GeoPoint>,
    unlocatedByCountry: Map<String, Int>,
    participantsByCountry: Map<String, Int>,
    homeLocation: PauseJoinPoint?,
  ) = post {
    if (glow.locations != locations) glow.locations = locations
    if (glow.unlocatedByCountry != unlocatedByCountry) glow.unlocatedByCountry = unlocatedByCountry
    if (glow.participantsByCountry != participantsByCountry) glow.participantsByCountry = participantsByCountry
    if (glow.homeLocation != homeLocation) glow.homeLocation = homeLocation
    home = homeLocation
    armArrival()
  }

  /** Someone arrived. The member's own arrival waits for the globe to land on them. */
  fun join(point: PauseJoinPoint, isOwn: Boolean) = post {
    val deadline = arrivalDeadlineNanos
    if (isOwn && deadline != null && arrivalTarget != null && System.nanoTime() < deadline) {
      pendingOwnJoin = point
    } else if (isOwn) {
      joins.enqueueOwn(point)
    } else {
      joins.enqueue(listOf(point))
    }
  }

  /**
   * The session's globe has landed: the world keeps turning for a minute and
   * comes to rest on the member (iOS `turnGlobeHome`), and self-spin is shut
   * down underneath it so nothing restarts the drift once it stops.
   */
  fun beginSession() = post {
    sessionActive = true
    arrivalDeadlineNanos = System.nanoTime() + ARRIVAL_TURN_NANOS
    arrivalTarget = null
    interaction.decelerateToRest(ARRIVAL_GATE_SECONDS)
    armArrival()
  }

  /** The session is over: no arrival, no queued sparks, and the globe spins free. */
  fun endSession() = post {
    sessionActive = false
    arrivalDeadlineNanos = null
    arrivalTarget = null
    pendingOwnJoin = null
    interaction.cancelTurn()
    interaction.resumeSpin(1.0)
    joins.clear()
    glow.clearSparks()
    rippleStore.clear()
    _ripples.value = emptyList()
  }

  // MARK: - Touch (UI thread; event times in seconds)

  fun touchDown(x: Float, y: Float, time: Double) = post { interaction.touchBegan(x, y, time) }

  fun touchMove(xs: FloatArray, ys: FloatArray, times: DoubleArray, viewHeight: Float) = post {
    for (i in xs.indices) interaction.touchMoved(xs[i], ys[i], times[i], viewHeight)
  }

  fun touchUp(x: Float, y: Float, time: Double, viewWidth: Float, viewHeight: Float, tapSlop: Float) = post {
    val tapped = interaction.touchEnded(x, y, time, viewWidth, viewHeight, tapSlop) ?: return@post
    CountryLookup.nearestCountry(tapped.lat, tapped.lon, withinDegrees = TAP_REACH_DEGREES)?.let(_reveals::tryEmit)
  }

  fun touchCancel() = post { interaction.touchCancelled() }

  // MARK: - Render thread

  private fun ensureStarted() {
    if (egl != null || _status.value is Status.Unavailable) return
    _status.value = Status.Starting
    try {
      val core = EglCore.create()
      egl = core
      renderer = EarthRenderer.create(appContext.assets)
      _status.value = Status.Ready(renderer!!.hdr)
      targets.forEach(::attachSurface)
      scheduleFrame()
    } catch (e: Throwable) {
      Log.e(TAG, "The Earth can't render here; the 2D globe stands in", e)
      teardown(contextAlive = egl != null)
      _status.value = Status.Unavailable(e.message ?: e.javaClass.simpleName)
    }
  }

  private fun attachSurface(target: EarthTarget) {
    val core = egl ?: return
    val texture = target.texture ?: return
    if (target.eglSurface != null) return
    val surface = core.createWindowSurface(texture)
    if (surface == null) {
      Log.w(TAG, "eglCreateWindowSurface failed (0x${Integer.toHexString(core.lastError)})")
      return
    }
    target.eglSurface = surface
  }

  private fun dropSurface(target: EarthTarget) {
    val surface = target.eglSurface
    renderer?.releaseTargets(target.gpu)
    if (surface != null) egl?.destroySurface(surface)
    target.eglSurface = null
    target.texture = null
    target.firstFrame.value = false
  }

  private fun renderable(target: EarthTarget): Boolean =
    target.eglSurface != null && target.active && target.width > 0 && target.height > 0

  private fun scheduleFrame() {
    if (frameScheduled || renderer == null || targets.none(::renderable)) return
    val c = choreographer ?: return
    frameScheduled = true
    c.postFrameCallback(frameCallback)
  }

  private fun onFrame(frameTimeNanos: Long) {
    frameScheduled = false
    val r = renderer ?: return
    val core = egl ?: return
    val due = targets.filter { renderable(it) && frameTimeNanos - it.lastFrameNanos >= it.frameIntervalNanos - FRAME_SLACK_NANOS }
    scheduleFrame()
    if (due.isEmpty()) return

    simulate(frameTimeNanos)
    core.makeIdleCurrent()
    r.uploadGlow(snapshot)
    val time = ((frameTimeNanos - startNanos) / 1e9).toFloat()
    for (target in due) {
      val surface = target.eglSurface ?: continue
      if (!core.makeCurrent(surface)) {
        if (handleEglFailure(target, core.lastError)) return
        continue
      }
      r.draw(target.gpu, target.width, target.height, target.renderScale, time, orientation, snapshot, tuning)
      if (!core.swap(surface)) {
        if (handleEglFailure(target, core.lastError)) return
        continue
      }
      target.lastFrameNanos = frameTimeNanos
      if (!target.firstFrame.value) target.firstFrame.value = true
    }
    core.makeIdleCurrent()
  }

  /** True when the whole context had to be rebuilt (the caller stops this frame). */
  private fun handleEglFailure(target: EarthTarget, error: Int): Boolean {
    if (error == EGL14.EGL_CONTEXT_LOST) {
      Log.w(TAG, "EGL context lost; rebuilding")
      teardown(contextAlive = false)
      ensureStarted()
      return true
    }
    // The surface was abandoned under us: drop it and wait for a new one.
    Log.w(TAG, "EGL surface failed (0x${Integer.toHexString(error)}); dropping it")
    val surface = target.eglSurface
    renderer?.releaseTargets(target.gpu)
    if (surface != null) egl?.destroySurface(surface)
    target.eglSurface = null
    return false
  }

  private fun simulate(frameTimeNanos: Long) {
    val time = (frameTimeNanos - startNanos) / 1e9
    val clock = frameTimeNanos / 1e9

    // The member's own spark lands with the globe.
    val deadline = arrivalDeadlineNanos
    if (deadline != null && frameTimeNanos >= deadline) {
      pendingOwnJoin?.let(joins::enqueueOwn)
      pendingOwnJoin = null
    }
    // One arrival per beat, each ringing out as its own person.
    if (frameTimeNanos >= nextJoinNanos) {
      joins.next()?.let { (point, beatMillis) ->
        glow.spark(point.lat, point.lon)
        // The flat ring belongs to the classic spark style; flash + shell
        // carries its own 3D wave (iOS GlobalPauseEarthScene).
        if (glow.tuning.sparkStyle == EarthGlowStore.SparkStyle.Classic) rippleStore.emit(point.lat, point.lon, clock)
        nextJoinNanos = frameTimeNanos + beatMillis * 1_000_000
      }
    }

    glow.tick(time)
    orientation = interaction.orientationMatrix(time)
    val before = _ripples.value.size
    rippleStore.tick(clock)
    val active = rippleStore.active
    if (active.size != before || active != _ripples.value) _ripples.value = active
    snapshot = glow.currentGpuSnapshot()
  }

  private fun armArrival() {
    if (!sessionActive) return
    val deadline = arrivalDeadlineNanos ?: return
    val target = home ?: return
    val remaining = ((deadline - System.nanoTime()) / 1e9).coerceAtLeast(0.0)
    val current = arrivalTarget
    if (current == null) {
      arrivalTarget = target
      interaction.settle(target.lat, target.lon, remaining)
      return
    }
    // A correction (the IP-resolved point replacing the country centroid):
    // same landing, no extra lap, still forward.
    if (target != current && remaining > ARRIVAL_CORRECTION_FLOOR_SECONDS) {
      arrivalTarget = target
      interaction.settle(target.lat, target.lon, remaining, minimumTurns = 0f)
    }
  }

  private fun releaseGl() {
    if (registered > 0) return
    teardown(contextAlive = true)
    if (_status.value !is Status.Unavailable) _status.value = Status.Idle
  }

  /** Frees every GL object and the context. [contextAlive] false skips GL deletes. */
  private fun teardown(contextAlive: Boolean) {
    choreographer?.removeFrameCallback(frameCallback)
    frameScheduled = false
    val core = egl
    for (target in targets) {
      val surface: EGLSurface? = target.eglSurface
      if (contextAlive) renderer?.releaseTargets(target.gpu) else target.gpu.allocated = false
      if (surface != null && core != null) core.destroySurface(surface)
      target.eglSurface = null
      target.firstFrame.value = false
    }
    if (contextAlive) runCatching { renderer?.release() }
    renderer = null
    runCatching { core?.release() }
    egl = null
  }

  companion object {
    private const val TAG = "EarthEngine"
    const val RELEASE_GRACE_MILLIS = 10_000L
    private const val FRAME_SLACK_NANOS = 2_000_000L

    /** iOS `GlobalPauseSessionController.arrivalTurn` / `arrivalGate`. */
    private const val ARRIVAL_TURN_NANOS = 60_000_000_000L
    private const val ARRIVAL_GATE_SECONDS = 55.0
    private const val ARRIVAL_CORRECTION_FLOOR_SECONDS = 10.0

    /** How far from a tap a country still answers (iOS `handleTap`). */
    private const val TAP_REACH_DEGREES = 6f

    @Volatile
    private var instance: EarthEngine? = null

    fun get(context: Context): EarthEngine =
      instance ?: synchronized(this) {
        instance ?: EarthEngine(context.applicationContext).also { instance = it }
      }

    private fun supportsGles3(context: Context): Boolean {
      val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return false
      return manager.deviceConfigurationInfo.reqGlEsVersion >= 0x30000
    }
  }
}

/**
 * One `TextureView` the engine draws into. Created and owned by the view;
 * every mutable field is touched only on the render thread.
 */
internal class EarthTarget(
  /** 60 fps for the live session's globe, 30 for the resting card's. */
  val frameIntervalNanos: Long,
  /** The share of native resolution rendered (EARTH3D_SPIKE.md §4.5). */
  val renderScale: Float,
) {
  var texture: SurfaceTexture? = null
  var eglSurface: EGLSurface? = null
  var width = 0
  var height = 0
  var active = false
  var lastFrameNanos = 0L
  val gpu = EarthRenderer.Targets()

  /** True once a frame has been presented on the current surface. */
  val firstFrame = MutableStateFlow(false)
}
