package io.appbeyond.freelance.deep.feature.deepsound.model

/**
 * Deep Sound's content, as the app holds it once `/sound/home` has been mapped.
 *
 * Ported from Deep/Deep/Features/DeepSound/Models/SoundContent.swift. URLs stay
 * plain strings — this module has no Android — and `palette` stays the server's
 * name for it; `ArtworkImage` owns the fallback for a name it does not know.
 */
enum class TrackKind {
  Instrumental,
  Guided,
  ;

  companion object {
    /** The server sends `GUIDED` or `INSTRUMENTAL`; anything else reads as instrumental. */
    fun fromServer(kind: String?): TrackKind = if (kind == "GUIDED") Guided else Instrumental
  }
}

/**
 * A single track inside a collection. `audioUrl` is the streaming source; `null`
 * means there is nothing to play (fixture content, or a row with no audio yet).
 */
data class SoundTrack(
  val id: String,
  val title: String,
  val durationSeconds: Int,
  val kind: TrackKind = TrackKind.Instrumental,
  val audioUrl: String? = null,
  val isPremium: Boolean = false,
  val lyricsLanguages: List<String> = emptyList(),
)

/** A collection of tracks — Deep Sound's equivalent of an album. */
data class SoundCollection(
  val id: String,
  val title: String,
  val subtitle: String,
  val palette: String?,
  val imageUrl: String?,
  val categoryId: String = "",
  val isPremium: Boolean = false,
  val tracks: List<SoundTrack> = emptyList(),
) {
  val trackCount: Int get() = tracks.size
  val totalDurationSeconds: Int get() = tracks.sumOf { it.durationSeconds }

  /** Every track as a queue entry, all sharing this collection. */
  fun queue(): List<SoundQueueEntry> = tracks.map { SoundQueueEntry(it, this) }
}

/** A shelf on the Deep Sound home: a category and its collections. */
data class SoundShelf(
  val id: String,
  val title: String,
  val collections: List<SoundCollection>,
)

/**
 * A track together with the collection it came from. A collection plays as a
 * run of entries sharing one collection; a playlist's entries each carry their
 * own, so artwork and the origin line follow the track, not the queue.
 */
data class SoundQueueEntry(
  val track: SoundTrack,
  val collection: SoundCollection,
)
