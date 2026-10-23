package io.appbeyond.freelance.deep.feature.onboarding.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActionScope
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentType
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.appshell.DeepIcons
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.chip
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.rhythm

private val ROW_SPACING = 12.dp
private val PADDING_HORIZONTAL = 18.dp
private val PADDING_VERTICAL = 16.dp
private val GLYPH_SIZE = 20.dp

/**
 * One frosted text field for the auth screens: a label-less pill with a gentle
 * placeholder, per DESIGN.md's calm voice.
 *
 * Ported from Deep/Deep/Features/Onboarding/Components/AuthField.swift — the
 * leading glyph, the soft trailing check when [isValid] is true, and for
 * secure fields a reveal toggle. iOS swaps a `SecureField` for a `TextField`;
 * here one field swaps its [PasswordVisualTransformation], so the text and the
 * focus survive the toggle for free (iOS has to reassert focus by hand; this
 * re-requests it only so a tap on the eye keeps the keyboard up).
 *
 * The toggle is a 20dp glyph; Compose widens any smaller pointer target to the
 * platform's 48dp minimum on its own, which is what iOS's negative-padding
 * trick buys by hand without inflating the pill beyond its siblings.
 *
 * @param imeAction the keyboard's action key. [ImeAction.Next] moves focus to
 *   the next field by default; any other action calls [onImeAction].
 * @param contentType the autofill hint (email, new password, …).
 */
@Composable
fun AuthField(
  value: String,
  onValueChange: (String) -> Unit,
  placeholder: String,
  modifier: Modifier = Modifier,
  icon: ImageVector? = null,
  isSecure: Boolean = false,
  isValid: Boolean? = null,
  keyboardType: KeyboardType = KeyboardType.Text,
  capitalization: KeyboardCapitalization = KeyboardCapitalization.None,
  imeAction: ImeAction = ImeAction.Next,
  onImeAction: (() -> Unit)? = null,
  contentType: ContentType? = null,
) {
  var isRevealed by rememberSaveable { mutableStateOf(false) }
  val focusRequester = remember { FocusRequester() }
  val submit: (KeyboardActionScope) -> Unit = { onImeAction?.invoke() }

  Row(
    modifier = modifier
      .fillMaxWidth()
      .frostedCard(cornerRadius = Dp.chip)
      .padding(horizontal = PADDING_HORIZONTAL, vertical = PADDING_VERTICAL),
    horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    if (icon != null) {
      Icon(icon, contentDescription = null, tint = Color.driftGrey, modifier = Modifier.size(GLYPH_SIZE))
    }

    BasicTextField(
      value = value,
      onValueChange = onValueChange,
      modifier = Modifier
        .weight(1f)
        .focusRequester(focusRequester)
        .then(if (contentType != null) Modifier.semantics { this.contentType = contentType } else Modifier),
      textStyle = DeepType.body.copy(color = Color.deepPlum),
      singleLine = true,
      cursorBrush = SolidColor(Color.lavenderMist),
      visualTransformation = if (isSecure && !isRevealed) PasswordVisualTransformation() else VisualTransformation.None,
      keyboardOptions = KeyboardOptions(
        capitalization = capitalization,
        autoCorrectEnabled = false,
        keyboardType = if (isSecure) KeyboardType.Password else keyboardType,
        imeAction = imeAction,
      ),
      keyboardActions = if (onImeAction == null) {
        KeyboardActions.Default
      } else {
        KeyboardActions(onDone = submit, onGo = submit, onSend = submit, onSearch = submit)
      },
      decorationBox = { inner ->
        Box(contentAlignment = Alignment.CenterStart) {
          if (value.isEmpty()) {
            Text(text = placeholder, style = DeepType.body, color = Color.driftGrey)
          }
          inner()
        }
      },
    )

    AnimatedVisibility(visible = isValid == true, enter = fadeIn(exhale()), exit = fadeOut(exhale())) {
      FilledCheckMark(size = GLYPH_SIZE)
    }

    if (isSecure) {
      Icon(
        imageVector = if (isRevealed) OnboardingGlyphs.EyeSlash else OnboardingGlyphs.Eye,
        contentDescription = stringResource(
          if (isRevealed) R.string.onboarding_hide_password else R.string.onboarding_show_password,
        ),
        tint = Color.driftGrey,
        modifier = Modifier
          .size(GLYPH_SIZE)
          .clickable(role = Role.Button, interactionSource = null, indication = null) {
            isRevealed = !isRevealed
            focusRequester.requestFocus()
          },
      )
    }
  }
}

@Preview(showBackground = true, name = "Auth field")
@Composable
private fun AuthFieldPreview() {
  OnboardingPreviewBackdrop {
    Column(
      modifier = Modifier.padding(horizontal = Dp.edge, vertical = Dp.rhythm),
      verticalArrangement = Arrangement.spacedBy(Dp.rhythm),
    ) {
      AuthField(value = "", onValueChange = {}, placeholder = "Your name", icon = DeepIcons.Person)
      AuthField(
        value = "drift@deep.app",
        onValueChange = {},
        placeholder = "Email",
        icon = OnboardingGlyphs.Envelope,
        isValid = true,
      )
      AuthField(
        value = "secret",
        onValueChange = {},
        placeholder = "Password",
        icon = OnboardingGlyphs.Lock,
        isSecure = true,
      )
      AuthField(value = "", onValueChange = {}, placeholder = "No icon")
    }
  }
}
