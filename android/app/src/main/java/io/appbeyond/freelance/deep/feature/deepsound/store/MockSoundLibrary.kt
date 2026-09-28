package io.appbeyond.freelance.deep.feature.deepsound.store

import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundShelf
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundTrack
import io.appbeyond.freelance.deep.feature.deepsound.model.TrackKind
import io.appbeyond.freelance.deep.feature.deepsound.model.TrackLyrics
import io.appbeyond.freelance.deep.networking.DeepApiException

/**
 * In-memory [SoundLibrary] for previews — no networking, serving
 * [SoundLibraryFixtures] (or, with [fails], throwing every call). The Android
 * twin of `FixtureSoundContentRepository.swift`.
 */
class MockSoundLibrary(
  private val fixtureShelves: List<SoundShelf> = SoundLibraryFixtures.shelves,
  private val fails: Boolean = false,
) : SoundLibrary {

  override suspend fun shelves(): List<SoundShelf> {
    if (fails) throw DeepApiException.Transport("Mock failure")
    return fixtureShelves
  }

  override suspend fun lyrics(trackId: String): List<TrackLyrics> {
    if (fails) throw DeepApiException.Transport("Mock failure")
    return emptyList()
  }

  companion object {
    /** The bundled fixture shelves — the environment default, so previews are hermetic. */
    val loaded: MockSoundLibrary get() = MockSoundLibrary()

    /** Every call throws, for previewing the home's retry state. */
    val failing: MockSoundLibrary get() = MockSoundLibrary(fails = true)
  }
}

/**
 * Sample content for previews and for [io.appbeyond.freelance.deep.feature.playlist.store.PlaylistFixtures],
 * which saves a few of these tracks. No networking, no audio — just enough
 * shape to make the home, detail and playlist screens feel alive. Deliberately
 * smaller than `SoundLibrary.swift`'s bundled catalogue (three shelves rather
 * than five, a couple of collections each) — this only has to cover Deep
 * Sound and Playlist's previews, not stand in for real content.
 */
object SoundLibraryFixtures {

  /** "Calm" — settled skies and still places. */
  val calm: List<SoundCollection> = listOf(
    SoundCollection(
      id = "col-calm-1",
      title = "Northern Calm",
      subtitle = "Wide skies, settled breath",
      palette = "tide",
      imageUrl = "https://images.unsplash.com/photo-1483347756197-71ef80e95f73?w=600&q=80",
      categoryId = "calm",
      tracks = listOf(
        SoundTrack(id = "trk-calm-1-1", title = "Aurora Drift", durationSeconds = 9 * 60 + 16),
        SoundTrack(id = "trk-calm-1-2", title = "Polar Stillness", durationSeconds = 7 * 60 + 48),
        SoundTrack(id = "trk-calm-1-3", title = "Open Sky", durationSeconds = 6 * 60 + 30),
      ),
    ),
    SoundCollection(
      id = "col-calm-2",
      title = "Still Forest",
      subtitle = "Green quiet between the trees",
      palette = "meadow",
      imageUrl = "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&q=80",
      categoryId = "calm",
      tracks = listOf(
        SoundTrack(id = "trk-calm-2-1", title = "Under the Canopy", durationSeconds = 7 * 60 + 26),
        SoundTrack(id = "trk-calm-2-2", title = "Moss and Shade", durationSeconds = 6 * 60 + 54),
      ),
    ),
  )

  /** "Morning" — a soft return to the day. */
  val morning: List<SoundCollection> = listOf(
    SoundCollection(
      id = "col-morning-1",
      title = "Morning Mist",
      subtitle = "A soft return to the day",
      palette = "dawn",
      imageUrl = "https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=600&q=80",
      categoryId = "morning",
      tracks = listOf(
        SoundTrack(id = "trk-morning-1-1", title = "First Light", durationSeconds = 5 * 60 + 12),
        SoundTrack(id = "trk-morning-1-2", title = "Dew", durationSeconds = 6 * 60 + 58),
      ),
    ),
    SoundCollection(
      id = "col-morning-2",
      title = "First Sun",
      subtitle = "Warmth arriving over the hills",
      palette = "bloom",
      imageUrl = "https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?w=600&q=80",
      categoryId = "morning",
      tracks = listOf(
        SoundTrack(id = "trk-morning-2-1", title = "Horizon Glow", durationSeconds = 6 * 60 + 18),
        SoundTrack(id = "trk-morning-2-2", title = "Waking Fields", durationSeconds = 7 * 60 + 42),
      ),
    ),
  )

  /** "Sleep" — one guided track alongside instrumentals, to exercise [TrackKind.Guided]. */
  val sleep: List<SoundCollection> = listOf(
    SoundCollection(
      id = "col-sleep-1",
      title = "Deep Rest",
      subtitle = "A slow way down into sleep",
      palette = "dusk",
      imageUrl = "https://images.unsplash.com/photo-1470813740244-df37b8c1edcb?w=600&q=80",
      categoryId = "sleep",
      tracks = listOf(
        SoundTrack(id = "trk-sleep-1-1", title = "Settling In", durationSeconds = 8 * 60 + 10),
        SoundTrack(
          id = "trk-sleep-1-2",
          title = "A Guided Wind-Down",
          durationSeconds = 12 * 60 + 5,
          kind = TrackKind.Guided,
        ),
      ),
    ),
    SoundCollection(
      id = "col-sleep-2",
      title = "Night Tide",
      subtitle = "Waves, far off and unhurried",
      palette = "ember",
      imageUrl = "https://images.unsplash.com/photo-1440342359743-84fcb8c21f21?w=600&q=80",
      categoryId = "sleep",
      tracks = listOf(
        SoundTrack(id = "trk-sleep-2-1", title = "Low Tide", durationSeconds = 10 * 60 + 40),
      ),
    ),
  )

  val shelves: List<SoundShelf> = listOf(
    SoundShelf(id = "calm", title = "Calm", collections = calm),
    SoundShelf(id = "morning", title = "Morning", collections = morning),
    SoundShelf(id = "sleep", title = "Sleep", collections = sleep),
  )
}
