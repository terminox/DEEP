package io.appbeyond.freelance.deep.feature.appshell

import androidx.annotation.StringRes
import androidx.compose.ui.graphics.vector.ImageVector
import io.appbeyond.freelance.deep.R

/**
 * The app's five tabs, in bar order.
 *
 * Matching `MainTabController.Tab` on iOS — including that the first tab is
 * labelled **Home** while its content is Global Pause. That is deliberate on
 * both platforms: the world's pause is the first thing you see, so it takes the
 * home slot rather than a tab of its own.
 */
enum class DeepTab(
  @StringRes val label: Int,
  val icon: ImageVector,
) {
  Home(R.string.tab_home, DeepIcons.Globe),
  Sounds(R.string.tab_sounds, DeepIcons.Waveform),
  Garden(R.string.tab_garden, DeepIcons.Leaf),
  Compassion(R.string.tab_compassion, DeepIcons.Heart),
  You(R.string.tab_you, DeepIcons.Person),
}
