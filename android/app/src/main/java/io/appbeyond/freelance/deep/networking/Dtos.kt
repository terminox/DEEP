package io.appbeyond.freelance.deep.networking

import kotlinx.serialization.Serializable

/*
 * Wire shapes for the Deep API, ported from `DTOs.swift`.
 *
 * These mirror the backend's JSON exactly — plain camelCase, so no naming
 * strategy is configured — and are mapped into the app's domain models by each
 * repository, keeping transport concerns out of the UI types. The contract they
 * track is `deep-api/src/lib/serialize.ts`, which is the one place Prisma rows
 * become JSON.
 *
 * Week one covers `GET /pause/home` and nothing else.
 *
 * Every optional field carries a default, because kotlinx.serialization treats a
 * missing key as an error where Swift's `Decodable` treats it as `nil`. A field
 * without a default here is one the backend is contractually obliged to send.
 */

/**
 * `GET /pause/home` — the Global Pause home in one call.
 *
 * Sections carry complete collections *with their tracks*, so opening or playing
 * one needs no follow-up fetch. Anonymous requests are fine: the route runs
 * `optionalAuth` and falls back to deterministic picks, so nothing here requires
 * a signed-in member.
 */
@Serializable
data class PauseHomeDto(
  val sections: List<PauseSectionDto> = emptyList(),
  val categories: List<CategoryDto> = emptyList(),
)

/**
 * One server-composed shelf: `popular`, `today` or `forYou`.
 *
 * [personalized] is true only on `forYou`, and only when the member has an
 * onboarding profile behind it — the signal a screen needs to decide whether
 * "Made for you" has earned its name.
 */
@Serializable
data class PauseSectionDto(
  val key: String,
  val title: String,
  val personalized: Boolean = false,
  val collections: List<CollectionDto> = emptyList(),
)

/**
 * A collection as `serializeCollection` writes it.
 *
 * [imageUrl] is null for a collection with no artwork yet, and [tracks] is absent
 * — not empty — wherever the server sent the collection without loading them
 * (`/pause/home` always loads them; other routes do not). [trackCount] is the
 * count only where the server counted, so a null there means "unknown", never
 * "zero".
 *
 * [subtitle] is nullable here although the column is not, because the translated
 * projection may resolve to nothing for a language that has no override.
 */
@Serializable
data class CollectionDto(
  val id: String,
  val categoryId: String,
  val title: String,
  val subtitle: String? = null,
  val palette: String,
  val imageUrl: String? = null,
  val isPremium: Boolean = false,
  val displayOrder: Int = 0,
  val trackCount: Int? = null,
  val tracks: List<TrackDto>? = null,
)

/**
 * A track as `serializeTrack` writes it.
 *
 * [kind] is `INSTRUMENTAL` or `GUIDED`, left a `String` exactly as iOS leaves it:
 * an unknown enum case from a server that has learned a third kind should not
 * fail the whole response.
 *
 * [audioUrl] is null when the row has no audio uploaded yet, which the admin
 * allows — a track that cannot be played is a real state, not a decoding error.
 */
@Serializable
data class TrackDto(
  val id: String,
  val title: String,
  val durationSeconds: Int,
  val kind: String,
  val audioUrl: String? = null,
  val isPremium: Boolean = false,
  val displayOrder: Int = 0,
  val lyricsLanguages: List<String> = emptyList(),
)

/**
 * A category as `serializeCategory` writes it — the Explore grid's backbone.
 *
 * [collections] and [collectionCount] follow the same absent-versus-empty rule as
 * [CollectionDto.tracks]. On `/pause/home` the collections are always present.
 */
@Serializable
data class CategoryDto(
  val id: String,
  val slug: String,
  val title: String,
  val displayOrder: Int = 0,
  val collectionCount: Int? = null,
  val collections: List<CollectionDto>? = null,
)
