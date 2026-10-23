package io.appbeyond.freelance.deep.feature.deepsound.model

/**
 * DEEP Sound's content, as the app holds it once `/sound/home` has been mapped.
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
 * means there is nothing to play (fixture content, a row with no audio yet, or
 * a locked track).
 *
 * [isLocked] is the server's effective answer for this listener — DEEP
 * Premium content they are not a member for (a premium track, or any track of
 * a premium collection). A locked track arrives with its title, duration and
 * lyric languages but no `audioUrl`, and never joins a queue (see
 * [SoundQueue.playable]). A server that predates the lock sends no flag, which
 * reads as unlocked.
 */
data class SoundTrack(
  val id: String,
  val title: String,
  val durationSeconds: Int,
  val kind: TrackKind = TrackKind.Instrumental,
  val audioUrl: String? = null,
  val isPremium: Boolean = false,
  val isLocked: Boolean = false,
  val lyricsLanguages: List<String> = emptyList(),
)

/**
 * A collection of tracks — DEEP Sound's equivalent of an album.
 *
 * [isLocked] is the server's answer for a premium collection this listener is
 * not a member for; its tracks then all arrive locked too.
 */
data class SoundCollection(
  val id: String,
  val title: String,
  val subtitle: String,
  val palette: String?,
  val imageUrl: String?,
  val categoryId: String = "",
  val isPremium: Boolean = false,
  val isLocked: Boolean = false,
  val tracks: List<SoundTrack> = emptyList(),
) {
  val trackCount: Int get() = tracks.size
  val totalDurationSeconds: Int get() = tracks.sumOf { it.durationSeconds }

  /**
   * True when nothing here can play for this listener: the collection itself
   * is locked, or every one of its tracks is (a free collection holding only
   * premium tracks). A collection sent without its tracks goes by its own flag.
   * What a card's lock glyph reads.
   */
  val locksEveryTrack: Boolean
    get() = isLocked || (tracks.isNotEmpty() && tracks.all { it.isLocked })

  /** Every track as a queue entry, all sharing this collection. */
  fun queue(): List<SoundQueueEntry> = tracks.map { SoundQueueEntry(it, this) }
}

/** A shelf on the DEEP Sound home: a category and its collections. */
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
