package io.appbeyond.freelance.deep.feature.globalpause.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MenuDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessageReportReason
import io.appbeyond.freelance.deep.feature.profile.DeepConfirmDialog
import io.appbeyond.freelance.deep.feature.profile.DeepDialog
import io.appbeyond.freelance.deep.feature.profile.DialogAction
import io.appbeyond.freelance.deep.feature.profile.SettingsRow
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.duskRose
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.softPress
import io.appbeyond.freelance.deep.theme.tile

/*
 * Report and Block on a peace message that isn't the member's own: a quiet
 * ellipsis on the card opens a menu with the two; Report asks why, Block asks
 * to be sure. Both dialogs are the frosted `DeepDialog` Settings already uses,
 * and the menu is styled as the playlist row's, so nothing here is new
 * chrome. iOS shows the same menu, reasons and confirmation.
 */

/**
 * What a card can do about a message that isn't the member's own. A card
 * handed none shows no menu — signed out, or their own message.
 */
@Immutable
class PeaceMessageCardActions(
  val onReport: (PeaceMessageReportReason) -> Unit,
  val onBlock: () -> Unit,
)

/** Which of the menu's surfaces is up — shared by the button and the card's TalkBack actions. */
@Stable
class PeaceMessageMenuState {
  var isMenuOpen by mutableStateOf(false)
  var isPickingReason by mutableStateOf(false)
  var isConfirmingBlock by mutableStateOf(false)
}

/**
 * The ellipsis, its menu, and the two dialogs behind it.
 *
 * @param authorName who Block would block, as the card shows them.
 */
@Composable
fun PeaceMessageMenu(
  state: PeaceMessageMenuState,
  authorName: String,
  actions: PeaceMessageCardActions,
  modifier: Modifier = Modifier,
) {
  val more = stringResource(R.string.safety_more)
  Box(modifier) {
    Box(
      Modifier
        .size(MORE_SIZE)
        .softPress()
        .clip(CircleShape)
        .clickable(
          interactionSource = remember { MutableInteractionSource() },
          indication = null,
          role = Role.Button,
          onClickLabel = more,
          onClick = { state.isMenuOpen = true },
        ),
      contentAlignment = Alignment.Center,
    ) {
      Icon(GlobalPauseIcons.Ellipsis, contentDescription = more, tint = Color.driftGrey, modifier = Modifier.size(MORE_GLYPH))
    }

    DropdownMenu(
      expanded = state.isMenuOpen,
      onDismissRequest = { state.isMenuOpen = false },
      shape = RoundedCornerShape(Dp.tile),
      containerColor = Color.moonCream,
      tonalElevation = 0.dp,
    ) {
      DropdownMenuItem(
        text = { Text(stringResource(R.string.safety_report), style = DeepType.body) },
        leadingIcon = { Icon(GlobalPauseIcons.Flag, contentDescription = null, modifier = Modifier.size(MENU_GLYPH)) },
        colors = MenuDefaults.itemColors(textColor = Color.deepPlum, leadingIconColor = Color.driftGrey),
        onClick = {
          state.isMenuOpen = false
          state.isPickingReason = true
        },
      )
      DropdownMenuItem(
        text = { Text(stringResource(R.string.safety_block, authorName), style = DeepType.body) },
        leadingIcon = { Icon(GlobalPauseIcons.NoSign, contentDescription = null, modifier = Modifier.size(MENU_GLYPH)) },
        colors = MenuDefaults.itemColors(textColor = Color.duskRose, leadingIconColor = Color.duskRose),
        onClick = {
          state.isMenuOpen = false
          state.isConfirmingBlock = true
        },
      )
    }
  }

  PeaceMessageMenuDialogs(state, authorName, actions)
}

/** The reason picker and the block confirmation, for whichever is up. */
@Composable
private fun PeaceMessageMenuDialogs(
  state: PeaceMessageMenuState,
  authorName: String,
  actions: PeaceMessageCardActions,
) {
  if (state.isPickingReason) {
    DeepDialog(
      title = stringResource(R.string.safety_report_title),
      actions = listOf(DialogAction(stringResource(R.string.safety_cancel)) { state.isPickingReason = false }),
      onDismissRequest = { state.isPickingReason = false },
    ) {
      ReportReasons { reason ->
        state.isPickingReason = false
        actions.onReport(reason)
      }
    }
  }

  if (state.isConfirmingBlock) {
    DeepConfirmDialog(
      title = stringResource(R.string.safety_block_title, authorName),
      message = stringResource(R.string.safety_block_body),
      actions = listOf(
        DialogAction(stringResource(R.string.safety_cancel)) { state.isConfirmingBlock = false },
        DialogAction(stringResource(R.string.safety_block_confirm), destructive = true) {
          state.isConfirmingBlock = false
          actions.onBlock()
        },
      ),
      onDismissRequest = { state.isConfirmingBlock = false },
    )
  }
}

/** The four reasons, as rows of a list of choices — the language picker's grammar. */
@Composable
private fun ReportReasons(onPick: (PeaceMessageReportReason) -> Unit) {
  Column(Modifier.fillMaxWidth()) {
    PeaceMessageReportReason.entries.forEach { reason ->
      SettingsRow(title = stringResource(reason.label), onClick = { onPick(reason) })
    }
  }
}

private val PeaceMessageReportReason.label: Int
  get() = when (this) {
    PeaceMessageReportReason.Offensive -> R.string.safety_reason_offensive
    PeaceMessageReportReason.Harassment -> R.string.safety_reason_harassment
    PeaceMessageReportReason.Spam -> R.string.safety_reason_spam
    PeaceMessageReportReason.Other -> R.string.safety_reason_other
  }

/** The ellipsis's hit area: the avatar's size, so the identity row keeps its height. */
private val MORE_SIZE = 32.dp
private val MORE_GLYPH = 20.dp
private val MENU_GLYPH = 18.dp

@Preview(showBackground = true, name = "Peace message menu")
@Composable
private fun PeaceMessageMenuPreview() {
  val state = remember { PeaceMessageMenuState().apply { isMenuOpen = true } }
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      PeaceMessageMenu(
        state = state,
        authorName = "Haruki",
        actions = PeaceMessageCardActions(onReport = {}, onBlock = {}),
        modifier = Modifier.padding(Dp.edge),
      )
    }
  }
}
