package io.appbeyond.freelance.deep.feature.onboarding.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.onboarding.model.QuizOption
import io.appbeyond.freelance.deep.shared.components.ArtworkImage
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.settle
import io.appbeyond.freelance.deep.theme.softPress

private val ORB_SIZE = 30.dp
private val ORB_RIM_WIDTH = 0.5.dp
private const val ORB_RIM_ALPHA = 0.5f
private val ROW_SPACING = 14.dp
private val PADDING_VERTICAL = 16.dp
private val PADDING_HORIZONTAL = 18.dp
private val TEXT_SPACING = 2.dp

/** The selected card's rim — iOS's `strokeBorder(.lavenderMist, lineWidth: 1.5)`. */
internal val SELECTION_RIM_WIDTH = 1.5.dp

/** The mark's pop-in — iOS's `.scale(scale: 0.6).combined(with: .opacity)`. */
internal const val MARK_INITIAL_SCALE = 0.6f

private const val HOLLOW_MARK_ALPHA = 0.5f

/**
 * A single-select quiz answer: a frosted pill with a soft palette orb, the
 * answer text, and a trailing mark that blooms in when chosen.
 *
 * Ported from Deep/Deep/Features/Onboarding/Components/QuizOptionCard.swift.
 * The orb is [ArtworkImage] with no URL — the same server palette name resolved
 * by the same component every other palette-tinted surface uses, rather than a
 * second palette table here.
 */
@Composable
fun QuizOptionCard(
  option: QuizOption,
  isSelected: Boolean,
  onClick: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val shape = RoundedCornerShape(Dp.card)
  val rimAlpha by animateFloatAsState(
    targetValue = if (isSelected) 1f else 0f,
    animationSpec = settle(),
    label = "quiz-option-rim",
  )

  Row(
    modifier = modifier
      .fillMaxWidth()
      .frostedCard(cornerRadius = Dp.card)
      .selectionRim(rimAlpha, shape)
      .softPress()
      .selectable(
        selected = isSelected,
        role = Role.RadioButton,
        interactionSource = null,
        indication = null,
        onClick = onClick,
      )
      .padding(vertical = PADDING_VERTICAL, horizontal = PADDING_HORIZONTAL),
    horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    ArtworkImage(
      url = null,
      palette = option.palette,
      modifier = Modifier
        .size(ORB_SIZE)
        .clip(CircleShape)
        .border(ORB_RIM_WIDTH, Color.White.copy(alpha = ORB_RIM_ALPHA), CircleShape),
    )

    Column(
      modifier = Modifier.weight(1f),
      verticalArrangement = Arrangement.spacedBy(TEXT_SPACING),
    ) {
      Text(text = option.title, style = DeepType.body, color = Color.deepPlum)
      option.subtitle?.let { Text(text = it, style = DeepType.caption, color = Color.driftGrey) }
    }

    SelectionMark(isSelected = isSelected, hollowAlpha = HOLLOW_MARK_ALPHA)
  }
}

/** A lavender rim over a selected card, faded rather than width-animated (a 0dp border still draws a hairline). */
internal fun Modifier.selectionRim(alpha: Float, shape: RoundedCornerShape): Modifier =
  if (alpha > 0f) border(SELECTION_RIM_WIDTH, Color.lavenderMist.copy(alpha = alpha), shape) else this

/** Hollow ring ⇄ filled check, the check popping in on [settle]. */
@Composable
internal fun SelectionMark(
  isSelected: Boolean,
  hollowAlpha: Float,
  modifier: Modifier = Modifier,
  size: Dp = SELECTION_MARK_SIZE,
) {
  AnimatedContent(
    targetState = isSelected,
    transitionSpec = {
      (scaleIn(settle(), initialScale = MARK_INITIAL_SCALE) + fadeIn(settle())) togetherWith fadeOut(settle())
    },
    modifier = modifier,
    label = "selection-mark",
  ) { selected ->
    if (selected) FilledCheckMark(size = size) else HollowMark(alpha = hollowAlpha, size = size)
  }
}

@Preview(showBackground = true, name = "Quiz option card")
@Composable
private fun QuizOptionCardPreview() {
  var selected by remember { mutableStateOf("calm") }
  val options = listOf(
    QuizOption(id = "calm", title = "Calm", subtitle = null, palette = "tide"),
    QuizOption(id = "connection", title = "Connection", subtitle = "Feeling less alone", palette = "dusk"),
    QuizOption(id = "clarity", title = "Clarity", subtitle = null, palette = "mist"),
  )

  OnboardingPreviewBackdrop {
    Column(
      modifier = Modifier.padding(horizontal = Dp.edge, vertical = Dp.rhythm),
      verticalArrangement = Arrangement.spacedBy(ROW_SPACING),
    ) {
      options.forEach { option ->
        QuizOptionCard(option = option, isSelected = selected == option.id, onClick = { selected = option.id })
      }
    }
  }
}
