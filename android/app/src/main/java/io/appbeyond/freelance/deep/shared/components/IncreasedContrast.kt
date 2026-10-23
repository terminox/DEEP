package io.appbeyond.freelance.deep.shared.components

import android.app.UiModeManager
import android.content.Context
import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalInspectionMode

/**
 * Whether the member has asked for more contrast. This is Android's twin of
 * iOS's `colorSchemeContrast == .increased`.
 *
 * The signal is the system's colour-contrast level (Settings → Accessibility →
 * Colour and motion → Colour contrast), which `UiModeManager` exposes from
 * Android 14. Both the medium and the high level count as increased, because
 * iOS has only the one step. Below 14 there is no public signal, so the answer
 * is always false and the standard look applies. "High contrast text" is a
 * different setting: the system applies it to text by itself, and an app
 * can't read it.
 *
 * Observed live, like [rememberReduceMotion], because the level is changed in
 * the system's settings while DEEP stays open behind them.
 */
@Composable
fun rememberIncreasedContrast(): Boolean {
  if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return false
  val context = LocalContext.current
  val uiModeManager = remember(context) { context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager }
  var increased by remember(uiModeManager) { mutableStateOf(uiModeManager.contrast > 0f) }
  val observes = !LocalInspectionMode.current
  DisposableEffect(uiModeManager, observes) {
    if (!observes) return@DisposableEffect onDispose {}
    val listener = UiModeManager.ContrastChangeListener { level -> increased = level > 0f }
    uiModeManager.addContrastChangeListener(context.mainExecutor, listener)
    // Picks up a change made between the first read and registering.
    increased = uiModeManager.contrast > 0f
    onDispose { uiModeManager.removeContrastChangeListener(listener) }
  }
  return increased
}
