package io.appbeyond.freelance.deep.feature.deepsound.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Ported from the state half of DEEP's `SoundPlayer`/`StreamingSoundPlayer`
 * suites — everything `SoundPlayback` derives from the queue and index alone.
 */
class SoundPlaybackTest {
  private fun collection(id: String = "collection-1", vararg tracks: SoundTrack): SoundCollection =
    SoundCollection(
      id = id,
      title = "Ocean",
      subtitle = "Field recording",
      palette = null,
      imageUrl = null,
      tracks = tracks.toList(),
    )

  private fun track(id: String = "track-1", durationSeconds: Int = 180, audioUrl: String? = "https://example.com/a.mp3"): SoundTrack =
    SoundTrack(id = id, title = "Waves", durationSeconds = durationSeconds, audioUrl = audioUrl)

  // MARK: - Idle

  @Test
  @DisplayName("idle playback has no track at all")
  fun idleHasNoTrack() {
    val playback = SoundPlayback.Idle
    assertFalse(playback.hasTrack)
    assertNull(playback.currentEntry)
    assertNull(playback.currentTrack)
    assertNull(playback.collection)
    assertEquals(0.0, playback.duration)
    assertFalse(playback.isCurrentPlayable)
  }

  // MARK: - isCurrentPlayable

  @Test
  @DisplayName("a track with no audio URL still loads, but isn't playable")
  fun nullAudioUrlHasTrackButIsNotPlayable() {
    val t = track(audioUrl = null)
    val c = collection(tracks = arrayOf(t))
    val playback = SoundPlayback(entries = c.queue())

    assertTrue(playback.hasTrack)
    assertFalse(playback.isCurrentPlayable)
  }

  @Test
  @DisplayName("a track with an audio URL is playable")
  fun realAudioUrlIsPlayable() {
    val t = track(audioUrl = "https://example.com/a.mp3")
    val c = collection(tracks = arrayOf(t))
    val playback = SoundPlayback(entries = c.queue())

    assertTrue(playback.isCurrentPlayable)
  }

  // MARK: - duration

  @Test
  @DisplayName("duration comes straight from the backend's track duration")
  fun durationComesFromBackend() {
    val t = track(durationSeconds = 245)
    val c = collection(tracks = arrayOf(t))
    val playback = SoundPlayback(entries = c.queue())

    assertEquals(245.0, playback.duration)
  }

  // MARK: - isCurrent

  @Test
  @DisplayName("isCurrent matches only when both the track and the collection agree")
  fun isCurrentMatchesTrackAndCollection() {
    val t = track(id = "track-1")
    val c = collection(id = "collection-1", tracks = arrayOf(t))
    val playback = SoundPlayback(entries = c.queue())

    assertTrue(playback.isCurrent(t, c))
  }

  @Test
  @DisplayName("isCurrent is false when the track id matches but the collection doesn't")
  fun isCurrentFalseWhenCollectionDiffers() {
    val t = track(id = "track-1")
    val c = collection(id = "collection-1", tracks = arrayOf(t))
    val otherCollection = collection(id = "collection-2", tracks = arrayOf(t))
    val playback = SoundPlayback(entries = c.queue())

    assertFalse(playback.isCurrent(t, otherCollection))
  }

  @Test
  @DisplayName("isCurrent is false when the collection matches but the track doesn't")
  fun isCurrentFalseWhenTrackDiffers() {
    val t = track(id = "track-1")
    val otherTrack = track(id = "track-2")
    val c = collection(id = "collection-1", tracks = arrayOf(t, otherTrack))
    val playback = SoundPlayback(entries = c.queue(), index = 0)

    assertFalse(playback.isCurrent(otherTrack, c))
  }

  // MARK: - out-of-range index

  @Test
  @DisplayName("an out-of-range index reads as no track at all")
  fun outOfRangeIndexIsNull() {
    val t = track()
    val c = collection(tracks = arrayOf(t))
    val playback = SoundPlayback(entries = c.queue(), index = 5)

    assertNull(playback.currentEntry)
    assertNull(playback.currentTrack)
    assertNull(playback.collection)
    assertFalse(playback.hasTrack)
    assertFalse(playback.isCurrentPlayable)
  }
}
