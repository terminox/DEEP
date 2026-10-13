package io.appbeyond.freelance.deep.shared.components

import android.icu.text.BreakIterator
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.TextStyle
import io.appbeyond.freelance.deep.theme.exhale

/**
 * A figure whose characters roll individually when it changes — up and in as
 * [value] grows, down as it shrinks — the Android stand-in for SwiftUI's
 * `.contentTransition(.numericText(value:))`. Characters are keyed from the
 * right, so "240" → "1,240" rolls the units, tens and hundreds in place and
 * the new thousands simply arrive. Under reduced motion the change is a plain
 * crossfade. Read as one value by TalkBack, not character by character.
 * Characters are grapheme clusters, so Thai marks never separate from their
 * consonants.
 *
 * Hoisted from `SunlightFact` in week 5, when the Compassion portfolio's
 * balances, shares and compact counts needed the same roll.
 *
 * @param text the figure as shown, already formatted in the app's locale.
 * @param value the quantity behind it, for the roll's direction only.
 */
@Composable
fun RollingText(
  text: String,
  value: Float,
  style: TextStyle,
  color: Color,
  modifier: Modifier = Modifier,
) {
  val reduceMotion = rememberReduceMotion()
  val previous = remember { mutableFloatStateOf(value) }
  val rising = value >= previous.floatValue
  SideEffect { previous.floatValue = value }

  val clusters = remember(text) { graphemes(text) }
  Row(modifier.clearAndSetSemantics { contentDescription = text }) {
    clusters.forEachIndexed { index, cluster ->
      key(clusters.size - index) {
        AnimatedContent(
          targetState = cluster,
          transitionSpec = {
            if (reduceMotion) {
              fadeIn(exhale()) togetherWith fadeOut(exhale())
            } else {
              val from = if (rising) 1 else -1
              (slideInVertically(exhale()) { it * from } + fadeIn(exhale()))
                .togetherWith(slideOutVertically(exhale()) { -it * from } + fadeOut(exhale()))
                .using(SizeTransform(clip = true))
            }
          },
          label = "rolling-character",
        ) { character ->
          Text(text = character, style = style, color = color)
        }
      }
    }
  }
}

/**
 * [text] split into user-perceived characters, so a Thai vowel or tone mark
 * stays on its consonant — "1.8 หมื่น" rolled per `Char` would draw the
 * combining marks as orphans.
 */
private fun graphemes(text: String): List<String> {
  val iterator = BreakIterator.getCharacterInstance()
  iterator.setText(text)
  val clusters = mutableListOf<String>()
  var start = iterator.first()
  var end = iterator.next()
  while (end != BreakIterator.DONE) {
    clusters += text.substring(start, end)
    start = end
    end = iterator.next()
  }
  return clusters
}
