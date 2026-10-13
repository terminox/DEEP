package io.appbeyond.freelance.deep.feature.compassion.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.compassion.CompassionIcons
import io.appbeyond.freelance.deep.shared.components.RollingText
import io.appbeyond.freelance.deep.shared.localization.AppFormat
import io.appbeyond.freelance.deep.shared.localization.rememberAppLocale
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.moonCream

/** Over the dark hero the pill is a translucent plum wash — the stand-in for
 * iOS's `.ultraThinMaterial`, which has no minSdk-26 equivalent. */
private const val OVER_HERO_FILL_ALPHA = 0.22f
private const val PALE_FILL_ALPHA = 0.65f
private const val RIM_ALPHA = 0.4f

/**
 * The running "My Hearts" balance as a soft pill. The count rolls when hearts
 * are sent, so giving is felt in the chrome as well as the cause.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Components/HeartBalanceChip.swift.
 *
 * @param overDarkHero the lighter treatment for a chip over hero artwork.
 */
@Composable
fun HeartBalanceChip(balance: Int, modifier: Modifier = Modifier, overDarkHero: Boolean = false) {
  val locale = rememberAppLocale()
  val label = stringResource(R.string.compassion_balance_chip)
  val shape = RoundedCornerShape(Dp.chip)
  Row(
    modifier
      .background(
        if (overDarkHero) Color.deepPlum.copy(alpha = OVER_HERO_FILL_ALPHA) else Color.White.copy(alpha = PALE_FILL_ALPHA),
        shape,
      )
      .border(0.5.dp, Color.White.copy(alpha = RIM_ALPHA), shape)
      .padding(horizontal = 12.dp, vertical = 8.dp)
      .clearAndSetSemantics { contentDescription = "$label, $balance" },
    horizontalArrangement = Arrangement.spacedBy(6.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Icon(CompassionIcons.HeartFill, contentDescription = null, tint = Color.blushPowder, modifier = Modifier.size(12.dp))
    RollingText(
      text = AppFormat.number(balance, locale),
      value = balance.toFloat(),
      style = FactFigureStyle,
      color = if (overDarkHero) Color.White else Color.deepPlum,
    )
  }
}

@Preview(showBackground = true, name = "Heart balance chip")
@Composable
private fun HeartBalanceChipPreview() {
  Row(
    Modifier.background(Color.moonCream).padding(16.dp),
    horizontalArrangement = Arrangement.spacedBy(16.dp),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    HeartBalanceChip(balance = 2_450)
    HeartBalanceChip(
      balance = 2_450,
      overDarkHero = true,
      modifier = Modifier.background(Color.deepPlum).padding(8.dp),
    )
  }
}
