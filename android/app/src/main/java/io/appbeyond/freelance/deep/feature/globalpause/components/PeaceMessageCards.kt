package io.appbeyond.freelance.deep.feature.globalpause.components

import android.text.format.DateUtils
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.dropShadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.shadow.Shadow
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.globalpause.model.Intention
import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessage
import io.appbeyond.freelance.deep.feature.globalpause.store.FixturePauseEventRemote
import io.appbeyond.freelance.deep.shared.components.AtmosphereBackground
import io.appbeyond.freelance.deep.shared.components.DeepTagLabel
import io.appbeyond.freelance.deep.theme.DeepTheme
import io.appbeyond.freelance.deep.theme.DeepType
import io.appbeyond.freelance.deep.theme.blushPowder
import io.appbeyond.freelance.deep.theme.deepPlum
import io.appbeyond.freelance.deep.theme.driftGrey
import io.appbeyond.freelance.deep.theme.edge
import io.appbeyond.freelance.deep.theme.frostedCard
import io.appbeyond.freelance.deep.theme.lavenderMist
import io.appbeyond.freelance.deep.theme.peachCloud
import io.appbeyond.freelance.deep.theme.skyWash
import io.appbeyond.freelance.deep.theme.tile
import java.time.Instant
import kotlin.math.abs

/*
 * The parts a peace message is made of, shared by the card in Fuku's Lounge
 * and the composer the member writes into at the end of a pause. One file on
 * purpose: the composer is a *preview* of the card, so the two must be the
 * same object. Anything that lives in only one of them is a promise the other
 * breaks.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Components/PeaceMessageCardChrome.swift
 * and PeaceMessagesSection.swift.
 */

/** The surface every peace message sits on, composed or published. */
fun Modifier.peaceMessageCard(): Modifier =
  fillMaxWidth()
    .frostedCard(cornerRadius = Dp.tile)
    .padding(14.dp)

/** A radial-gradient avatar with a serif italic initial. */
@Composable
fun PeaceMessageAvatar(tint: Color, initial: String, modifier: Modifier = Modifier) {
  Box(
    modifier
      .size(32.dp)
      .dropShadow(CircleShape, Shadow(radius = 6.dp, color = tint.copy(alpha = 0.4f), offset = DpOffset(0.dp, 3.dp)))
      .drawBehind {
        // From the top-leading corner out to 24dp, as iOS's RadialGradient.
        drawCircle(
          Brush.radialGradient(
            listOf(Color.White.copy(alpha = 0.95f), tint.copy(alpha = 0.85f)),
            center = Offset.Zero,
            radius = 24.dp.toPx(),
          ),
        )
      }
      .border(0.6.dp, Color.White.copy(alpha = 0.7f), CircleShape),
    contentAlignment = Alignment.Center,
  ) {
    Text(
      text = initial,
      fontFamily = FontFamily.Serif,
      fontStyle = FontStyle.Italic,
      fontWeight = FontWeight.Light,
      fontSize = 15.sp,
      color = Color.deepPlum.copy(alpha = 0.85f),
    )
  }
}

/**
 * Who left the message, and where from — the two lines that head every card.
 * The place is absent rather than blank when it isn't known.
 *
 * @param tintSeed a message id in the feed, the member's own name in the
 *   composer, so a person's colour holds still.
 */
@Composable
fun PeaceMessageIdentity(name: String, place: String, tintSeed: String, modifier: Modifier = Modifier) {
  Row(modifier, horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
    PeaceMessageAvatar(tint = peaceTint(tintSeed), initial = name.firstOrNull()?.toString() ?: "?")
    // Weighted, not beside a Spacer: a Spacer bids against the text column.
    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
      Text(name, style = DeepType.bodyMedium, color = Color.deepPlum, maxLines = 1, overflow = TextOverflow.Ellipsis)
      if (place.isNotEmpty()) {
        Text(place, style = DeepType.micro, color = Color.driftGrey, maxLines = 1, overflow = TextOverflow.Ellipsis)
      }
    }
  }
}

/** Hashes the seed into one of four tints, as iOS does, so a message keeps
 * its colour across refreshes. */
fun peaceTint(seed: String): Color {
  val tints = listOf(Color.lavenderMist, Color.blushPowder, Color.skyWash, Color.peachCloud)
  var hash = 0L
  for (byte in seed.toByteArray(Charsets.UTF_8)) hash = hash * 31 + (byte.toInt() and 0xFF)
  return tints[(abs(hash) % tints.size).toInt()]
}

/**
 * The titled list of messages in Fuku's Lounge. Rendered as items of the
 * lounge's own lazy list (see `GlobalPauseLobbyScreen`); this is one card.
 */
@Composable
fun PeaceMessageCard(message: PeaceMessage, intentions: List<Intention>, modifier: Modifier = Modifier) {
  val locale = LocalConfiguration.current.locales[0]
  val place = message.countryName(locale)
  val tag = message.intentionLabel(intentions)
  val ago = relativeAgo(message.createdAt)
  val quoted = stringResource(R.string.pause_message_quoted, message.text)
  val spoken = buildList {
    add(message.displayName)
    if (place.isNotEmpty()) add(stringResource(R.string.pause_message_a11y_from, place))
    add(stringResource(R.string.pause_message_a11y_says, message.text))
    add(ago)
    if (tag != null) add(stringResource(R.string.pause_message_a11y_tagged, tag))
  }.joinToString(", ")

  Column(
    modifier
      .peaceMessageCard()
      .clearAndSetSemantics { contentDescription = spoken },
    verticalArrangement = Arrangement.spacedBy(10.dp),
  ) {
    PeaceMessageIdentity(name = message.displayName, place = place, tintSeed = message.id)
    Text(
      quoted,
      style = DeepType.caption.copy(lineHeight = DeepType.caption.lineHeight * 1.1f),
      color = Color.deepPlum.copy(alpha = 0.78f),
      modifier = Modifier.fillMaxWidth(),
    )
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
      Text(ago, style = DeepType.micro, color = Color.driftGrey, modifier = Modifier.weight(1f))
      if (tag != null) DeepTagLabel(label = tag)
    }
  }
}

/** "5 minutes ago", in the member's language — iOS's `.relative(presentation: .named)`. */
@Composable
private fun relativeAgo(at: Instant): String {
  // Read per composition, so a card scrolled back to reads its age as now.
  LocalConfiguration.current
  return DateUtils.getRelativeTimeSpanString(
    at.toEpochMilli(),
    System.currentTimeMillis(),
    DateUtils.MINUTE_IN_MILLIS,
  ).toString()
}

@Preview(showBackground = true, name = "Peace message")
@Composable
private fun PeaceMessageCardPreview() {
  DeepTheme {
    Box {
      AtmosphereBackground()
      Column(Modifier.padding(Dp.edge), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        FixturePauseEventRemote.sampleMessages(Instant.now()).take(3).forEach {
          PeaceMessageCard(it, FixturePauseEventRemote.sampleIntentions)
        }
        PeaceMessageIdentity(name = "Friend", place = "", tintSeed = "friend", modifier = Modifier.peaceMessageCard())
      }
    }
  }
}
