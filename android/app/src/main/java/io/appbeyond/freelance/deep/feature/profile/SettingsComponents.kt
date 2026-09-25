package io.appbeyond.freelance.deep.feature.profile

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.DialogWindowProvider
import io.appbeyond.freelance.deep.feature.appshell.DeepIcons
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.bloom
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.duskRose
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.softPress

// MARK: - Constants

private const val ROW_ICON_ALPHA = 0.7f
private val ROW_ICON_COLUMN = 24.dp
private val ROW_ICON_GLYPH = 20.dp
private val ROW_SPACING = 14.dp
private val ROW_PADDING_VERTICAL = 16.dp
private val ROW_PADDING_HORIZONTAL = 18.dp
private val ACCESSORY_GLYPH = 14.dp
private val PROGRESS_SIZE = 18.dp
private val PROGRESS_STROKE = 1.5.dp
private val SECTION_TITLE_INSET = 8.dp
private val SECTION_TITLE_GAP = 10.dp

/** iOS `HeaderIconButton`: a 40pt disc of white at 65% with a faint rim. */
private val HEADER_BUTTON_SIZE = 40.dp
private val HEADER_BUTTON_GLYPH = 18.dp
private const val HEADER_BUTTON_FILL_ALPHA = 0.65f
private const val HEADER_BUTTON_BORDER_ALPHA = 0.4f
private val HEADER_BUTTON_BORDER = 0.5.dp

/**
 * The dialog scrim: plum, not black. A black dim turns Deep's pale atmosphere
 * into a bruise; a light plum wash keeps the room recognisably the same one.
 */
private const val SCRIM_ALPHA = 0.28f
private val DIALOG_MAX_WIDTH = 340.dp
private val DIALOG_PADDING = 24.dp
private val DIALOG_ACTION_PADDING_HORIZONTAL = 22.dp
private val DIALOG_ACTION_PADDING_VERTICAL = 12.dp
private const val DIALOG_BLOOM_FROM_SCALE = 0.92f

// MARK: - Section

/**
 * A Calm-style settings group: an optional whisper of a title above a frosted
 * card of rows. The card *is* the grouping — Deep separates content with
 * whitespace and surfaces, never with rules, so there are no hairlines
 * between the rows.
 *
 * Ported from `SettingsSection` in
 * Deep/Deep/Features/Profile/SettingsComponents.swift.
 */
@Composable
fun SettingsSection(
  modifier: Modifier = Modifier,
  title: String? = null,
  content: @Composable () -> Unit,
) {
  Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(SECTION_TITLE_GAP)) {
    if (title != null) {
      Text(
        text = title,
        style = DeepType.micro,
        color = Color.driftGrey,
        modifier = Modifier.padding(horizontal = SECTION_TITLE_INSET),
      )
    }
    Column(Modifier.fillMaxWidth().frostedCard(cornerRadius = Dp.card)) {
      content()
    }
  }
}

// MARK: - Row

/** What trails a [SettingsRow]. Ported from `SettingsRow.Accessory`. */
sealed interface SettingsAccessory {
  data object None : SettingsAccessory
  data object Chevron : SettingsAccessory
  data class Value(val text: String) : SettingsAccessory
  data object Progress : SettingsAccessory
}

/**
 * One settings line: a glyph in a fixed column, a title, and an optional
 * trailing accessory. With an [onClick] it becomes a soft-press control;
 * without one it renders as a static, informational row.
 *
 * Ported from `SettingsRow` in Deep/Deep/Features/Profile/SettingsComponents.swift.
 * The press carries no ripple: iOS's `.softPress` is the only feedback there,
 * and a Material ripple washing across a frosted card is a second, foreign
 * language layered on the first.
 *
 * @param tint overrides the plum glyph/title colour — e.g. [duskRose] for a
 *   row whose action is irreversible.
 */
@Composable
fun SettingsRow(
  title: String,
  modifier: Modifier = Modifier,
  icon: ImageVector? = null,
  accessory: SettingsAccessory = SettingsAccessory.None,
  tint: Color? = null,
  onClick: (() -> Unit)? = null,
) {
  val ink = tint ?: Color.deepPlum
  val interaction = remember { MutableInteractionSource() }

  Row(
    modifier = modifier
      .fillMaxWidth()
      .then(
        if (onClick != null) {
          Modifier
            .softPress()
            .clickable(
              interactionSource = interaction,
              indication = null,
              role = Role.Button,
              onClick = onClick,
            )
        } else {
          Modifier
        },
      )
      .padding(vertical = ROW_PADDING_VERTICAL, horizontal = ROW_PADDING_HORIZONTAL),
    horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    if (icon != null) {
      Box(Modifier.size(ROW_ICON_COLUMN), contentAlignment = Alignment.Center) {
        Icon(
          imageVector = icon,
          contentDescription = null,
          tint = ink.copy(alpha = ROW_ICON_ALPHA),
          modifier = Modifier.size(ROW_ICON_GLYPH),
        )
      }
    }

    // Weighted rather than followed by a Spacer, so a long title keeps its width.
    Text(
      text = title,
      style = DeepType.body,
      color = ink,
      modifier = Modifier.weight(1f),
    )

    when (accessory) {
      SettingsAccessory.None -> Unit
      SettingsAccessory.Chevron -> Icon(
        imageVector = ProfileIcons.ChevronRight,
        contentDescription = null,
        tint = Color.driftGrey,
        modifier = Modifier.size(ACCESSORY_GLYPH),
      )
      is SettingsAccessory.Value -> Text(
        text = accessory.text,
        style = DeepType.caption,
        color = Color.driftGrey,
      )
      SettingsAccessory.Progress -> CircularProgressIndicator(
        color = Color.driftGrey,
        strokeWidth = PROGRESS_STROKE,
        modifier = Modifier.size(PROGRESS_SIZE),
      )
    }
  }
}

// MARK: - Header button

/**
 * A round, frosted header control — the settings entry on the You tab, the back
 * chevron on Settings. Ported from Deep/Deep/Shared/Components/HeaderIconButton.swift.
 */
@Composable
fun HeaderIconButton(
  icon: ImageVector,
  contentDescription: String,
  onClick: () -> Unit,
  modifier: Modifier = Modifier,
) {
  Box(
    modifier = modifier
      .size(HEADER_BUTTON_SIZE)
      .softPress()
      .clip(CircleShape)
      .background(Color.White.copy(alpha = HEADER_BUTTON_FILL_ALPHA))
      .border(HEADER_BUTTON_BORDER, Color.White.copy(alpha = HEADER_BUTTON_BORDER_ALPHA), CircleShape)
      .clickable(
        interactionSource = remember { MutableInteractionSource() },
        indication = null,
        role = Role.Button,
        onClickLabel = contentDescription,
        onClick = onClick,
      ),
    contentAlignment = Alignment.Center,
  ) {
    Icon(
      imageVector = icon,
      contentDescription = contentDescription,
      tint = Color.deepPlum,
      modifier = Modifier.size(HEADER_BUTTON_GLYPH),
    )
  }
}

// MARK: - Dialog

/** One choice in a [DeepConfirmDialog]. */
data class DialogAction(
  val label: String,
  val destructive: Boolean = false,
  val onClick: () -> Unit,
)

/**
 * Deep's confirmation: a frosted card blooming in over a soft plum scrim.
 *
 * Stands in for both iOS presentations Settings uses — the log-out
 * `confirmationDialog` (an action sheet) and the delete `alert`. Android has
 * neither idiom in Deep's register: a stock Material `AlertDialog` arrives on
 * a black dim with its own surface and tonal buttons. So this is composed from
 * what the app already owns — [frostedCard] for the surface and the frosted
 * chip pill (iOS's "Try again" button) for each action, destructive ones inked
 * in [duskRose] the way `role: .destructive` reddens them on iOS.
 *
 * The platform window dim is switched off and the scrim drawn here instead, so
 * it can be plum rather than black. Tapping the scrim or pressing back is the
 * cancel, as it is on iOS.
 *
 * @param actions shown side by side, in order; the cancel-like choice goes first.
 */
@Composable
fun DeepConfirmDialog(
  title: String,
  message: String,
  actions: List<DialogAction>,
  onDismissRequest: () -> Unit,
) {
  Dialog(
    onDismissRequest = onDismissRequest,
    properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
  ) {
    (LocalView.current.parent as? DialogWindowProvider)?.window?.setDimAmount(0f)
    DeepConfirmDialogContent(title, message, actions, onDismissRequest)
  }
}

/** The dialog's body alone, so previews can render it without a window. */
@Composable
private fun DeepConfirmDialogContent(
  title: String,
  message: String,
  actions: List<DialogAction>,
  onDismissRequest: () -> Unit,
) {
  val appeared = remember { MutableTransitionState(false).apply { targetState = true } }

  Box(
    Modifier
      .fillMaxSize()
      .background(Color.deepPlum.copy(alpha = SCRIM_ALPHA))
      .clickable(
        interactionSource = remember { MutableInteractionSource() },
        indication = null,
        onClick = onDismissRequest,
      )
      .safeDrawingPadding()
      .padding(horizontal = Dp.edge),
    contentAlignment = Alignment.Center,
  ) {
    AnimatedVisibility(
      visibleState = appeared,
      enter = fadeIn(bloom()) + scaleIn(bloom(), initialScale = DIALOG_BLOOM_FROM_SCALE),
    ) {
      Column(
        Modifier
          .widthIn(max = DIALOG_MAX_WIDTH)
          .fillMaxWidth()
          .frostedCard(cornerRadius = Dp.card)
          // Swallow taps on the card so only the scrim dismisses.
          .clickable(
            interactionSource = remember { MutableInteractionSource() },
            indication = null,
            onClick = {},
          )
          .padding(DIALOG_PADDING),
        horizontalAlignment = Alignment.CenterHorizontally,
      ) {
        Text(
          text = title,
          style = DeepType.displayTitle,
          color = Color.deepPlum,
          textAlign = TextAlign.Center,
        )
        Text(
          text = message,
          style = DeepType.body,
          color = Color.driftGrey,
          textAlign = TextAlign.Center,
          modifier = Modifier.padding(top = 10.dp),
        )
        Row(
          Modifier.padding(top = Dp.rhythm),
          horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
          actions.forEach { action -> DialogActionPill(action) }
        }
      }
    }
  }
}

@Composable
private fun DialogActionPill(action: DialogAction) {
  Box(
    Modifier
      .softPress()
      .frostedCard(cornerRadius = Dp.chip)
      .clickable(
        interactionSource = remember { MutableInteractionSource() },
        indication = null,
        role = Role.Button,
        onClick = action.onClick,
      )
      .padding(horizontal = DIALOG_ACTION_PADDING_HORIZONTAL, vertical = DIALOG_ACTION_PADDING_VERTICAL),
    contentAlignment = Alignment.Center,
  ) {
    Text(
      text = action.label,
      style = DeepType.bodyMedium,
      color = if (action.destructive) Color.duskRose else Color.deepPlum,
    )
  }
}

// MARK: - Previews

@Preview(showBackground = true, name = "Settings section")
@Composable
private fun SettingsSectionPreview() {
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      Column(
        Modifier.padding(Dp.edge),
        verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
      ) {
        HeaderIconButton(ProfileIcons.ChevronLeft, contentDescription = "Back", onClick = {})
        SettingsSection(title = "Membership") {
          SettingsRow(title = "Language", icon = DeepIcons.Globe, accessory = SettingsAccessory.Value("English"))
          SettingsRow(title = "Manage subscription", icon = ProfileIcons.CreditCard, accessory = SettingsAccessory.Chevron, onClick = {})
          SettingsRow(title = "Restore purchases", icon = ProfileIcons.ArrowClockwise, accessory = SettingsAccessory.Progress, onClick = {})
        }
        SettingsSection(title = "Account") {
          SettingsRow(title = "Log out", icon = ProfileIcons.LogOut, onClick = {})
          SettingsRow(title = "Delete account", icon = ProfileIcons.Trash, tint = Color.duskRose, onClick = {})
        }
      }
    }
  }
}

@Preview(showBackground = true, name = "Confirm dialog")
@Composable
private fun DeepConfirmDialogPreview() {
  var open by remember { mutableStateOf(true) }
  DeepTheme {
    Box(Modifier.fillMaxSize().background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      if (open) {
        DeepConfirmDialogContent(
          title = "Log out of DEEP?",
          message = "You'll start fresh from the welcome flow. What you've shared stays safe.",
          actions = listOf(
            DialogAction("Stay") { open = false },
            DialogAction("Log out", destructive = true) { open = false },
          ),
          onDismissRequest = { open = false },
        )
      }
    }
  }
}
