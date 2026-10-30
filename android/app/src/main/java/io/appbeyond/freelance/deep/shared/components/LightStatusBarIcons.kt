package io.appbeyond.freelance.deep.shared.components

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

/**
 * Light status-bar icons while [enabled] — for a screen laid over something
 * dark (the Global Pause night sky, Now Playing's photograph), where DEEP's
 * light theme would draw a dark clock across it. Whatever the icons were
 * before is restored when [enabled] turns off or the caller leaves.
 *
 * iOS's `preferredStatusBarStyle` (`LightStatusBarHostingController`), which
 * is owned by the presenting controller; here it is owned by the composable
 * that needs it.
 */
@Composable
fun LightStatusBarIcons(enabled: Boolean = true) {
  val view = LocalView.current
  if (view.isInEditMode) return
  DisposableEffect(enabled) {
    val window = view.context.findActivity()?.window
    val controller = window?.let { WindowCompat.getInsetsController(it, view) }
    val before = controller?.isAppearanceLightStatusBars
    controller?.isAppearanceLightStatusBars = !enabled
    onDispose { if (before != null) controller.isAppearanceLightStatusBars = before }
  }
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
  is Activity -> this
  is ContextWrapper -> baseContext.findActivity()
  else -> null
}
