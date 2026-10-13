package io.appbeyond.freelance.deep.feature.globalpause

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.globalpause.components.PeaceMessageComposerCard
import io.appbeyond.freelance.deep.feature.globalpause.model.Intention
import io.appbeyond.freelance.deep.feature.globalpause.store.FixturePauseEventRemote
import io.appbeyond.freelance.deep.networking.DeepApiException
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.DeepChip
import io.appbeyond.freelance.deep.shared.components.RewardContinueButton
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.exhale
import io.appbeyond.freelance.deep.theme.rhythm
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/**
 * The landing after the meditation: a thank-you, and one card to write into.
 *
 * One ask, one tap. The composer *is* the card the message will appear as, so
 * the member sees their name, their place and their chosen word before they
 * commit. The forward tap posts it — there is no separate send, so writing a
 * message costs no more steps than skipping one. It says nothing about hearts:
 * the ritual it continues into carries that news.
 *
 * Its background is painted by the session's ending — one atmosphere for both
 * halves, so nothing crossfades against itself.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Screens/GlobalPauseReflectionView.swift,
 * with one deliberate difference: the button reads "Continue" throughout and
 * never relabels itself to "Send & continue" — one action title per screen.
 *
 * @param isPreparing the ending is settling tonight's award: the tap rests
 *   rather than promise a number that hasn't landed.
 * @param post posts the message with its tag (the server also keeps the tag as
 *   tonight's reflection).
 * @param submit keeps a tag left without a message.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun GlobalPauseReflectionScreen(
  intentions: List<Intention>,
  name: String,
  place: String,
  isPreparing: Boolean,
  post: suspend (message: String, intention: String?) -> Unit,
  submit: suspend (intention: String) -> Unit,
  onContinue: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val scope = rememberCoroutineScope()
  val focus = LocalFocusManager.current
  var text by rememberSaveable { mutableStateOf("") }
  var tag by rememberSaveable { mutableStateOf<String?>(null) }
  var isSending by remember { mutableStateOf(false) }
  var note by remember { mutableStateOf<String?>(null) }
  // Once a refusal has been shown, the next tap leaves rather than trapping
  // the member on a message that will not send.
  var mayContinueUnsent by remember { mutableStateOf(false) }

  val noteSignedOut = stringResource(R.string.pause_reflection_note_signed_out)
  val noteLimit = stringResource(R.string.pause_reflection_note_limit)
  val noteFailed = stringResource(R.string.pause_reflection_note_failed)

  fun commit() {
    if (isSending || isPreparing) return
    focus.clearFocus()
    val trimmed = text.trim()
    val chosen = tag
    if (mayContinueUnsent || (trimmed.isEmpty() && chosen == null)) {
      onContinue()
      return
    }
    isSending = true
    scope.launch {
      try {
        // A word without a message still belongs in tonight's reflection.
        if (trimmed.isEmpty()) submit(chosen!!) else post(trimmed, chosen)
        onContinue()
      } catch (cancelled: CancellationException) {
        throw cancelled
      } catch (failure: Exception) {
        note = when {
          failure is DeepApiException.Unauthorized -> noteSignedOut
          failure is DeepApiException.Http && failure.code == "message_limit" -> noteLimit
          else -> noteFailed
        }
        mayContinueUnsent = true
      } finally {
        isSending = false
      }
    }
  }

  Box(modifier.fillMaxSize().imePadding()) {
    Column(
      Modifier
        .fillMaxSize()
        .verticalScroll(rememberScrollState())
        .statusBarsPadding()
        .padding(horizontal = Dp.edge)
        .padding(top = Dp.rhythm, bottom = BUTTON_CLEARANCE),
      horizontalAlignment = Alignment.CenterHorizontally,
      verticalArrangement = Arrangement.spacedBy(Dp.rhythm * 1.5f, Alignment.CenterVertically),
    ) {
      Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(7.dp)) {
        Text(stringResource(R.string.pause_reflection_eyebrow), style = DeepType.micro, color = Color.driftGrey)
        Text(
          stringResource(R.string.pause_reflection_title),
          style = DeepType.displayTitle,
          color = Color.deepPlum,
          textAlign = TextAlign.Center,
          modifier = Modifier.semantics { heading() },
        )
      }

      PeaceMessageComposerCard(
        text = text,
        onTextChange = { text = it },
        name = name,
        place = place,
        tagLabel = intentions.firstOrNull { it.key == tag }?.label,
      )

      Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(stringResource(R.string.pause_reflection_tag_prompt), style = DeepType.caption, color = Color.driftGrey)
        FlowRow(
          horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
          verticalArrangement = Arrangement.spacedBy(8.dp),
          modifier = Modifier.fillMaxWidth(),
        ) {
          intentions.forEach { intention ->
            DeepChip(
              label = intention.label,
              isSelected = tag == intention.key,
              onClick = { tag = if (tag == intention.key) null else intention.key },
            )
          }
        }
      }

      AnimatedVisibility(visible = note != null, enter = fadeIn(exhale()), exit = fadeOut(exhale())) {
        Text(
          note.orEmpty(),
          style = DeepType.caption,
          color = Color.driftGrey,
          textAlign = TextAlign.Center,
        )
      }
    }

    RewardContinueButton(
      title = stringResource(R.string.reward_continue),
      onClick = ::commit,
      isBusy = isSending || isPreparing,
      modifier = Modifier
        .align(Alignment.BottomCenter)
        .navigationBarsPadding()
        .padding(horizontal = Dp.edge)
        .padding(bottom = Dp.rhythm),
    )
  }
}

/** Room under the scroll for the pinned button. */
private val BUTTON_CLEARANCE = 112.dp

/** The offline intention labels, in the member's language — iOS's `Intention.samples`. */
@Composable
fun sampleIntentions(): List<Intention> = listOf(
  Intention("peace", stringResource(R.string.pause_intention_peace)),
  Intention("healing", stringResource(R.string.pause_intention_healing)),
  Intention("gratitude", stringResource(R.string.pause_intention_gratitude)),
  Intention("someone-i-love", stringResource(R.string.pause_intention_someone_i_love)),
  Intention("other", stringResource(R.string.pause_intention_other)),
)

@Preview(showBackground = true, name = "Reflection")
@Composable
private fun ReflectionPreview() {
  DeepTheme {
    Box {
      AtmosphereBackground()
      GlobalPauseReflectionScreen(
        intentions = FixturePauseEventRemote.sampleIntentions,
        name = "Miyu",
        place = "Thailand",
        isPreparing = false,
        post = { _, _ -> },
        submit = {},
        onContinue = {},
      )
    }
  }
}

@Preview(showBackground = true, name = "Reflection — settling the award")
@Composable
private fun ReflectionPreparingPreview() {
  DeepTheme {
    Box {
      AtmosphereBackground()
      GlobalPauseReflectionScreen(
        intentions = FixturePauseEventRemote.sampleIntentions,
        name = "Miyu",
        place = "",
        isPreparing = true,
        post = { _, _ -> },
        submit = {},
        onContinue = {},
      )
    }
  }
}
