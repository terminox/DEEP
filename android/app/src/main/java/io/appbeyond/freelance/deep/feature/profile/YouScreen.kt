package io.appbeyond.freelance.deep.feature.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.appshell.DeepIcons
import io.appbeyond.freelance.deep.feature.onboarding.store.AccountStore
import io.appbeyond.freelance.deep.feature.onboarding.store.MockAccountStore
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm

// MARK: - Constants

/** iOS `PinnedHomeHeader`: `.padding(.top, 6)` / `.padding(.bottom, 10)`. */
private val HEADER_PADDING_TOP = 6.dp
private val HEADER_PADDING_BOTTOM = 10.dp

/** Air above the note, so it lands in an empty room rather than under the header. */
private val NOTE_TOP_AIR = 72.dp
private val NOTE_GLYPH = 44.dp
private const val NOTE_GLYPH_ALPHA = 0.55f

// MARK: - Screen

/**
 * The You tab's root, for now.
 *
 * On iOS this tab opens on the saved-sounds playlist (`PlaylistView`), with
 * Settings behind a gear in the pinned header. Saved sounds arrive with the
 * sound player later in the port, so this keeps the header's shape — wordmark
 * title, a caption beneath, the frosted control trailing — and in place of the
 * list sits the tab's own "rooms being furnished" note from `strings.xml`,
 * plus Settings as a plain row, so the way in is unmissable while the gear is
 * the only other thing on screen.
 *
 * A leaf: navigation arrives as [onOpenSettings], and `MainShellCoordinator`
 * owns the stack it pushes onto.
 */
@Composable
fun YouScreen(
  accountStore: AccountStore,
  onOpenSettings: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val account by accountStore.account.collectAsStateWithLifecycle()
  val name = account?.displayName ?: stringResource(R.string.settings_friend)

  Box(modifier.fillMaxSize()) {
    AtmosphereBackground()

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
      Row(
        Modifier
          .fillMaxWidth()
          .padding(horizontal = Dp.edge)
          .padding(top = HEADER_PADDING_TOP, bottom = HEADER_PADDING_BOTTOM),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
      ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
          Text(stringResource(R.string.you_title), style = DeepType.wordmark, color = Color.deepPlum)
          Text(
            text = stringResource(R.string.you_greeting, name),
            style = DeepType.caption,
            color = Color.driftGrey,
            maxLines = 1,
          )
        }
        HeaderIconButton(
          icon = ProfileIcons.Sliders,
          contentDescription = stringResource(R.string.you_open_settings),
          onClick = onOpenSettings,
        )
      }

      Column(
        Modifier
          .fillMaxSize()
          .verticalScroll(rememberScrollState())
          .padding(horizontal = Dp.edge)
          .padding(top = Dp.rhythm, bottom = Dp.rhythm),
        horizontalAlignment = Alignment.CenterHorizontally,
      ) {
        Icon(
          imageVector = DeepIcons.Person,
          contentDescription = null,
          tint = Color.lavenderMist.copy(alpha = NOTE_GLYPH_ALPHA),
          modifier = Modifier.padding(top = NOTE_TOP_AIR).size(NOTE_GLYPH),
        )
        Text(
          text = stringResource(R.string.placeholder_you_title),
          style = DeepType.displayTitle,
          color = Color.deepPlum,
          textAlign = TextAlign.Center,
          modifier = Modifier.padding(top = 20.dp),
        )
        Text(
          text = stringResource(R.string.placeholder_you_body),
          style = DeepType.body,
          color = Color.driftGrey,
          textAlign = TextAlign.Center,
          modifier = Modifier.padding(top = 10.dp, start = 12.dp, end = 12.dp),
        )

        SettingsSection(Modifier.padding(top = Dp.rhythm * 2)) {
          SettingsRow(
            title = stringResource(R.string.you_open_settings),
            icon = ProfileIcons.Sliders,
            accessory = SettingsAccessory.Chevron,
            onClick = onOpenSettings,
          )
        }
      }
    }
  }
}

@Preview(showBackground = true, name = "You — signed in")
@Composable
private fun YouScreenPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      YouScreen(accountStore = MockAccountStore.emailUser, onOpenSettings = {})
    }
  }
}
