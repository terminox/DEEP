package io.appbeyond.freelance.deep.networking

import io.appbeyond.freelance.deep.feature.globalpause.model.Intention
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseLiveSnapshot
import io.appbeyond.freelance.deep.feature.globalpause.model.PausePhaseKey
import io.appbeyond.freelance.deep.feature.globalpause.model.PausePhaseWindow
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseSchedule
import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessage
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Duration

/*
 * Wire shapes for the live Global Pause event, checked field by field against
 * what `deep-api/src/routes/pauseLive.ts` writes (`/pause/schedule`,
 * `/pause/presence/…`, `/pause/live`, `/pause/messages`, `/pause/reflection`,
 * `/me/pause/award`) and ported from the pause DTOs in `DTOs.swift`.
 *
 * Instants travel as ISO strings and are parsed in the mapping
 * ([IsoInstantSerializer.parse]) rather than by a contextual serializer, so a
 * malformed date fails one field's mapping rather than the whole decode.
 * Fields an older server may omit default here, as the Swift DTOs' optionals do.
 *
 * The server spells it `countryISO`; Kotlin's naming rules spell it
 * `countryIso`, so those carry a `@SerialName`.
 */

// MARK: - Schedule

/** One phase window. An unknown [key] from a newer server is dropped in mapping. */
@Serializable
data class PausePhaseDto(
  val key: String,
  val startsAt: String,
  val endsAt: String,
)

@Serializable
data class PauseIntentionDto(
  val key: String,
  val label: String,
)

/** `GET /pause/schedule` — the occurrence under way, else the next. */
@Serializable
data class PauseScheduleDto(
  val serverNow: String,
  val pauseDate: String,
  val slotId: String? = null,
  val timezone: String,
  val phases: List<PausePhaseDto> = emptyList(),
  val nextMeditationStartsAt: String? = null,
  val lobbyAudioUrl: String? = null,
  val lobbyDurationSeconds: Int? = null,
  val meditationAudioUrl: String? = null,
  val meditationDurationSeconds: Int = 0,
  val welcomeMessages: List<String> = emptyList(),
  val intentions: List<PauseIntentionDto> = emptyList(),
)

// MARK: - Presence

/** `POST /pause/presence/heartbeat` body. [countryIso] is omitted, never null:
 * zod's `.optional()` refuses an explicit null. */
@Serializable
data class PauseHeartbeatRequest(
  val presenceId: String,
  @SerialName("countryISO") val countryIso: String? = null,
)

@Serializable
data class PauseLocationDto(
  val lat: Double,
  val lon: Double,
)

/** The heartbeat's reply. [location] is the caller's own privacy-rounded
 * position, null when the server couldn't place the IP. */
@Serializable
data class PauseHeartbeatResponse(
  val ok: Boolean = true,
  val serverNow: String? = null,
  val location: PauseLocationDto? = null,
)

/** `{ ok, serverNow }` — the presence leave and the reflection answer with this. */
@Serializable
data class PauseOkResponse(
  val ok: Boolean = true,
  val serverNow: String? = null,
)

// MARK: - Live

@Serializable
data class PauseCountDto(
  val iso: String,
  val count: Int,
)

@Serializable
data class PausePointDto(
  val lat: Double,
  val lon: Double,
  val count: Int,
)

@Serializable
data class PauseJoinDto(
  val iso: String,
  val at: String,
  val lat: Double? = null,
  val lon: Double? = null,
)

/**
 * `GET /pause/live`. [messages] rides along for tonight's feed but is not read:
 * the lounge pages `GET /pause/messages` instead, as iOS does.
 */
@Serializable
data class PauseLiveDto(
  val serverNow: String,
  val phase: String? = null,
  val participantCount: Int = 0,
  val byCountry: List<PauseCountDto> = emptyList(),
  val byContinent: List<PauseCountDto>? = null,
  val unlocatedByCountry: List<PauseCountDto>? = null,
  val points: List<PausePointDto>? = null,
  val recentJoins: List<PauseJoinDto> = emptyList(),
)

// MARK: - Messages and the reflection

@Serializable
data class PeaceMessageDto(
  val id: String,
  val displayName: String,
  @SerialName("countryISO") val countryIso: String? = null,
  val text: String,
  val intention: String? = null,
  val createdAt: String,
)

/** `GET /pause/messages` — newest first, keyset-paged by an opaque cursor. */
@Serializable
data class PeaceMessagesResponse(
  val serverNow: String? = null,
  val messages: List<PeaceMessageDto> = emptyList(),
  val nextCursor: String? = null,
)

/** `POST /pause/messages` body. Absent fields are omitted, never null. */
@Serializable
data class PeaceMessagePostRequest(
  val text: String,
  @SerialName("countryISO") val countryIso: String? = null,
  val intention: String? = null,
)

/**
 * `POST /pause/messages` — the stored message, plus the award the night's
 * first message earns (`duplicate` for every later one) and the shared
 * `{ wallet, plant }` tail.
 */
@Serializable
data class PeaceMessagePostResponse(
  val message: PeaceMessageDto,
  val serverNow: String? = null,
  val award: AwardOutcomeDto? = null,
  val wallet: WalletDto? = null,
  val plant: PlantProgressDto? = null,
)

/** `POST /pause/reflection` body — at least one of the two. */
@Serializable
data class PauseReflectionRequest(
  val intention: String? = null,
  val mood: String? = null,
)

/** `POST /me/pause/award`. [eligible] reads true when absent, as iOS's does. */
@Serializable
data class PauseAwardResponse(
  val eligible: Boolean? = null,
  val award: AwardOutcomeDto? = null,
  val wallet: WalletDto? = null,
  val plant: PlantProgressDto? = null,
  val serverNow: String? = null,
)

// MARK: - Mapping down to :core:model

fun PauseScheduleDto.toDomain(): PauseSchedule = PauseSchedule(
  pauseDate = pauseDate,
  timezone = timezone,
  phases = phases.mapNotNull { phase ->
    PausePhaseKey.fromWire(phase.key)?.let { key ->
      PausePhaseWindow(
        key = key,
        startsAt = IsoInstantSerializer.parse(phase.startsAt),
        endsAt = IsoInstantSerializer.parse(phase.endsAt),
      )
    }
  },
  lobbyAudioUrl = lobbyAudioUrl,
  lobbyDuration = Duration.ofSeconds((lobbyDurationSeconds ?: 0).toLong()),
  meditationAudioUrl = meditationAudioUrl,
  meditationDuration = Duration.ofSeconds(meditationDurationSeconds.toLong()),
  nextOccurrenceMeditationStart = nextMeditationStartsAt?.let(IsoInstantSerializer::parse),
  welcomeMessages = welcomeMessages,
  intentions = intentions.map { Intention(key = it.key, label = it.label) },
)

/** Keeps the first of any repeated key, as iOS's `uniquingKeysWith` does. */
private fun List<PauseCountDto>.tally(): Map<String, Int> {
  val out = LinkedHashMap<String, Int>()
  for (entry in this) out.putIfAbsent(entry.iso, entry.count)
  return out
}

fun PauseLiveDto.toDomain(): PauseLiveSnapshot = PauseLiveSnapshot(
  serverNow = IsoInstantSerializer.parse(serverNow),
  participantCount = participantCount,
  byCountry = byCountry.tally(),
  byContinent = byContinent.orEmpty().tally(),
  locations = points.orEmpty().map { PauseLiveSnapshot.GeoPoint(it.lat.toFloat(), it.lon.toFloat(), it.count) },
  unlocatedByCountry = unlocatedByCountry.orEmpty().tally(),
  recentJoins = recentJoins.map {
    PauseLiveSnapshot.Join(
      iso = it.iso,
      at = IsoInstantSerializer.parse(it.at),
      lat = it.lat?.toFloat(),
      lon = it.lon?.toFloat(),
    )
  },
)

fun PeaceMessageDto.toDomain(): PeaceMessage = PeaceMessage(
  id = id,
  displayName = displayName,
  countryIso = countryIso,
  text = text,
  intention = intention,
  createdAt = IsoInstantSerializer.parse(createdAt),
)
