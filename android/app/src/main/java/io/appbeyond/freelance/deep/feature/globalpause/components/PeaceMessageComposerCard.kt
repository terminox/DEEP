package io.appbeyond.freelance.deep.feature.globalpause.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.DeepTagLabel
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.lavenderMist

/**
 * The feedback-phase composer — one gentle line into the world's feed.
 *
 * It is the published card made editable: the same chrome, the same identity
 * header, the same tag in the same place. What the member writes into is what
 * the world reads back, so nothing about it can surprise them afterwards —
 * least of all that they posted under their name, from their country.
 *
 * It holds no send button of its own: the screen's one forward tap commits it,
 * so writing a message costs no more steps than not writing one.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Components/PeaceMessageComposerCard.swift.
 *
 * @param name the member's display name — "Friend" when there isn't one.
 * @param place the country the post itself will carry, from the same source.
 * @param tagLabel the chosen word, shown where the published card shows it.
 */
@Composable
fun PeaceMessageComposerCard(
  text: String,
  onTextChange: (String) -> Unit,
  name: String,
  place: String,
  tagLabel: String?,
  modifier: Modifier = Modifier,
  focusRequester: FocusRequester = remember { FocusRequester() },
) {
  val focus = LocalFocusManager.current
  val placeholder = stringResource(R.string.pause_composer_placeholder)

  Column(modifier.peaceMessageCard(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
    PeaceMessageIdentity(name = name, place = place, tintSeed = name)

    BasicTextField(
      value = text,
      // The 280 the server enforces, as a soft stop rather than a refusal.
      onValueChange = { onTextChange(it.take(LIMIT)) },
      textStyle = DeepType.caption.copy(color = Color.deepPlum.copy(alpha = 0.78f)),
      cursorBrush = SolidColor(Color.lavenderMist),
      minLines = 2,
      maxLines = 5,
      keyboardOptions = KeyboardOptions(
        capitalization = KeyboardCapitalization.Sentences,
        imeAction = ImeAction.Done,
      ),
      keyboardActions = KeyboardActions(onDone = { focus.clearFocus() }),
      modifier = Modifier
        .fillMaxWidth()
        .focusRequester(focusRequester)
        .semantics { contentDescription = placeholder },
      decorationBox = { field ->
        Box {
          if (text.isEmpty()) {
            Text(placeholder, style = DeepType.caption, color = Color.driftGrey)
          }
          field()
        }
      },
    )

    AnimatedVisibility(visible = tagLabel != null, enter = fadeIn(exhale()), exit = fadeOut(exhale())) {
      Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
        DeepTagLabel(label = tagLabel.orEmpty())
      }
    }
  }
}

/** `POST /pause/messages` refuses more than this. */
const val PEACE_MESSAGE_LIMIT = 280
private const val LIMIT = PEACE_MESSAGE_LIMIT

@Preview(showBackground = true, name = "Composer — empty")
@Composable
private fun ComposerEmptyPreview() {
  DeepTheme {
    Box {
      AtmosphereBackground()
      PeaceMessageComposerCard(
        text = "",
        onTextChange = {},
        name = "Miyu",
        place = "Thailand",
        tagLabel = null,
        modifier = Modifier.padding(Dp.edge),
      )
    }
  }
}

@Preview(showBackground = true, name = "Composer — written and tagged")
@Composable
private fun ComposerWrittenPreview() {
  var text by remember { mutableStateOf("The city went quiet with me tonight. Thank you, whoever you are.") }
  DeepTheme {
    Box {
      AtmosphereBackground()
      PeaceMessageComposerCard(
        text = text,
        onTextChange = { text = it },
        name = "Miyu",
        place = "Thailand",
        tagLabel = "Gratitude",
        modifier = Modifier.padding(Dp.edge),
      )
    }
  }
}
