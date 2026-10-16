package io.appbeyond.freelance.deep.feature.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.LocalMiniPlayerClearance
import io.appbeyond.freelance.deep.shared.localization.AppLanguage
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm

/**
 * The language picker, pushed from Settings.
 *
 * Ported from Deep/Deep/Features/Profile/LanguageView.swift. Two rows and no
 * symbol column — every row is the same kind of choice — each named in its
 * own language, the one labelling that stays legible whichever language the
 * screen is showing. No "follow the device" row: DEEP does that until someone
 * picks, so the device's language simply arrives checked.
 *
 * The already-checked row is still a real tap: it pins a language that was so
 * far only matching the device. Choosing one recreates the screen in it.
 */
@Composable
fun LanguageScreen(
  selection: AppLanguage,
  onSelect: (AppLanguage) -> Unit,
  onBack: () -> Unit,
  modifier: Modifier = Modifier,
) {
  Box(modifier.fillMaxSize()) {
    AtmosphereBackground()
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
      SettingsTopBar(title = stringResource(R.string.language_title), onBack = onBack)
      Column(
        Modifier
          .fillMaxSize()
          .verticalScroll(rememberScrollState())
          .padding(horizontal = Dp.edge)
          .padding(top = Dp.rhythm, bottom = 40.dp + LocalMiniPlayerClearance.current),
        verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
      ) {
        SettingsSection {
          AppLanguage.entries.forEach { language ->
            val chosen = language == selection
            SettingsRow(
              title = language.endonym,
              accessory = if (chosen) SettingsAccessory.Check else SettingsAccessory.None,
              onClick = { onSelect(language) },
              modifier = Modifier.semantics { selected = chosen },
            )
          }
        }
        Text(
          text = stringResource(R.string.language_footnote),
          style = DeepType.caption,
          color = Color.driftGrey,
          modifier = Modifier.padding(horizontal = 8.dp),
        )
      }
    }
  }
}

@Preview(showBackground = true, name = "Language — English")
@Composable
private fun LanguageScreenPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      LanguageScreen(selection = AppLanguage.English, onSelect = {}, onBack = {})
    }
  }
}

@Preview(showBackground = true, name = "Language — Thai", locale = "th")
@Composable
private fun LanguageScreenThaiPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      LanguageScreen(selection = AppLanguage.Thai, onSelect = {}, onBack = {})
    }
  }
}
