package io.appbeyond.freelance.deep.feature.onboarding.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.onboarding.model.MindTree
import io.appbeyond.freelance.deep.shared.components.ArtworkImage
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.settle
import io.appbeyond.freelance.deep.theme.softPress
import io.appbeyond.freelance.deep.theme.tile

private const val ARTWORK_ASPECT = 0.8f
private val CARD_PADDING = 10.dp
private val CARD_SPACING = 10.dp
private val TEXT_SPACING = 2.dp
private val TEXT_BOTTOM_PADDING = 6.dp
private val MARK_INSET = 16.dp
private val MARK_SEAT_INSET = 2.dp

/**
 * One selectable Mind Tree tile: the tree's artwork over its palette gradient,
 * name and tagline beneath, and a check that blooms in at the top-trailing
 * corner when chosen. Speaks [QuizOptionCard]'s selection language, reshaped
 * for a grid.
 *
 * Ported from Deep/Deep/Features/Onboarding/Components/MindTreeCard.swift.
 */
@Composable
fun MindTreeCard(
  tree: MindTree,
  isSelected: Boolean,
  onClick: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val shape = RoundedCornerShape(Dp.card)
  val rimAlpha by animateFloatAsState(
    targetValue = if (isSelected) 1f else 0f,
    animationSpec = settle(),
    label = "mind-tree-rim",
  )

  Box(
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
      ),
  ) {
    Column(
      modifier = Modifier.padding(CARD_PADDING),
      verticalArrangement = Arrangement.spacedBy(CARD_SPACING),
      horizontalAlignment = Alignment.CenterHorizontally,
    ) {
      ArtworkImage(
        url = tree.imageUrl,
        palette = tree.palette,
        modifier = Modifier
          .fillMaxWidth()
          .aspectRatio(ARTWORK_ASPECT)
          .clip(RoundedCornerShape(Dp.tile)),
      )

      Column(
        modifier = Modifier.padding(bottom = TEXT_BOTTOM_PADDING),
        verticalArrangement = Arrangement.spacedBy(TEXT_SPACING),
        horizontalAlignment = Alignment.CenterHorizontally,
      ) {
        Text(text = tree.name, style = DeepType.body, color = Color.deepPlum, textAlign = TextAlign.Center)
        Text(text = tree.tagline, style = DeepType.caption, color = Color.driftGrey, textAlign = TextAlign.Center)
      }
    }

    AnimatedVisibility(
      visible = isSelected,
      enter = scaleIn(settle(), initialScale = MARK_INITIAL_SCALE) + fadeIn(settle()),
      exit = fadeOut(settle()),
      modifier = Modifier
        .align(Alignment.TopEnd)
        .padding(MARK_INSET),
    ) {
      // Seated on a white disc so the check holds over any artwork.
      Box(contentAlignment = Alignment.Center) {
        Box(
          Modifier
            .matchParentSize()
            .padding(MARK_SEAT_INSET)
            .clip(CircleShape)
            .background(Color.White),
        )
        FilledCheckMark()
      }
    }
  }
}

@Preview(showBackground = true, name = "Mind Tree cards")
@Composable
private fun MindTreeCardPreview() {
  var selected by remember { mutableStateOf("oak") }
  val trees = listOf(
    MindTree(id = "oak", name = "Oak", tagline = "Steady & Strong", imageUrl = null, palette = "tide"),
    MindTree(id = "sakura", name = "Sakura", tagline = "Gentle & Open", imageUrl = null, palette = "bloom"),
  )

  OnboardingPreviewBackdrop {
    Row(
      modifier = Modifier.padding(horizontal = Dp.edge, vertical = Dp.rhythm),
      horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
      trees.forEach { tree ->
        MindTreeCard(
          tree = tree,
          isSelected = selected == tree.id,
          onClick = { selected = tree.id },
          modifier = Modifier.weight(1f),
        )
      }
    }
  }
}
