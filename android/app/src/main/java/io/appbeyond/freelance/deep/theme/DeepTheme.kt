package io.appbeyond.freelance.deep.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.ProvideTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview

/**
 * Deep's theme root.
 *
 * Ported from Deep/Deep/Theme/DeepTheme.swift, which pins
 * `.preferredColorScheme(.light)` everywhere — [DeepColor]'s palette has no
 * dark variant, so there is nothing to switch on here either.
 *
 * This deliberately does **not** wrap [content] in a Material `colorScheme`.
 * Doing so would hand every stock Material3 component (`Button`, `Text`,
 * `Surface`, …) a set of Material defaults to fall back on — exactly what the
 * token files in this package exist to prevent. Only the two composition
 * locals a plain `Text` actually reads are set: [LocalContentColor], for
 * anything that doesn't specify its own colour, and the default `TextStyle`
 * via [ProvideTextStyle].
 */
@Composable
fun DeepTheme(content: @Composable () -> Unit) {
  CompositionLocalProvider(LocalContentColor provides Color.deepPlum) {
    ProvideTextStyle(value = DeepType.body) {
      content()
    }
  }
}

@Preview(showBackground = true)
@Composable
private fun DeepThemePreview() {
  DeepTheme {
    Box(
      modifier = Modifier
        .fillMaxSize()
        .background(Color.moonCream),
      contentAlignment = Alignment.Center,
    ) {
      // No explicit colour or style passed — this is what proves both
      // composition locals this theme sets are actually reaching a plain Text.
      Text("Every Text inherits deepPlum + body from here.")
    }
  }
}
