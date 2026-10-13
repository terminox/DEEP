package io.appbeyond.freelance.deep.feature.globalpause.globe.earth

import android.content.res.AssetManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.opengl.GLES30
import android.util.Log
import io.appbeyond.freelance.deep.feature.globalpause.earth.EarthFrame
import io.appbeyond.freelance.deep.feature.globalpause.earth.EarthGeometry
import io.appbeyond.freelance.deep.feature.globalpause.earth.EarthGlowSnapshot
import io.appbeyond.freelance.deep.feature.globalpause.earth.EarthTuning
import io.appbeyond.freelance.deep.feature.globalpause.earth.Mat4
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * The Earth's GPU side — iOS's `EarthRenderer`, on OpenGL ES 3.0.
 *
 * Pipeline, per target (EARTH3D_SPIKE.md §2.1):
 *   1. surface  → the target's RGBA16F scene texture (cleared to transparent)
 *   2. threshold: scene → bloom A   (600px-tall reference resolution)
 *   3. blur H:   bloom A → bloom B
 *   4. blur V:   bloom B → bloom A
 *   5. composite: scene + bloom A → the window surface
 * Blending, depth and dithering are off everywhere; the passes that overwrite
 * every pixel invalidate their attachment first so a tiler never restores it.
 *
 * Without a colour-renderable half-float format (`GL_EXT_color_buffer_half_float`
 * or `_float`, probed at start), there is no HDR target to bloom from: the
 * surface pass compiles with `EARTH_DIRECT`, tonemaps itself and draws
 * straight to the window — the spike's rung 5, a real globe without its halo.
 *
 * Uniforms ride three std140 blocks (§3.2), each orphaned and rewritten per
 * draw — GL copies `glBufferSubData` at call time, so nothing here needs the
 * iOS triple-buffer semaphore.
 *
 * Confined to the engine's render thread, with the context current.
 */
internal class EarthRenderer private constructor(
  private val shaders: EarthShaders,
  val hdr: Boolean,
) {

  private lateinit var surface: EarthShaders.Program
  /** The self-tonemapping surface pass: the whole pipeline without half
   * floats, or one target whose half-float attachment the driver refused. */
  private var direct: EarthShaders.Program? = null
  private var threshold: EarthShaders.Program? = null
  private var blur: EarthShaders.Program? = null
  private var composite: EarthShaders.Program? = null

  private var blurDirection = -1
  private var compositeDither = -1
  private var directDither = -1

  private val vao = IntArray(1)
  private val ubos = IntArray(3)
  private val continent = IntArray(1)

  private val frameFloats = FloatArray(EarthFrame.FLOATS)
  private val tuningFloats = FloatArray(EarthTuning.FLOATS)
  private val frameBuffer: FloatBuffer = floatBuffer(EarthFrame.FLOATS)
  private val tuningBuffer: FloatBuffer = floatBuffer(EarthTuning.FLOATS)
  private val glowBuffer: FloatBuffer = floatBuffer(GLOW_FLOATS)

  /** Per-target intermediates, sized to that target. */
  class Targets {
    var width = 0
    var height = 0
    val fbo = IntArray(3)
    val tex = IntArray(3)
    var allocated = false
    var bloomWidth = 0
    var bloomHeight = 0
    /** The size a half-float attachment was refused at — not retried per frame. */
    var refusedWidth = 0
    var refusedHeight = 0
  }

  private fun setUp(assets: AssetManager) {
    if (hdr) {
      surface = shaders.build(EarthShaders.Pass.Surface)
      threshold = shaders.build(EarthShaders.Pass.Threshold)
      blur = shaders.build(EarthShaders.Pass.Blur)
      composite = shaders.build(EarthShaders.Pass.Composite)
    } else {
      surface = directProgram()
    }

    GLES30.glGenBuffers(3, ubos, 0)
    allocateUbo(BINDING_FRAME, EarthFrame.BYTES)
    allocateUbo(BINDING_GLOW, GLOW_FLOATS * 4)
    allocateUbo(BINDING_TUNING, EarthTuning.BYTES)

    bindBlocks(surface, frame = true, glow = true)
    GLES30.glUseProgram(surface.id)
    GLES30.glUniform1i(surface.uniform("continentTex"), 0)
    threshold?.let {
      bindBlocks(it, frame = false, glow = false)
      GLES30.glUseProgram(it.id)
      GLES30.glUniform1i(it.uniform("src"), 0)
    }
    blur?.let {
      bindBlocks(it, frame = false, glow = false)
      GLES30.glUseProgram(it.id)
      GLES30.glUniform1i(it.uniform("src"), 0)
      blurDirection = it.uniform("uDirection")
    }
    composite?.let {
      bindBlocks(it, frame = false, glow = false)
      GLES30.glUseProgram(it.id)
      GLES30.glUniform1i(it.uniform("scene"), 0)
      GLES30.glUniform1i(it.uniform("bloom"), 1)
      compositeDither = it.uniform("uDither")
    }
    GLES30.glUseProgram(0)

    // Attributeless fullscreen triangle: an empty VAO is all the draw needs.
    GLES30.glGenVertexArrays(1, vao, 0)
    loadContinent(assets)
    checkGl("setUp")
  }

  private fun directProgram(): EarthShaders.Program = direct ?: shaders.build(EarthShaders.Pass.SurfaceDirect).also {
    bindBlocks(it, frame = true, glow = true)
    GLES30.glUseProgram(it.id)
    GLES30.glUniform1i(it.uniform("continentTex"), 0)
    directDither = it.uniform("uDither")
    direct = it
  }

  private fun allocateUbo(binding: Int, bytes: Int) {
    GLES30.glBindBuffer(GLES30.GL_UNIFORM_BUFFER, ubos[binding])
    GLES30.glBufferData(GLES30.GL_UNIFORM_BUFFER, bytes, null, GLES30.GL_DYNAMIC_DRAW)
    GLES30.glBindBufferBase(GLES30.GL_UNIFORM_BUFFER, binding, ubos[binding])
    GLES30.glBindBuffer(GLES30.GL_UNIFORM_BUFFER, 0)
  }

  private fun bindBlocks(program: EarthShaders.Program, frame: Boolean, glow: Boolean) {
    fun bind(name: String, binding: Int) {
      val index = program.blockIndex(name)
      if (index == GLES30.GL_INVALID_INDEX) throw EarthShaderException("${program.name} lacks uniform block $name")
      GLES30.glUniformBlockBinding(program.id, index, binding)
    }
    if (frame) bind("EarthUniforms", BINDING_FRAME)
    if (glow) bind("GlowBlock", BINDING_GLOW)
    bind("EarthTuning", BINDING_TUNING)
  }

  /**
   * The equirectangular continent map (black = land), uploaded as GL_R8 —
   * the shader reads only `.r` — with mipmaps, linear (not sRGB), image row 0
   * first so V = 0 is the north pole exactly as on iOS. No ETC2: block
   * artifacts would print through the shader's hard coastline bands
   * (EARTH3D_SPIKE.md §2.8).
   */
  private fun loadContinent(assets: AssetManager) {
    val bitmap = assets.open(CONTINENT_ASSET).use { stream ->
      BitmapFactory.decodeStream(stream, null, BitmapFactory.Options().apply {
        inPreferredConfig = Bitmap.Config.ARGB_8888
        inScaled = false
        inPremultiplied = false
      })
    } ?: throw EarthShaderException("Could not decode $CONTINENT_ASSET")
    val width = bitmap.width
    val height = bitmap.height
    val red = ByteBuffer.allocateDirect(width * height).order(ByteOrder.nativeOrder())
    val row = IntArray(width)
    for (y in 0 until height) {
      bitmap.getPixels(row, 0, width, 0, y, width, 1)
      for (x in 0 until width) red.put(((row[x] shr 16) and 0xFF).toByte())
    }
    bitmap.recycle()
    red.position(0)

    GLES30.glGenTextures(1, continent, 0)
    GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, continent[0])
    GLES30.glPixelStorei(GLES30.GL_UNPACK_ALIGNMENT, 1)
    GLES30.glTexImage2D(GLES30.GL_TEXTURE_2D, 0, GLES30.GL_R8, width, height, 0, GLES30.GL_RED, GLES30.GL_UNSIGNED_BYTE, red)
    GLES30.glGenerateMipmap(GLES30.GL_TEXTURE_2D)
    // Longitude wraps (or the dateline prints a seam); latitude clamps.
    GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_REPEAT)
    GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE)
    GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR_MIPMAP_LINEAR)
    GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
    GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, 0)
  }

  /** Uploads this frame's glow sources — once per frame, shared by every target. */
  fun uploadGlow(glow: EarthGlowSnapshot) {
    val floats = minOf(glow.count, EarthGeometry.MAX_GLOW_SOURCES) * EarthGlowSnapshot.FLOATS_PER_SOURCE
    glowBuffer.clear()
    glowBuffer.put(glow.data, 0, floats)
    glowBuffer.position(0)
    GLES30.glBindBuffer(GLES30.GL_UNIFORM_BUFFER, ubos[BINDING_GLOW])
    GLES30.glBufferData(GLES30.GL_UNIFORM_BUFFER, GLOW_FLOATS * 4, null, GLES30.GL_DYNAMIC_DRAW)
    if (floats > 0) GLES30.glBufferSubData(GLES30.GL_UNIFORM_BUFFER, 0, floats * 4, glowBuffer)
    GLES30.glBindBuffer(GLES30.GL_UNIFORM_BUFFER, 0)
  }

  /**
   * Draws one frame into the current window surface, [width]×[height]
   * rendered pixels. [renderScale] is the target's share of native
   * resolution: the rim and the dither scale with it.
   */
  fun draw(
    targets: Targets,
    width: Int,
    height: Int,
    renderScale: Float,
    time: Float,
    orientation: Mat4,
    glow: EarthGlowSnapshot,
    tuning: EarthTuning,
  ) {
    if (width <= 0 || height <= 0) return
    EarthFrame.pack(frameFloats, time, width.toFloat() / height, height, orientation, glow, tuning)
    val reach = glow.lightVolumeReach(
      sigmaScale = tuning.orbSigmaScale,
      worldUnitsPerPixel = EarthGeometry.worldUnitsPerPixel(height),
      radiusScale = 1f + maxOf(tuning.breathScaleAmp, 0f),
    )
    tuning.pack(tuningFloats, rimScale = renderScale, lightVolumeReach = reach)
    write(BINDING_FRAME, frameBuffer, frameFloats)
    write(BINDING_TUNING, tuningBuffer, tuningFloats)

    GLES30.glDisable(GLES30.GL_DEPTH_TEST)
    GLES30.glDisable(GLES30.GL_BLEND)
    GLES30.glDisable(GLES30.GL_DITHER)
    GLES30.glDisable(GLES30.GL_CULL_FACE)
    GLES30.glDisable(GLES30.GL_SCISSOR_TEST)
    GLES30.glBindVertexArray(vao[0])
    val dither = 1f / renderScale.coerceIn(0.25f, 1f)

    if (hdr && ensureTargets(targets, width, height)) {
      // 1. Surface → scene (HDR), cleared to transparent.
      GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, targets.fbo[SCENE])
      GLES30.glViewport(0, 0, width, height)
      GLES30.glClearColor(0f, 0f, 0f, 0f)
      GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT)
      GLES30.glUseProgram(surface.id)
      bindTexture(0, continent[0])
      GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, 3)

      // 2–4. Bloom at the reference height.
      GLES30.glViewport(0, 0, targets.bloomWidth, targets.bloomHeight)
      postPass(targets, BLOOM_A, threshold!!, source = targets.tex[SCENE])
      postPass(targets, BLOOM_B, blur!!, source = targets.tex[BLOOM_A]) { GLES30.glUniform2f(blurDirection, 1f, 0f) }
      postPass(targets, BLOOM_A, blur!!, source = targets.tex[BLOOM_B]) { GLES30.glUniform2f(blurDirection, 0f, 1f) }

      // 5. Composite → the window.
      GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0)
      GLES30.glViewport(0, 0, width, height)
      GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT)
      GLES30.glUseProgram(composite!!.id)
      GLES30.glUniform1f(compositeDither, dither)
      bindTexture(0, targets.tex[SCENE])
      bindTexture(1, targets.tex[BLOOM_A])
      GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, 3)
      bindTexture(1, 0)
    } else {
      // Rung 5: the surface tonemaps itself, straight to the window.
      GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0)
      GLES30.glViewport(0, 0, width, height)
      GLES30.glClearColor(0f, 0f, 0f, 0f)
      GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT)
      GLES30.glUseProgram(directProgram().id)
      if (directDither >= 0) GLES30.glUniform1f(directDither, dither)
      bindTexture(0, continent[0])
      GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, 3)
    }
    bindTexture(0, 0)
    GLES30.glUseProgram(0)
    GLES30.glBindVertexArray(0)
  }

  private inline fun postPass(
    targets: Targets,
    destination: Int,
    program: EarthShaders.Program,
    source: Int,
    setUniforms: () -> Unit = {},
  ) {
    GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, targets.fbo[destination])
    // Every pixel is overwritten: tell a tiler not to restore the old ones.
    GLES30.glInvalidateFramebuffer(GLES30.GL_FRAMEBUFFER, 1, COLOR_ATTACHMENT, 0)
    GLES30.glUseProgram(program.id)
    setUniforms()
    bindTexture(0, source)
    GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, 3)
  }

  private fun bindTexture(unit: Int, texture: Int) {
    GLES30.glActiveTexture(GLES30.GL_TEXTURE0 + unit)
    GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, texture)
  }

  private fun write(binding: Int, buffer: FloatBuffer, floats: FloatArray) {
    buffer.clear()
    buffer.put(floats)
    buffer.position(0)
    GLES30.glBindBuffer(GLES30.GL_UNIFORM_BUFFER, ubos[binding])
    // Orphan, then write: a driver that would rather synchronise than rename
    // must not stall on the previous frame still reading this buffer.
    GLES30.glBufferData(GLES30.GL_UNIFORM_BUFFER, floats.size * 4, null, GLES30.GL_DYNAMIC_DRAW)
    GLES30.glBufferSubData(GLES30.GL_UNIFORM_BUFFER, 0, floats.size * 4, buffer)
    GLES30.glBindBuffer(GLES30.GL_UNIFORM_BUFFER, 0)
  }

  /**
   * Allocates (or reallocates on resize) the scene and bloom targets. The
   * bloom chain keeps the fixed 600px reference height so the halo is a
   * constant fraction of the view at any size. False if the driver refuses a
   * half-float attachment at this size — the frame then draws direct.
   */
  private fun ensureTargets(targets: Targets, width: Int, height: Int): Boolean {
    if (targets.allocated && targets.width == width && targets.height == height) return true
    if (targets.refusedWidth == width && targets.refusedHeight == height) return false
    releaseTargets(targets)
    val (bloomWidth, bloomHeight) = EarthGeometry.bloomSize(width, height)
    GLES30.glGenTextures(3, targets.tex, 0)
    GLES30.glGenFramebuffers(3, targets.fbo, 0)
    val sizes = arrayOf(width to height, bloomWidth to bloomHeight, bloomWidth to bloomHeight)
    for (i in 0 until 3) {
      val (w, h) = sizes[i]
      GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, targets.tex[i])
      GLES30.glTexImage2D(GLES30.GL_TEXTURE_2D, 0, GLES30.GL_RGBA16F, w, h, 0, GLES30.GL_RGBA, GLES30.GL_HALF_FLOAT, null)
      GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR)
      GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR)
      GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE)
      GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE)
      GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, targets.fbo[i])
      GLES30.glFramebufferTexture2D(GLES30.GL_FRAMEBUFFER, GLES30.GL_COLOR_ATTACHMENT0, GLES30.GL_TEXTURE_2D, targets.tex[i], 0)
      val status = GLES30.glCheckFramebufferStatus(GLES30.GL_FRAMEBUFFER)
      if (status != GLES30.GL_FRAMEBUFFER_COMPLETE) {
        Log.w(TAG, "RGBA16F target ${w}x$h incomplete (0x${Integer.toHexString(status)}); drawing direct")
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0)
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, 0)
        targets.allocated = true
        releaseTargets(targets)
        targets.refusedWidth = width
        targets.refusedHeight = height
        return false
      }
    }
    GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0)
    GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, 0)
    targets.width = width
    targets.height = height
    targets.bloomWidth = bloomWidth
    targets.bloomHeight = bloomHeight
    targets.allocated = true
    return true
  }

  fun releaseTargets(targets: Targets) {
    if (!targets.allocated) return
    GLES30.glDeleteFramebuffers(3, targets.fbo, 0)
    GLES30.glDeleteTextures(3, targets.tex, 0)
    targets.fbo.fill(0)
    targets.tex.fill(0)
    targets.allocated = false
    targets.width = 0
    targets.height = 0
  }

  /** Frees every GL object this renderer made. The context must be current. */
  fun release() {
    listOfNotNull(surface, direct, threshold, blur, composite).distinct().forEach { GLES30.glDeleteProgram(it.id) }
    GLES30.glDeleteBuffers(3, ubos, 0)
    GLES30.glDeleteVertexArrays(1, vao, 0)
    GLES30.glDeleteTextures(1, continent, 0)
  }

  companion object {
    private const val TAG = "EarthRenderer"
    const val CONTINENT_ASSET = "earth/earth_specular_2048.jpg"

    private const val BINDING_FRAME = 0
    private const val BINDING_GLOW = 1
    private const val BINDING_TUNING = 2

    /** `vec4 glowData[128]`: 64 sources × 2 vec4 = 512 floats, 2048 bytes. */
    private const val GLOW_FLOATS = EarthGeometry.MAX_GLOW_SOURCES * EarthGlowSnapshot.FLOATS_PER_SOURCE

    private const val SCENE = 0
    private const val BLOOM_A = 1
    private const val BLOOM_B = 2
    private val COLOR_ATTACHMENT = intArrayOf(GLES30.GL_COLOR_ATTACHMENT0)

    /**
     * Builds the renderer on the current context. Probes the half-float
     * colour target first (extension AND a complete framebuffer — some
     * drivers advertise and still refuse), then compiles. Throws
     * [EarthShaderException] with the driver's log on any build failure.
     */
    fun create(assets: AssetManager): EarthRenderer {
      val hdr = probeHalfFloatTarget()
      if (!hdr) Log.w(TAG, "No colour-renderable RGBA16F: the globe draws without bloom")
      return EarthRenderer(EarthShaders(assets), hdr).also { it.setUp(assets) }
    }

    private fun probeHalfFloatTarget(): Boolean {
      val extensions = GLES30.glGetString(GLES30.GL_EXTENSIONS).orEmpty()
      val advertised = "GL_EXT_color_buffer_half_float" in extensions || "GL_EXT_color_buffer_float" in extensions
      if (!advertised) return false
      val tex = IntArray(1)
      val fbo = IntArray(1)
      GLES30.glGenTextures(1, tex, 0)
      GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, tex[0])
      GLES30.glTexImage2D(GLES30.GL_TEXTURE_2D, 0, GLES30.GL_RGBA16F, 4, 4, 0, GLES30.GL_RGBA, GLES30.GL_HALF_FLOAT, null)
      GLES30.glGenFramebuffers(1, fbo, 0)
      GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, fbo[0])
      GLES30.glFramebufferTexture2D(GLES30.GL_FRAMEBUFFER, GLES30.GL_COLOR_ATTACHMENT0, GLES30.GL_TEXTURE_2D, tex[0], 0)
      val complete = GLES30.glCheckFramebufferStatus(GLES30.GL_FRAMEBUFFER) == GLES30.GL_FRAMEBUFFER_COMPLETE
      GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0)
      GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, 0)
      GLES30.glDeleteFramebuffers(1, fbo, 0)
      GLES30.glDeleteTextures(1, tex, 0)
      while (GLES30.glGetError() != GLES30.GL_NO_ERROR) Unit
      return complete
    }

    private fun floatBuffer(floats: Int): FloatBuffer =
      ByteBuffer.allocateDirect(floats * 4).order(ByteOrder.nativeOrder()).asFloatBuffer()

    private fun checkGl(where: String) {
      val error = GLES30.glGetError()
      if (error != GLES30.GL_NO_ERROR) throw EarthShaderException("GL error 0x${Integer.toHexString(error)} in $where")
    }
  }
}
