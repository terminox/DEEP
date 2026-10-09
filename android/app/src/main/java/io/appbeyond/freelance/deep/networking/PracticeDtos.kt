package io.appbeyond.freelance.deep.networking

import io.appbeyond.freelance.deep.feature.practice.model.PracticeCompletion
import io.appbeyond.freelance.deep.feature.practice.store.PracticePushResult
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.UUID

/*
 * Wire shapes for the practice journal's sync, ported from `DTOs.swift`
 * (`PracticeSessionDTO`, `PracticeSyncRequestDTO`, `PracticeSyncResponseDTO`,
 * `PracticeSessionsResponseDTO`) and checked against `routes/practice.ts`.
 *
 * Dates and ids cross the wire as plain strings and are parsed per entry in
 * the mapping, not by the decoder: one malformed row in a pulled log of a
 * thousand must cost that row, never the whole merge (`APIPracticeRemote.fetchAll`
 * `compactMap`s the same way).
 */

/** One completion offered up — every field required by the route's zod schema. */
@Serializable
data class PracticeSessionRequest(
  val id: String,
  val title: String,
  val durationSeconds: Int,
  /** UTC ISO-8601 ending in `Z` — see [wireTimestamp]. */
  val completedAt: String,
)

/** `POST /me/practice/sessions` body; at most 200 per request (`PracticeJournal.MAX_PUSH_BATCH`). */
@Serializable
data class PracticeSyncRequest(
  val sessions: List<PracticeSessionRequest>,
)

/**
 * `POST /me/practice/sessions`. [synced] echoes every id the server accepted
 * (new and already-stored alike); [awards] holds one outcome per session still
 * inside the award window; [wallet] and [plant] are fetched after the grants.
 */
@Serializable
data class PracticeSyncResponseDto(
  val synced: List<String> = emptyList(),
  val awards: List<AwardOutcomeDto> = emptyList(),
  val wallet: WalletDto? = null,
  val plant: PlantProgressDto? = null,
)

/** One stored session as `serializeSession` writes it — every field optional so a bad row is dropped, not fatal. */
@Serializable
data class PracticeSessionDto(
  val id: String? = null,
  val title: String? = null,
  val durationSeconds: Int? = null,
  val completedAt: String? = null,
)

/** `GET /me/practice/sessions` — the member's log, newest first, capped at 1,000. */
@Serializable
data class PracticeSessionsResponseDto(
  val sessions: List<PracticeSessionDto> = emptyList(),
)

// MARK: - Mapping

/**
 * The timestamp the route's `z.string().datetime()` accepts: UTC with a `Z`.
 * Zod's default refuses a numeric offset, so the device's zone must never leak
 * into it. Truncated to milliseconds to match what the server's own
 * `toISOString()` writes back.
 */
internal fun wireTimestamp(instant: Instant): String =
  DateTimeFormatter.ISO_INSTANT.format(instant.truncatedTo(ChronoUnit.MILLIS))

fun PracticeCompletion.toRequest(): PracticeSessionRequest = PracticeSessionRequest(
  id = id.toString(),
  title = title,
  durationSeconds = durationSeconds,
  completedAt = wireTimestamp(completedAt),
)

/** The accepted ids (unparseable ones dropped) plus the batch's awards folded into one grant. */
fun PracticeSyncResponseDto.toDomain(): PracticePushResult = PracticePushResult(
  synced = synced.mapNotNull { uuidOrNull(it) },
  grant = foldAwards(awards, wallet, plant),
)

/** Ported from `APIPracticeRemote.fetchAll`: a row without a valid id or date is dropped. */
fun PracticeSessionsResponseDto.toDomain(): List<PracticeCompletion> = sessions.mapNotNull { dto ->
  val id = dto.id?.let(::uuidOrNull) ?: return@mapNotNull null
  val completedAt = dto.completedAt
    ?.let { runCatching { IsoInstantSerializer.parse(it) }.getOrNull() }
    ?: return@mapNotNull null
  PracticeCompletion(
    id = id,
    title = dto.title ?: "",
    durationSeconds = dto.durationSeconds ?: 0,
    completedAt = completedAt,
    isSynced = true,
  )
}

private fun uuidOrNull(text: String): UUID? = runCatching { UUID.fromString(text) }.getOrNull()
