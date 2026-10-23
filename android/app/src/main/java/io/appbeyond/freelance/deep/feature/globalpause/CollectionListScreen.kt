package io.appbeyond.freelance.deep.feature.globalpause

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsound.SoundFixtures
import io.appbeyond.freelance.deep.feature.deepsound.SoundIcons
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundTime
import io.appbeyond.freelance.deep.feature.profile.HeaderIconButton
import io.appbeyond.freelance.deep.shared.components.ArtworkImage
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.LocalMiniPlayerClearance
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.rhythm
import io.appbeyond.freelance.deep.theme.softPress

// MARK: - Constants

/** The row's artwork — iOS's `.frame(width: 72, height: 72)`. */
private val ARTWORK_SIZE = 72.dp

/** The artwork's corner — iOS's `cornerRadius: 16`. */
private val ARTWORK_RADIUS = 16.dp

/** Space between rows, and inside a row between artwork/text/chevron — iOS's `spacing: 14`. */
private val ROW_SPACING = 14.dp

/** Space between a row's title, subtitle and meta line — iOS's `VStack(spacing: 3)`. */
private val ROW_TEXT_SPACING = 3.dp

/** A row's inner padding — iOS's `.padding(12)`. */
private val ROW_PADDING = 12.dp

/** The trailing chevron — iOS's `.font(.system(size: 13, weight: .semibold))`. */
private val CHEVRON_SIZE = 16.dp

/** The bar's height below the status bar, matching CollectionDetailScreen's. */
private val TOP_BAR_PADDING_VERTICAL = 6.dp
private val TOP_BAR_TITLE_INSET = 56.dp

// MARK: - Screen

/**
 * A titled vertical list of collections — the destination for an Explore
 * category tap on the Global Pause home (and, in time, any "See all").
 * Rows push the real collection detail via [onOpenCollection].
 *
 * Ported from Deep/Deep/Features/GlobalPause/Components/CollectionListView.swift.
 * iOS rides a system navigation bar with an inline title; this is pushed onto
 * the tab's own stack, which has no bar, so the screen draws its own — the
 * same frosted-chevron-plus-centred-title bar [io.appbeyond.freelance.deep.feature.deepsound.CollectionDetailScreen]
 * uses, over the atmosphere with no bar background.
 *
 * @param title the list's heading — an Explore category's name.
 * @param collections the category's collections, in server order.
 * @param onOpenCollection asks the coordinator to push a row's collection detail.
 * @param onBack pops the screen.
 */
@Composable
fun CollectionListScreen(
  title: String,
  collections: List<SoundCollection>,
  onOpenCollection: (SoundCollection) -> Unit,
  onBack: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val bottomInset = Dp.rhythm + LocalMiniPlayerClearance.current

  Box(
    modifier
      .fillMaxSize()
      .background(Color.moonCream),
  ) {
    AtmosphereBackground()

    Column(
      Modifier
        .fillMaxSize()
        .statusBarsPadding(),
    ) {
      ListTopBar(title = title, onBack = onBack)

      LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(
          start = Dp.edge,
          end = Dp.edge,
          top = Dp.rhythm,
          bottom = bottomInset,
        ),
        verticalArrangement = Arrangement.spacedBy(ROW_SPACING),
      ) {
        items(collections, key = { it.id }) { collection ->
          CollectionRow(
            collection = collection,
            onOpen = { onOpenCollection(collection) },
          )
        }
      }
    }
  }
}

// MARK: - Top bar

/**
 * The back chevron at the leading edge and the list's title centred over the
 * whole width — the same shape as [io.appbeyond.freelance.deep.feature.deepsound.CollectionDetailScreen]'s
 * `DetailTopBar`, reused rather than duplicated in spirit only, since that one
 * is private to its own file.
 */
@Composable
private fun ListTopBar(title: String, onBack: () -> Unit) {
  Box(
    Modifier
      .fillMaxWidth()
      .padding(horizontal = Dp.edge, vertical = TOP_BAR_PADDING_VERTICAL),
    contentAlignment = Alignment.Center,
  ) {
    HeaderIconButton(
      icon = SoundIcons.ChevronBack,
      contentDescription = stringResource(R.string.deepsound_back),
      onClick = onBack,
      modifier = Modifier.align(Alignment.CenterStart),
    )
    Text(
      text = title,
      style = DeepType.sectionTitle,
      color = Color.deepPlum,
      maxLines = 1,
      overflow = TextOverflow.Ellipsis,
      textAlign = TextAlign.Center,
      modifier = Modifier.padding(horizontal = TOP_BAR_TITLE_INSET),
    )
  }
}

// MARK: - Row

/**
 * One collection: artwork, title, subtitle and a "{n} tracks · {x} min" meta
 * line, with a trailing chevron. The text column takes `Modifier.weight(1f)`
 * rather than sitting beside a `Spacer` — a `Spacer` bids against it for width
 * and truncates titles that have room to spare (the same fix `CollectionTile`
 * and `HomeTile`'s ports already carry).
 *
 * The accessibility label folds the title and track count together, exactly as
 * iOS's plain `"\(collection.title), \(collection.trackCount) tracks"` does —
 * not a catalog entry there either, so not one here.
 */
@Composable
private fun CollectionRow(
  collection: SoundCollection,
  onOpen: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val trackCount = pluralStringResource(
    R.plurals.deepsound_track_count,
    collection.trackCount,
    collection.trackCount,
  )
  val minutes = stringResource(
    R.string.deepsound_minutes,
    SoundTime.minutes(collection.totalDurationSeconds.toDouble()),
  )
  val meta = stringResource(R.string.deepsound_collection_meta, trackCount, minutes)
  val a11yLabel = "${collection.title}, $trackCount"

  Row(
    modifier
      .fillMaxWidth()
      .frostedCard()
      .softPress()
      .clickable(
        interactionSource = remember { MutableInteractionSource() },
        indication = null,
        onClick = onOpen,
      )
      .padding(ROW_PADDING)
      .clearAndSetSemantics {
        contentDescription = a11yLabel
        role = Role.Button
        onClick { onOpen(); true }
      },
    horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    ArtworkImage(
      url = collection.imageUrl,
      palette = collection.palette,
      contentDescription = null,
      modifier = Modifier
        .size(ARTWORK_SIZE)
        .clip(RoundedCornerShape(ARTWORK_RADIUS)),
    )

    Column(
      Modifier.weight(1f),
      verticalArrangement = Arrangement.spacedBy(ROW_TEXT_SPACING),
    ) {
      Text(
        text = collection.title,
        style = DeepType.bodyMedium,
        color = Color.deepPlum,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
      )
      Text(
        text = collection.subtitle,
        style = DeepType.caption,
        color = Color.driftGrey,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
      )
      Text(
        text = meta,
        style = DeepType.micro,
        color = Color.driftGrey,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
      )
    }

    Icon(
      SoundIcons.ChevronForward,
      contentDescription = null,
      tint = Color.driftGrey,
      modifier = Modifier.size(CHEVRON_SIZE),
    )
  }
}

// MARK: - Previews

@Preview(showBackground = true, name = "Collection list")
@Composable
private fun CollectionListPreview() {
  DeepTheme {
    CollectionListScreen(
      title = "Sleep",
      collections = SoundFixtures.sleep,
      onOpenCollection = {},
      onBack = {},
    )
  }
}
