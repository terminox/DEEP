package io.appbeyond.freelance.deep.feature.appshell

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm

/**
 * Deep's own bottom bar.
 *
 * Not `NavigationBar`. The bar frames every screen in the app, and stock Material
 * is the fastest way to make this look like a different product — so it is built
 * from Deep's tokens instead. It is also not a reproduction of the iOS 26 Liquid
 * Glass bar, which is an OS affordance rather than a design: Android gets the
 * same *language* through its own mechanics.
 *
 * Two constraints shaped it. There is **no hairline or divider** above the bar —
 * a standing rule on this project — so it separates from the content with a soft
 * upward lavender bloom instead. And there is **no blur**, because
 * `Modifier.blur` is a no-op below API 31 and the floor here is 26; the bar sits
 * on near-opaque moonCream and lets the bloom do the lifting.
 */
@Composable
fun DeepBottomBar(
  selected: DeepTab,
  onSelect: (DeepTab) -> Unit,
  modifier: Modifier = Modifier,
) {
  Column(modifier.fillMaxWidth()) {
    // The separation, as light rather than as a line.
    Box(
      Modifier
        .fillMaxWidth()
        .height(Dp_BLOOM)
        .background(
          Brush.verticalGradient(
            listOf(Color.lavenderMist.copy(alpha = 0f), Color.lavenderMist.copy(alpha = 0.10f))
          )
        )
    )

    Row(
      Modifier
        .fillMaxWidth()
        .background(Color.moonCream.copy(alpha = 0.96f))
        .navigationBarsPadding()
        .padding(top = 10.dp, bottom = 10.dp),
      horizontalArrangement = Arrangement.SpaceEvenly,
      verticalAlignment = Alignment.CenterVertically,
    ) {
      DeepTab.entries.forEach { tab ->
        DeepTabItem(
          tab = tab,
          isSelected = tab == selected,
          onSelect = { onSelect(tab) },
        )
      }
    }
  }
}

@Composable
private fun DeepTabItem(
  tab: DeepTab,
  isSelected: Boolean,
  onSelect: () -> Unit,
) {
  // An unselected tab recedes rather than greying out — it is still an
  // invitation, not a disabled control.
  val tint by animateColorAsState(
    targetValue = if (isSelected) Color.lavenderMist else Color.driftGrey.copy(alpha = 0.55f),
    animationSpec = exhale(),
    label = "tab-tint",
  )
  val labelColour by animateColorAsState(
    targetValue = if (isSelected) Color.deepPlum else Color.driftGrey.copy(alpha = 0.7f),
    animationSpec = exhale(),
    label = "tab-label",
  )

  val label = stringResource(tab.label)
  val interaction = remember { MutableInteractionSource() }

  Column(
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.spacedBy(4.dp),
    modifier = Modifier
      .selectable(
        selected = isSelected,
        onClick = onSelect,
        role = Role.Tab,
        interactionSource = interaction,
        // No ripple: a Material ripple is the one gesture in the app that
        // would startle. The tint shift is the feedback.
        indication = null,
      )
      .padding(horizontal = Dp_ITEM_H, vertical = 4.dp),
  ) {
    Icon(
      imageVector = tab.icon,
      contentDescription = label,
      tint = tint,
      modifier = Modifier.size(24.dp),
    )
    Text(text = label, style = DeepType.micro, color = labelColour)
  }
}

private val Dp_BLOOM = 12.dp
private val Dp_ITEM_H = 8.dp

@Preview(showBackground = true, backgroundColor = 0xFFFBF7FF)
@Composable
private fun DeepBottomBarPreview() {
  Column(verticalArrangement = Arrangement.spacedBy(androidx.compose.ui.unit.Dp.rhythm)) {
    DeepBottomBar(selected = DeepTab.Home, onSelect = {})
    DeepBottomBar(selected = DeepTab.Garden, onSelect = {})
  }
}
