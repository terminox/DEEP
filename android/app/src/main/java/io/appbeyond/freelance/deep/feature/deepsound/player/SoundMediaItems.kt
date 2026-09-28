package io.appbeyond.freelance.deep.feature.deepsound.player

import android.os.Bundle
import androidx.annotation.OptIn
import androidx.core.net.toUri
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.util.UnstableApi
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueueEntry

/** The collection a queued item came from, carried in its metadata extras. */
const val EXTRA_COLLECTION_ID = "io.appbeyond.freelance.deep.sound.COLLECTION_ID"

/**
 * One queue entry as the session's player holds it.
 *
 * The audio URL is written twice, and both are needed. [MediaItem.Builder.setUri]
 * is what a player in this process would read — but a `MediaController` hands
 * items to the session stripped of that local configuration, so the URL also
 * rides in [MediaItem.RequestMetadata.mediaUri], which does cross, and
 * `DeepSoundSessionCallback.onAddMediaItems` restores it on the far side.
 *
 * A track with no audio (fixture content, a row still waiting for its file)
 * travels with no URL at all and `isPlayable = false`. The session gives it a
 * silent placeholder so the queue keeps its shape and its indices, and the
 * service refuses to play it — iOS's `loadCurrent` stopping on a nil
 * `audioURL`, done in the only place that sees every way into a track.
 *
 * Duration comes from the backend, never from the stream, exactly as iOS does:
 * it is known before a byte arrives, so the notification's scrubber is right
 * from the first frame.
 */
@OptIn(UnstableApi::class)
fun SoundQueueEntry.toMediaItem(): MediaItem {
  val audio = track.audioUrl?.toUri()
  return MediaItem.Builder()
    .setMediaId(track.id)
    .setUri(audio)
    .setRequestMetadata(
      MediaItem.RequestMetadata.Builder().setMediaUri(audio).build()
    )
    .setMediaMetadata(
      MediaMetadata.Builder()
        .setTitle(track.title)
        .setArtist(collection.title)
        .setAlbumTitle(collection.title)
        .setArtworkUri(sizedArtwork(collection.imageUrl)?.toUri())
        .setDurationMs(track.durationSeconds * 1_000L)
        .setIsPlayable(audio != null)
        .setIsBrowsable(false)
        .setExtras(Bundle().apply { putString(EXTRA_COLLECTION_ID, collection.id) })
        .build()
    )
    .build()
}

/**
 * The artwork URL the notification and the lock screen should fetch.
 *
 * The session decodes artwork into a bitmap it hands to the system, and the
 * system scales it down to at most a few hundred pixels whatever arrives. The
 * seeded Unsplash URLs ask for 600px or more, so they are rewritten to 512 —
 * large enough for the expanded lock-screen art, a third of the bytes. Any other
 * host passes through untouched: our own `/media` serves one size.
 */
internal fun sizedArtwork(imageUrl: String?): String? {
  if (imageUrl == null) return null
  val uri = imageUrl.toUri()
  if (uri.host != UNSPLASH_HOST) return imageUrl
  val sized = uri.buildUpon().clearQuery()
  for (name in uri.queryParameterNames) {
    if (name == "w" || name == "q") continue
    for (value in uri.getQueryParameters(name)) sized.appendQueryParameter(name, value)
  }
  return sized
    .appendQueryParameter("w", ARTWORK_WIDTH.toString())
    .appendQueryParameter("q", ARTWORK_QUALITY.toString())
    .build()
    .toString()
}

private const val UNSPLASH_HOST = "images.unsplash.com"
private const val ARTWORK_WIDTH = 512
private const val ARTWORK_QUALITY = 80
