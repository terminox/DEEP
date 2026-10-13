package io.appbeyond.freelance.deep.feature.globalpause.model

import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import java.time.Instant
import java.util.Locale

/**
 * A message left after the meditation, shown back to everyone in Fuku's
 * Lounge.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Models/PeaceMessage.swift.
 *
 * @property intention the key the author tagged it with, null when untagged.
 *   Resolved to display copy against tonight's options.
 */
data class PeaceMessage(
  val id: String,
  val displayName: String,
  val countryIso: String?,
  val text: String,
  val intention: String?,
  val createdAt: Instant,
) {

  /** The country's display name in [locale]; empty when the place isn't known. */
  fun countryName(locale: Locale): String {
    val iso = countryIso ?: return ""
    val name = Locale("", iso).getDisplayCountry(locale)
    return name.ifBlank { iso }
  }

  /**
   * The tag's display label, looked up in the options tonight's schedule
   * carries. Falls back to the key humanised, so a word retired in the admin
   * still reads on the older messages that carry it.
   */
  fun intentionLabel(options: List<Intention>): String? {
    val key = intention ?: return null
    options.firstOrNull { it.key == key }?.let { return it.label }
    return key.replace('-', ' ')
      .split(' ')
      .joinToString(" ") { word -> word.replaceFirstChar { it.titlecase(Locale.ROOT) } }
  }
}

/** One page of the feed. [nextCursor] is opaque; null means the feed is exhausted. */
data class PeaceMessagesPage(
  val messages: List<PeaceMessage>,
  val nextCursor: String?,
)

/**
 * A freshly posted message, plus the award the first message of the night
 * earns — null for every later message.
 */
data class PostedPeaceMessage(
  val message: PeaceMessage,
  val award: AwardGrant?,
)
