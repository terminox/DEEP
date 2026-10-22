package io.appbeyond.freelance.deep.feature.globalpause.globe.earth

import android.content.res.AssetManager
import android.opengl.GLES30
import android.util.Log
import androidx.compose.ui.graphics.Color
import io.appbeyond.freelance.deep.BuildConfig
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.peachCloud
import io.appbeyond.freelance.deep.theme.skyWash
import io.appbeyond.freelance.deep.theme.softLilac
import java.util.Locale

/**
 * Loads the Earth's GLSL from `assets/earth/` and builds its programs.
 *
 * GLSL ES has no `#include`, so each program is assembled here from chunks:
 * the [prelude] (version, highp defaults), the palette — generated from the
 * DEEP colour tokens, so the shader can never drift from `DeepColor.kt` the
 * way iOS's hand-copied Metal constants could — the tuning block, and the
 * pass itself. The scratch validator that checks these sources with
 * `glslangValidator` assembles them in exactly this order.
 *
 * A compile or link failure throws [EarthShaderException] carrying the
 * driver's info log, which the engine logs before falling back to the 2D
 * globe. Must run on the thread holding the GL context.
 */
internal class EarthShaders(private val assets: AssetManager) {

  /** One linked program and its handle. */
  class Program(val id: Int, val name: String) {
    fun uniform(name: String): Int = GLES30.glGetUniformLocation(id, name)
    fun blockIndex(name: String): Int = GLES30.glGetUniformBlockIndex(id, name)
  }

  enum class Pass(val fragment: List<String>, val defines: String = "") {
    Surface(listOf(PALETTE, "earth_tuning.glsl", "earth_surface.frag")),
    SurfaceDirect(listOf(PALETTE, "earth_tuning.glsl", "earth_tonemap.glsl", "earth_surface.frag"), "#define EARTH_DIRECT 1\n"),
    Threshold(listOf("earth_tuning.glsl", "earth_bloom_threshold.frag")),
    Blur(listOf("earth_tuning.glsl", "earth_bloom_blur.frag")),
    Composite(listOf("earth_tuning.glsl", "earth_tonemap.glsl", "earth_composite.frag")),
  }

  private val sources = HashMap<String, String>()

  private fun source(chunk: String): String = when (chunk) {
    PALETTE -> palette
    else -> sources.getOrPut(chunk) { assets.open("earth/$chunk").bufferedReader().use { it.readText() } }
  }

  fun build(pass: Pass): Program {
    val vertex = compile(GLES30.GL_VERTEX_SHADER, "earth_fullscreen.vert", PRELUDE + source("earth_fullscreen.vert"))
    val fragmentSource = PRELUDE + pass.defines + pass.fragment.joinToString("") { source(it) }
    val fragment = try {
      compile(GLES30.GL_FRAGMENT_SHADER, pass.name, fragmentSource)
    } catch (e: EarthShaderException) {
      GLES30.glDeleteShader(vertex)
      throw e
    }
    val program = GLES30.glCreateProgram()
    GLES30.glAttachShader(program, vertex)
    GLES30.glAttachShader(program, fragment)
    GLES30.glLinkProgram(program)
    // Shaders can go once linked; the program keeps what it needs.
    GLES30.glDetachShader(program, vertex)
    GLES30.glDetachShader(program, fragment)
    GLES30.glDeleteShader(vertex)
    GLES30.glDeleteShader(fragment)
    val status = IntArray(1)
    GLES30.glGetProgramiv(program, GLES30.GL_LINK_STATUS, status, 0)
    if (status[0] == 0) {
      val log = GLES30.glGetProgramInfoLog(program)
      GLES30.glDeleteProgram(program)
      throw EarthShaderException("Link failed for ${pass.name}: $log")
    }
    return Program(program, pass.name)
  }

  private fun compile(type: Int, name: String, source: String): Int {
    val shader = GLES30.glCreateShader(type)
    if (shader == 0) throw EarthShaderException("glCreateShader failed for $name (0x${Integer.toHexString(GLES30.glGetError())})")
    GLES30.glShaderSource(shader, source)
    GLES30.glCompileShader(shader)
    val status = IntArray(1)
    GLES30.glGetShaderiv(shader, GLES30.GL_COMPILE_STATUS, status, 0)
    if (status[0] == 0) {
      val log = GLES30.glGetShaderInfoLog(shader)
      GLES30.glDeleteShader(shader)
      throw EarthShaderException("Compile failed for $name: $log")
    }
    if (BuildConfig.DEBUG) {
      GLES30.glGetShaderInfoLog(shader).takeIf { it.isNotBlank() }?.let { Log.w(TAG, "$name: $it") }
    }
    return shader
  }

  companion object {
    private const val TAG = "EarthShaders"
    private const val PALETTE = "<palette>"

    const val PRELUDE = "#version 300 es\n" +
      "precision highp float;\n" +
      "precision highp int;\n" +
      // ES 3.00's default sampler precision in a fragment shader is lowp:
      // an RGBA16F bloom target read through it would quantise to ~8 bits.
      "precision highp sampler2D;\n"

    /** The shader's palette, projected from the colour tokens. */
    val palette: String by lazy {
      listOf(
        "LAVENDER_MIST" to Color.lavenderMist,
        "SOFT_LILAC" to Color.softLilac,
        "BLUSH_POWDER" to Color.blushPowder,
        "SKY_WASH" to Color.skyWash,
        "PEACH_CLOUD" to Color.peachCloud,
        "MOON_CREAM" to Color.moonCream,
        "DEEP_PLUM" to Color.deepPlum,
      ).joinToString("") { (name, color) ->
        String.format(Locale.US, "const vec3 %s = vec3(%.6f, %.6f, %.6f);\n", name, color.red, color.green, color.blue)
      }
    }
  }
}

/** A shader that would not compile or link; the message carries the driver's log. */
internal class EarthShaderException(message: String) : RuntimeException(message)
