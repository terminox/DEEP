package io.appbeyond.freelance.deep.feature.globalpause.globe.earth

import android.graphics.SurfaceTexture
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface

/**
 * One EGL display, one OpenGL ES 3.0 context, and the window surfaces the
 * Earth renders into — the boilerplate `GLSurfaceView` would have supplied,
 * which hosting in a `TextureView` gives up (EARTH3D_SPIKE.md §2.6).
 *
 * One context serves every globe on screen, so the card's globe and the
 * session's share their programs, textures and buffers; each `TextureView`
 * is just another window surface made current in turn. A 1×1 pbuffer keeps
 * the context current while no window surface exists — between the card
 * leaving and the session arriving, and while the shaders build.
 *
 * Confined to the engine's render thread.
 */
internal class EglCore private constructor(
  private val display: EGLDisplay,
  private val config: EGLConfig,
  private val context: EGLContext,
  private val idleSurface: EGLSurface,
) {

  fun makeIdleCurrent() {
    EGL14.eglMakeCurrent(display, idleSurface, idleSurface, context)
  }

  /** A window surface for [texture], or null if EGL refuses it (logged by the caller). */
  fun createWindowSurface(texture: SurfaceTexture): EGLSurface? {
    val surface = EGL14.eglCreateWindowSurface(display, config, texture, intArrayOf(EGL14.EGL_NONE), 0)
    return surface.takeIf { it != EGL14.EGL_NO_SURFACE }
  }

  fun makeCurrent(surface: EGLSurface): Boolean = EGL14.eglMakeCurrent(display, surface, surface, context)

  /** Presents; false with [lastError] set when the surface or context is gone. */
  fun swap(surface: EGLSurface): Boolean = EGL14.eglSwapBuffers(display, surface)

  fun destroySurface(surface: EGLSurface) {
    // Never leave a dying surface current.
    makeIdleCurrent()
    EGL14.eglDestroySurface(display, surface)
  }

  val lastError: Int get() = EGL14.eglGetError()

  fun release() {
    EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
    EGL14.eglDestroySurface(display, idleSurface)
    EGL14.eglDestroyContext(display, context)
    EGL14.eglReleaseThread()
    EGL14.eglTerminate(display)
  }

  companion object {
    /** EGL_KHR_create_context's ES 3 renderable bit (EGLExt.EGL_OPENGL_ES3_BIT_KHR). */
    private const val EGL_OPENGL_ES3_BIT = 0x40

    /** Builds the core and makes it current, or throws with the EGL error. */
    fun create(): EglCore {
      val display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
      if (display == EGL14.EGL_NO_DISPLAY) throw EglException("No EGL display")
      val version = IntArray(2)
      if (!EGL14.eglInitialize(display, version, 0, version, 1)) throw EglException("eglInitialize", EGL14.eglGetError())

      // RGBA8888 with alpha — the globe is transparent outside the orb — and
      // no depth or stencil: every pass is a fullscreen triangle.
      val attributes = intArrayOf(
        EGL14.EGL_RED_SIZE, 8,
        EGL14.EGL_GREEN_SIZE, 8,
        EGL14.EGL_BLUE_SIZE, 8,
        EGL14.EGL_ALPHA_SIZE, 8,
        EGL14.EGL_DEPTH_SIZE, 0,
        EGL14.EGL_STENCIL_SIZE, 0,
        EGL14.EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT or EGL14.EGL_PBUFFER_BIT,
        EGL14.EGL_NONE,
      )
      val configs = arrayOfNulls<EGLConfig>(1)
      val count = IntArray(1)
      if (!EGL14.eglChooseConfig(display, attributes, 0, configs, 0, 1, count, 0) || count[0] == 0) {
        EGL14.eglTerminate(display)
        throw EglException("No RGBA8888 OpenGL ES 3 config", EGL14.eglGetError())
      }
      val config = configs[0]!!

      val context = EGL14.eglCreateContext(
        display, config, EGL14.EGL_NO_CONTEXT,
        intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE), 0,
      )
      if (context == EGL14.EGL_NO_CONTEXT) {
        val error = EGL14.eglGetError()
        EGL14.eglTerminate(display)
        throw EglException("eglCreateContext (ES 3)", error)
      }

      val idle = EGL14.eglCreatePbufferSurface(
        display, config, intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0,
      )
      if (idle == EGL14.EGL_NO_SURFACE) {
        val error = EGL14.eglGetError()
        EGL14.eglDestroyContext(display, context)
        EGL14.eglTerminate(display)
        throw EglException("eglCreatePbufferSurface", error)
      }
      return EglCore(display, config, context, idle).also { core ->
        if (!EGL14.eglMakeCurrent(display, idle, idle, context)) {
          val error = EGL14.eglGetError()
          core.release()
          throw EglException("eglMakeCurrent", error)
        }
      }
    }
  }
}

internal class EglException(message: String, error: Int? = null) :
  RuntimeException(if (error != null) "$message (EGL 0x${Integer.toHexString(error)})" else message)
