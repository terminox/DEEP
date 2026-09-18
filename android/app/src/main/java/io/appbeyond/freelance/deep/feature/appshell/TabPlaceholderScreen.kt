package io.appbeyond.freelance.deep.feature.appshell

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.lavenderMist

/**
 * What the four tabs that have not been built yet show in `v0.0.1`.
 *
 * Deliberately **not** a "coming soon" plate. Each names the thing that is coming
 * in the app's own voice, so an early build reads as a product with rooms still
 * being furnished rather than as a scaffold with holes in it. The copy lives in
 * `strings.xml` and is the real copy — it does not get replaced, it gets
 * surrounded.
 *
 * Each paints its own atmosphere, because the coordinator deliberately carries
 * no styling.
 */
@Composable
fun TabPlaceholderScreen(tab: DeepTab, modifier: Modifier = Modifier) {
  val (title, body) = tab.placeholderCopy()

  Box(modifier.fillMaxSize()) {
    AtmosphereBackground()

    Column(
      modifier = Modifier
        .fillMaxSize()
        .statusBarsPadding()
        .padding(horizontal = Dp.edge),
      verticalArrangement = Arrangement.Center,
      horizontalAlignment = Alignment.CenterHorizontally,
    ) {
      Icon(
        imageVector = tab.icon,
        contentDescription = null,
        tint = Color.lavenderMist.copy(alpha = 0.55f),
        modifier = Modifier.size(44.dp),
      )

      Text(
        text = stringResource(title),
        style = DeepType.displayTitle,
        color = Color.deepPlum,
        textAlign = TextAlign.Center,
        modifier = Modifier.padding(top = 20.dp),
      )

      Text(
        text = stringResource(body),
        style = DeepType.body,
        color = Color.driftGrey,
        textAlign = TextAlign.Center,
        modifier = Modifier.padding(top = 10.dp, start = 12.dp, end = 12.dp),
      )
    }
  }
}

private fun DeepTab.placeholderCopy(): Pair<Int, Int> = when (this) {
  DeepTab.Sounds -> R.string.placeholder_sounds_title to R.string.placeholder_sounds_body
  DeepTab.Garden -> R.string.placeholder_garden_title to R.string.placeholder_garden_body
  DeepTab.Compassion -> R.string.placeholder_compassion_title to R.string.placeholder_compassion_body
  DeepTab.You -> R.string.placeholder_you_title to R.string.placeholder_you_body
  // Home is never a placeholder; it ships its feed in v0.0.1.
  DeepTab.Home -> R.string.placeholder_sounds_title to R.string.placeholder_sounds_body
}

@Preview(showBackground = true)
@Composable
private fun TabPlaceholderGardenPreview() {
  DeepTheme { TabPlaceholderScreen(DeepTab.Garden) }
}

@Preview(showBackground = true, name = "Compassion")
@Composable
private fun TabPlaceholderCompassionPreview() {
  DeepTheme { TabPlaceholderScreen(DeepTab.Compassion) }
}
