package io.appbeyond.freelance.deep.feature.globalpause.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.deepsound.SoundFixtures
import io.appbeyond.freelance.deep.feature.deepsound.SoundIcons
import io.appbeyond.freelance.deep.feature.deepsound.components.ArtworkDisc
import io.appbeyond.freelance.deep.feature.deepsound.components.ArtworkDiscSize
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundTime
import io.appbeyond.freelance.deep.feature.deepsound.model.TrackKind
import io.appbeyond.freelance.deep.feature.premium.LocalPremiumAccess
import io.appbeyond.freelance.deep.feature.premium.components.PremiumLockBadge
import io.appbeyond.freelance.deep.feature.premium.components.PremiumLockCorner
import io.appbeyond.freelance.deep.feature.premium.model.PremiumGate
import io.appbeyond.freelance.deep.feature.premium.rememberHasPremium
import io.appbeyond.freelance.deep.feature.premium.store.FakePremiumAccess
import io.appbeyond.freelance.deep.shared.components.ArtworkImage
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.card
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.moonCream
import io.appbeyond.freelance.deep.theme.softPress
import io.appbeyond.freelance.deep.theme.tile

/*
 * The Home feed's shelves, ported from Deep/Deep/Features/GlobalPause/Components
 * at 705b6b4: `HomeSectionHeader`, `FeatureCarousel` + `FeatureCard` (every
 * server section but "Made for you"), and `RecommendationsSection` + `HomeTile`
 * ("Made for you").
 *
 * On both, tapping the body pushes the collection's detail and only the small
 * round play button starts it in place — iOS's `openCollection` and
 * `soundPlayer.play(collection)`, handed in here as [onOpen] / [onPlay]
 * lambdas. A DEEP Premium collection this listener is locked out of keeps its
 * play button and wears [PremiumLockBadge] at the artwork's top-trailing
 * corner; [onPlay] queues only what the premium gate lets through (the
 * caller's job, as on iOS), so a locked collection's button opens the DEEP
 * Premium invitation instead of starting anything.
 */

// MARK: - Constants

/** Header to row — iOS's `VStack(spacing: 14)`. */
private val SHELF_SPACING = 14.dp

/** Between cards and tiles — iOS's `HStack(spacing: 16)`. */
private val ROW_SPACING = 16.dp

/** `HomeSectionHeader`'s `Spacer(minLength: 12)`. */
private val HEADER_MIN_GAP = 12.dp

/** `FeatureCard`'s landscape artwork — iOS's 300 × 200. */
private val FEATURE_WIDTH = 300.dp
private val FEATURE_HEIGHT = 200.dp
private val FEATURE_SPACING = 10.dp
private val FEATURE_INSET = 16.dp
private val FEATURE_TITLE_SPACING = 8.dp
private val FEATURE_ROW_SPACING = 1.dp

/** The card's lift — iOS's `shadow(lavenderMist 0.28, radius: 18, y: 12)`. */
private const val FEATURE_SHADOW_ALPHA = 0.28f
private val FEATURE_SHADOW_RADIUS = 18.dp
private val FEATURE_SHADOW_OFFSET_Y = 12.dp

/** The legibility wash — clear at the middle, plum 0.45 at the foot. */
private const val FEATURE_WASH_ALPHA = 0.45f

/** The duration pill — `.padding(.horizontal, 9)`, `.padding(.vertical, 5)`, white 0.5. */
private val PILL_PADDING_HORIZONTAL = 9.dp
private val PILL_PADDING_VERTICAL = 5.dp
private val PILL_SPACING = 4.dp
private val PILL_GLYPH = 9.dp
private const val PILL_ALPHA = 0.5f

/** The micro size without the eyebrow's all-caps tracking — the pill reads a length. */
private val PILL_STYLE = DeepType.micro.copy(letterSpacing = 0.sp)

/** `HomeTile` — iOS's 150pt square, its title block 2 apart, 8 below the art. */
val HOME_TILE_SIZE = 150.dp
private val TILE_SPACING = 8.dp
private val TILE_TEXT_SPACING = 2.dp

/** The tile's lift — iOS's `shadow(lavenderMist 0.2, radius: 12, y: 8)`. */
private const val TILE_SHADOW_ALPHA = 0.2f
private val TILE_SHADOW_RADIUS = 12.dp
private val TILE_SHADOW_OFFSET_Y = 8.dp

/** The play disc's inset from the tile artwork's corner — iOS's `.padding(8)`. */
private val TILE_DISC_INSET = 8.dp

/** The lock badge's inset on a feature card — iOS's `inset: 12`, clear of the card's larger corner. */
private val FEATURE_LOCK_INSET = 12.dp

/** Kind and descriptor on a feature card's second line, told apart by weight and air — iOS's `HStack(spacing: 6)`. */
private val KIND_SPACING = 6.dp

// MARK: - Header

/**
 * A section title with an optional trailing "See all" — iOS's
 * `HomeSectionHeader`, shared by the home's carousels and the Explore grid so
 * headers read identically everywhere.
 */
@Composable
fun HomeSectionHeader(
  title: String,
  modifier: Modifier = Modifier,
  onSeeAll: (() -> Unit)? = null,
) {
  Row(
    modifier
      .fillMaxWidth()
      .padding(horizontal = Dp.edge),
    horizontalArrangement = Arrangement.spacedBy(HEADER_MIN_GAP),
  ) {
    Text(
      text = title,
      style = DeepType.sectionTitle,
      color = Color.deepPlum,
      modifier = Modifier
        .weight(1f)
        .alignByBaseline()
        .semantics { heading() },
    )
    if (onSeeAll != null) {
      Text(
        text = stringResource(R.string.home_see_all),
        style = DeepType.caption.copy(fontWeight = FontWeight.Medium),
        color = Color.lavenderMist,
        modifier = Modifier
          .alignByBaseline()
          .softPress()
          .clickable(interactionSource = null, indication = null, role = Role.Button, onClick = onSeeAll),
      )
    }
  }
}

// MARK: - Feature carousel

/**
 * A titled, horizontally scrolling shelf of [FeatureCard]s — the home's
 * "Popular now" / "Today's sessions" sections. iOS's `FeatureCarousel`.
 */
@Composable
fun FeatureCarousel(
  title: String,
  collections: List<SoundCollection>,
  onOpen: (SoundCollection) -> Unit,
  onPlay: (SoundCollection) -> Unit,
  modifier: Modifier = Modifier,
  onSeeAll: (() -> Unit)? = null,
) {
  Column(modifier, verticalArrangement = Arrangement.spacedBy(SHELF_SPACING)) {
    HomeSectionHeader(title = title, onSeeAll = onSeeAll)
    LazyRow(
      horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
      contentPadding = PaddingValues(horizontal = Dp.edge),
    ) {
      items(collections, key = { it.id }) { collection ->
        FeatureCard(collection = collection, onOpen = onOpen, onPlay = onPlay)
      }
    }
  }
}

/**
 * A large landscape card: the artwork carries the title and a duration pill,
 * a title row sits beneath. iOS's `FeatureCard`.
 */
@Composable
fun FeatureCard(
  collection: SoundCollection,
  onOpen: (SoundCollection) -> Unit,
  onPlay: (SoundCollection) -> Unit,
  modifier: Modifier = Modifier,
) {
  val shape = RoundedCornerShape(Dp.card)
  val kind = kindLabel(collection)
  val minutes = stringResource(
    R.string.deepsound_minutes,
    SoundTime.minutes(collection.totalDurationSeconds.toDouble()),
  )
  val hasPremium = rememberHasPremium()

  Column(
    modifier
      .width(FEATURE_WIDTH)
      .softPress()
      .clickable(interactionSource = null, indication = null) { onOpen(collection) }
      .collectionSemantics(collection, hasPremium, kind, minutes, onOpen, onPlay),
    verticalArrangement = Arrangement.spacedBy(FEATURE_SPACING),
  ) {
    Box(
      Modifier
        .size(FEATURE_WIDTH, FEATURE_HEIGHT)
        .dropShadow(
          shape = shape,
          shadow = Shadow(
            radius = FEATURE_SHADOW_RADIUS,
            color = Color.lavenderMist.copy(alpha = FEATURE_SHADOW_ALPHA),
            offset = DpOffset(0.dp, FEATURE_SHADOW_OFFSET_Y),
          ),
        )
        .clip(shape),
    ) {
      ArtworkImage(
        url = collection.imageUrl,
        palette = collection.palette,
        modifier = Modifier.fillMaxSize(),
      )
      Box(
        Modifier
          .fillMaxSize()
          .background(
            Brush.verticalGradient(
              colorStops = arrayOf(
                0.5f to Color.Transparent,
                1f to Color.deepPlum.copy(alpha = FEATURE_WASH_ALPHA),
              ),
            ),
          ),
      )
      Row(
        Modifier
          .align(Alignment.BottomStart)
          .fillMaxWidth()
          .padding(FEATURE_INSET),
        verticalAlignment = Alignment.Bottom,
      ) {
        Column(
          Modifier.weight(1f),
          verticalArrangement = Arrangement.spacedBy(FEATURE_TITLE_SPACING),
        ) {
          Text(
            text = collection.title,
            style = DeepType.displayTitle,
            color = Color.White,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
          )
          DurationPill(minutes)
        }
        PlayButton(collection, ArtworkDiscSize.Large, onPlay)
      }
      PremiumLockCorner(isLocked = PremiumGate.isLocked(collection, hasPremium), inset = FEATURE_LOCK_INSET)
    }

    Column(verticalArrangement = Arrangement.spacedBy(FEATURE_ROW_SPACING)) {
      Text(
        text = collection.title,
        style = DeepType.bodyMedium,
        color = Color.deepPlum,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier.fillMaxWidth(),
      )
      // Kind and descriptor told apart by weight and a little air, not a
      // middle dot — the design language has no separators. The kind keeps
      // its width; the descriptor gives way.
      Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(KIND_SPACING),
      ) {
        Text(
          text = kind,
          style = DeepType.caption.copy(fontWeight = FontWeight.Medium),
          color = Color.driftGrey,
          maxLines = 1,
          softWrap = false,
        )
        Text(
          text = collection.subtitle,
          style = DeepType.caption,
          color = Color.driftGrey,
          maxLines = 1,
          overflow = TextOverflow.Ellipsis,
          modifier = Modifier.weight(1f, fill = false),
        )
      }
    }
  }
}

/** The small white capsule on a feature card: a play glyph and the length. */
@Composable
private fun DurationPill(minutes: String) {
  Row(
    Modifier
      .background(Color.White.copy(alpha = PILL_ALPHA), CircleShape)
      .padding(horizontal = PILL_PADDING_HORIZONTAL, vertical = PILL_PADDING_VERTICAL),
    horizontalArrangement = Arrangement.spacedBy(PILL_SPACING),
    verticalAlignment = Alignment.CenterVertically,
  ) {
    Icon(SoundIcons.Play, contentDescription = null, tint = Color.deepPlum, modifier = Modifier.size(PILL_GLYPH))
    Text(minutes, style = PILL_STYLE, color = Color.deepPlum)
  }
}

// MARK: - Recommendations

/**
 * The home's "Made for you" section — a carousel of square [HomeTile]s, the
 * way DEEP Sound presents its shelves. iOS's `RecommendationsSection`: no
 * "See all".
 */
@Composable
fun RecommendationsSection(
  title: String,
  collections: List<SoundCollection>,
  onOpen: (SoundCollection) -> Unit,
  onPlay: (SoundCollection) -> Unit,
  modifier: Modifier = Modifier,
) {
  Column(modifier, verticalArrangement = Arrangement.spacedBy(SHELF_SPACING)) {
    HomeSectionHeader(title = title)
    LazyRow(
      horizontalArrangement = Arrangement.spacedBy(ROW_SPACING),
      contentPadding = PaddingValues(horizontal = Dp.edge),
    ) {
      items(collections, key = { it.id }) { collection ->
        HomeTile(collection = collection, onOpen = onOpen, onPlay = onPlay)
      }
    }
  }
}

/**
 * A square artwork tile with the play button on its corner, over a title and
 * a secondary line — DEEP Sound's `CollectionTile` with a way to play in
 * place. iOS's `HomeTile`.
 */
@Composable
fun HomeTile(
  collection: SoundCollection,
  onOpen: (SoundCollection) -> Unit,
  onPlay: (SoundCollection) -> Unit,
  modifier: Modifier = Modifier,
  size: Dp = HOME_TILE_SIZE,
) {
  val shape = RoundedCornerShape(Dp.tile)
  val kind = kindLabel(collection)
  val minutes = stringResource(
    R.string.deepsound_minutes,
    SoundTime.minutes(collection.totalDurationSeconds.toDouble()),
  )
  val hasPremium = rememberHasPremium()

  Column(
    modifier
      .width(size)
      .softPress()
      .clickable(interactionSource = null, indication = null) { onOpen(collection) }
      .collectionSemantics(collection, hasPremium, kind, minutes, onOpen, onPlay),
    verticalArrangement = Arrangement.spacedBy(TILE_SPACING),
  ) {
    Box {
      ArtworkImage(
        url = collection.imageUrl,
        palette = collection.palette,
        modifier = Modifier
          .size(size)
          .dropShadow(
            shape = shape,
            shadow = Shadow(
              radius = TILE_SHADOW_RADIUS,
              color = Color.lavenderMist.copy(alpha = TILE_SHADOW_ALPHA),
              offset = DpOffset(0.dp, TILE_SHADOW_OFFSET_Y),
            ),
          )
          .clip(shape),
      )
      PremiumLockCorner(isLocked = PremiumGate.isLocked(collection, hasPremium))
      PlayButton(
        collection,
        ArtworkDiscSize.Small,
        onPlay,
        Modifier
          .align(Alignment.BottomEnd)
          .padding(TILE_DISC_INSET),
      )
    }

    Column(verticalArrangement = Arrangement.spacedBy(TILE_TEXT_SPACING)) {
      Text(
        text = collection.title,
        style = DeepType.bodyMedium,
        color = Color.deepPlum,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier.fillMaxWidth(),
      )
      Text(
        text = collection.subtitle,
        style = DeepType.caption,
        color = Color.driftGrey,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier.fillMaxWidth(),
      )
    }
  }
}

// MARK: - Shared

/**
 * The play button — its own tap target inside the card's, so it plays in
 * place rather than opening. It stays on a DEEP Premium collection, as on
 * iOS: what it queues is the gate's to decide, in [onPlay].
 */
@Composable
private fun PlayButton(
  collection: SoundCollection,
  size: ArtworkDiscSize,
  onPlay: (SoundCollection) -> Unit,
  modifier: Modifier = Modifier,
) {
  ArtworkDisc(
    size = size,
    modifier = modifier
      .softPress()
      .clickable(interactionSource = null, indication = null, role = Role.Button) { onPlay(collection) },
  )
}

/**
 * One element for TalkBack — iOS's `.accessibilityElement(children: .combine)`
 * with its "title, kind, length" label — opening the collection on activation
 * and carrying "Play …" as a custom action, since the play button inside is
 * folded into it. A locked collection says it is part of DEEP Premium instead
 * of offering to play.
 */
@Composable
private fun Modifier.collectionSemantics(
  collection: SoundCollection,
  hasPremium: Boolean,
  kind: String,
  minutes: String,
  onOpen: (SoundCollection) -> Unit,
  onPlay: (SoundCollection) -> Unit,
): Modifier {
  val locked = PremiumGate.isLocked(collection, hasPremium)
  val canPlay = PremiumGate.playable(collection, hasPremium).isNotEmpty()
  val label = listOfNotNull(
    collection.title,
    kind,
    minutes,
    if (locked) stringResource(R.string.premium_part_of) else null,
  ).joinToString(", ")
  val playLabel = stringResource(R.string.home_play_collection, collection.title)
  return clearAndSetSemantics {
    contentDescription = label
    role = Role.Button
    onClick { onOpen(collection); true }
    // Offered only when the play button would start something.
    if (canPlay) {
      customActions = listOf(CustomAccessibilityAction(playLabel) { onPlay(collection); true })
    }
  }
}

/**
 * iOS's `SoundCollection.kindLabel`: any guided track makes the collection
 * read as guided; otherwise it's a soundscape.
 */
@Composable
private fun kindLabel(collection: SoundCollection): String = stringResource(
  if (collection.tracks.any { it.kind == TrackKind.Guided }) R.string.home_kind_guided else R.string.home_kind_soundscape,
)

// MARK: - Previews

@Preview(showBackground = true, name = "Feature carousel")
@Composable
private fun FeatureCarouselPreview() {
  DeepTheme {
    Box(Modifier.background(Color.moonCream)) {
      AtmosphereBackground(animated = false)
      FeatureCarousel(
        title = "Popular now",
        collections = SoundFixtures.sleep,
        onOpen = {},
        onPlay = {},
        onSeeAll = {},
        modifier = Modifier.padding(vertical = Dp.edge),
      )
    }
  }
}

@Preview(showBackground = true, name = "Feature carousel — DEEP Premium locked")
@Composable
private fun FeatureCarouselLockedPreview() {
  DeepTheme {
    CompositionLocalProvider(LocalPremiumAccess provides FakePremiumAccess(hasPremium = false)) {
      Box(Modifier.background(Color.moonCream)) {
        AtmosphereBackground(animated = false)
        FeatureCarousel(
          title = "Popular now",
          collections = listOf(SoundFixtures.premiumSample) + SoundFixtures.sleep,
          onOpen = {},
          onPlay = {},
          modifier = Modifier.padding(vertical = Dp.edge),
        )
      }
    }
  }
}

@Preview(showBackground = true, name = "Recommendations — one locked")
@Composable
private fun RecommendationsPreview() {
  DeepTheme {
    CompositionLocalProvider(LocalPremiumAccess provides FakePremiumAccess(hasPremium = false)) {
      Box(Modifier.background(Color.moonCream)) {
        AtmosphereBackground(animated = false)
        RecommendationsSection(
          title = "Made for you",
          collections = listOf(SoundFixtures.oceanDepths, SoundFixtures.premiumSample, SoundFixtures.eveningLight),
          onOpen = {},
          onPlay = {},
          modifier = Modifier.padding(vertical = Dp.edge),
        )
      }
    }
  }
}

@Preview(showBackground = true, name = "Recommendations — member")
@Composable
private fun RecommendationsMemberPreview() {
  DeepTheme {
    CompositionLocalProvider(LocalPremiumAccess provides FakePremiumAccess(hasPremium = true)) {
      Box(Modifier.background(Color.moonCream)) {
        AtmosphereBackground(animated = false)
        RecommendationsSection(
          title = "Made for you",
          collections = listOf(SoundFixtures.oceanDepths, SoundFixtures.premiumSample, SoundFixtures.eveningLight),
          onOpen = {},
          onPlay = {},
          modifier = Modifier.padding(vertical = Dp.edge),
        )
      }
    }
  }
}

@Preview(showBackground = true, name = "Section header")
@Composable
private fun HomeSectionHeaderPreview() {
  DeepTheme {
    Column(
      Modifier.background(Color.moonCream).padding(vertical = Dp.edge),
      verticalArrangement = Arrangement.spacedBy(Dp.edge),
    ) {
      HomeSectionHeader(title = "Popular now", onSeeAll = {})
      HomeSectionHeader(title = "Explore")
    }
  }
}
