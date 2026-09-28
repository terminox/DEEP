package io.appbeyond.freelance.deep.networking

import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundShelf
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundTrack
import io.appbeyond.freelance.deep.feature.deepsound.model.TrackKind
import io.appbeyond.freelance.deep.feature.deepsound.model.TrackLyrics
import kotlinx.serialization.Contextual
import kotlinx.serialization.Serializable
import java.time.Instant

/*
 * Wire shapes for Deep Sound and playlists, ported from `DTOs.swift`
 * (`SoundHomeDTO`, `LyricsDTO`/`LyricsResponseDTO`, `PlaylistDTO`,
 * `PlaylistItemDTO`, `PlaylistsResponseDTO`, `PlaylistResponseDTO`,
 * `SaveTrackRequestDTO`). `CategoryDto`/`CollectionDto`/`TrackDto` already
 * cover `/sound/home`'s categories (Dtos.kt); this file adds the envelope and
 * the mapping down to `:core:model`, plus the playlist shapes
 * `deep-api/src/lib/serialize.ts` writes for `serializePlaylist` /
 * `serializePlaylistItem` / `serializeLyrics`.
 *
 * `savedAt`/`updatedAt` decode straight to [Instant] via [IsoInstantSerializer],
 * registered contextually on [DeepJson] — no hand-rolled ISO parsing needed
 * the way `APIPlaylistRemote` carries its own on iOS.
 */

/** `GET /sound/home` — every category, ordered, with its ordered collections and tracks. */
@Serializable
data class SoundHomeDto(
  val categories: List<CategoryDto> = emptyList(),
)

/** A track's lyrics in one language, as `serializeLyrics` writes it. */
@Serializable
data class LyricsDto(
  val id: String,
  val trackId: String,
  val languageCode: String,
  val content: String,
)

/** `GET /sound/tracks/{id}/lyrics` — empty for a track with none, never absent. */
@Serializable
data class LyricsResponseDto(
  val lyrics: List<LyricsDto> = emptyList(),
)

/**
 * A saved-sound row, as `serializePlaylistItem` writes it. [collection] rides
 * along without its own [CollectionDto.tracks] — a kept-track row needs the
 * artwork and the origin name, nothing more.
 */
@Serializable
data class PlaylistItemDto(
  val id: String,
  @Contextual val savedAt: Instant,
  val track: TrackDto,
  val collection: CollectionDto,
)

/**
 * A playlist, as `serializePlaylist` writes it. [items] is absent — not empty
 * — wherever the server sent the playlist without loading them; every
 * playlist route here always loads them, so in practice this is never null.
 */
@Serializable
data class PlaylistDto(
  val id: String,
  val name: String,
  val isDefault: Boolean = false,
  val trackCount: Int = 0,
  @Contextual val updatedAt: Instant,
  val items: List<PlaylistItemDto>? = null,
)

/** `GET /me/playlists` — every playlist the member has, each with its items. */
@Serializable
data class PlaylistsResponseDto(
  val playlists: List<PlaylistDto> = emptyList(),
)

/** `POST .../items` and `DELETE .../items/{trackId}` both answer with the whole playlist. */
@Serializable
data class PlaylistResponseDto(
  val playlist: PlaylistDto,
)

/** `POST /me/playlists/{id}/items` body. */
@Serializable
data class PlaylistItemRequest(
  val trackId: String,
)

// MARK: - Mapping down to :core:model

/** [ApiSoundLibrary]'s `home()`; also called directly by `MockSoundLibrary`'s fixtures. */
fun SoundHomeDto.toShelves(): List<SoundShelf> = categories.map { it.toShelf() }

private fun CategoryDto.toShelf(): SoundShelf = SoundShelf(
  id = id,
  title = title,
  collections = (collections ?: emptyList())
    .sortedBy { it.displayOrder }
    .map { it.toDomain() },
)

/**
 * Ported from `APISoundContentRepository.collection(from:)`. Also used by
 * `ApiPlaylistStore` to map a saved sound's origin collection — the same
 * projection Deep Sound's shelves use, exactly as `APIPlaylistRemote` reuses
 * `APISoundContentRepository`'s statics rather than mapping its own copy.
 *
 * [CollectionDto.subtitle] defaults to empty rather than the DTO's `null`: the
 * column is not nullable, only its translated projection can miss, and
 * `SoundCollection.subtitle` is not optional on either platform.
 */
fun CollectionDto.toDomain(): SoundCollection = SoundCollection(
  id = id,
  title = title,
  subtitle = subtitle ?: "",
  palette = palette,
  imageUrl = imageUrl,
  categoryId = categoryId,
  isPremium = isPremium,
  tracks = (tracks ?: emptyList())
    .sortedBy { it.displayOrder }
    .map { it.toDomain() },
)

/** Ported from `APISoundContentRepository.track(from:)`. */
fun TrackDto.toDomain(): SoundTrack = SoundTrack(
  id = id,
  title = title,
  durationSeconds = durationSeconds,
  kind = TrackKind.fromServer(kind),
  audioUrl = audioUrl,
  isPremium = isPremium,
  lyricsLanguages = lyricsLanguages,
)

/** [ApiSoundLibrary]'s `lyrics(trackId:)`. */
fun LyricsResponseDto.toDomain(): List<TrackLyrics> =
  lyrics.map { TrackLyrics(languageCode = it.languageCode, content = it.content) }
