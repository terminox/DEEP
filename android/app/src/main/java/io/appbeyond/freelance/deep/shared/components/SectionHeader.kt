package io.appbeyond.freelance.deep.shared.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.moonCream

/**
 * A section's title, and an optional caption beneath it, inset to the screen
 * edge.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Components/SectionHeader.swift
 * (and its title-only sibling `HomeSectionHeader`), minus the "See all"
 * trailing link nobody on Android routes yet.
 */
@Composable
fun SectionHeader(
  title: String,
  modifier: Modifier = Modifier,
  subtitle: String? = null,
) {
  Column(
    modifier.fillMaxWidth().padding(horizontal = Dp.edge),
    verticalArrangement = Arrangement.spacedBy(4.dp),
  ) {
    Text(
      text = title,
      style = DeepType.sectionTitle,
      color = Color.deepPlum,
      modifier = Modifier.semantics { heading() },
    )
    if (subtitle != null) {
      Text(text = subtitle, style = DeepType.caption, color = Color.driftGrey)
    }
  }
}

@Preview(showBackground = true, name = "Section header")
@Composable
private fun SectionHeaderPreview() {
  Column(
    Modifier.background(Color.moonCream).padding(vertical = 16.dp),
    verticalArrangement = Arrangement.spacedBy(24.dp),
  ) {
    SectionHeader(title = "Set your intention", subtitle = "What would you like to pause for?")
    SectionHeader(title = "From the field")
  }
}
