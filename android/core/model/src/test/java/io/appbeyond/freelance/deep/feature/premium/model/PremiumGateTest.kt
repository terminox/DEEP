package io.appbeyond.freelance.deep.feature.premium.model

import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueueEntry
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundTrack
import io.appbeyond.freelance.deep.feature.mindgarden.model.Plant
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Ported from Deep/DeepTests/PremiumGateTests.swift and the gate half of
 * PremiumPlantTests.swift: the server's verdict first, the client rule as the
 * fallback, and membership unlocking all of it.
 */
class PremiumGateTest {

  /** A track with streamable audio unless [withheld], the way the server sends one it doesn't hold back. */
  private fun track(id: String, premium: Boolean = false, locked: Boolean = false, withheld: Boolean = false) =
    SoundTrack(
      id = id,
      title = id,
      durationSeconds = 60,
      audioUrl = if (withheld) null else "https://example.test/$id.mp3",
      isPremium = premium,
      isLocked = locked,
    )

  private fun collection(premium: Boolean = false, locked: Boolean = false, tracks: List<SoundTrack>) =
    SoundCollection(
      id = "c",
      title = "C",
      subtitle = "",
      palette = "mist",
      imageUrl = null,
      isPremium = premium,
      isLocked = locked,
      tracks = tracks,
    )

  // MARK: - Tracks

  @Test
  @DisplayName("A free track in a free collection is open")
  fun freeTrackOpen() {
    val free = track("a")
    assertFalse(PremiumGate.isLocked(free, collection(tracks = listOf(free)), hasPremium = false))
  }

  @Test
  @DisplayName("A premium track is locked for the free plan, open for a member")
  fun premiumTrack() {
    val premium = track("a", premium = true)
    val home = collection(tracks = listOf(premium))
    assertTrue(PremiumGate.isLocked(premium, home, hasPremium = false))
    assertFalse(PremiumGate.isLocked(premium, home, hasPremium = true))
  }

  @Test
  @DisplayName("A free track is locked by the premium collection it sits in")
  fun lockedByCollection() {
    val free = track("a")
    val premiumHome = collection(premium = true, tracks = listOf(free))
    assertTrue(PremiumGate.isLocked(free, premiumHome, hasPremium = false))
    assertFalse(PremiumGate.isLocked(free, premiumHome, hasPremium = true))
  }

  @Test
  @DisplayName("The server's verdict can add a lock the client rule wouldn't")
  fun serverVerdictAddsLock() {
    val withheld = track("b", locked = true)
    assertTrue(PremiumGate.isLocked(withheld, collection(tracks = listOf(withheld)), hasPremium = false))
  }

  @Test
  @DisplayName("An open verdict cached while a member never unlocks after a lapse")
  fun staleOpenVerdictDoesNotUnlock() {
    // Fetched while a member: the server said open and sent the audio.
    val cached = track("a", premium = true, locked = false)
    val home = collection(premium = true, locked = false, tracks = listOf(cached))
    assertTrue(PremiumGate.isLocked(cached, home, hasPremium = false))
    assertTrue(PremiumGate.isLocked(home, hasPremium = false))
    assertTrue(PremiumGate.playable(home, hasPremium = false).isEmpty())
  }

  @Test
  @DisplayName("Membership unlocks visually even when the server still says locked")
  fun membershipBeatsStaleVerdict() {
    val stale = track("a", premium = true, locked = true)
    assertFalse(PremiumGate.isLocked(stale, collection(tracks = listOf(stale)), hasPremium = true))
  }

  @Test
  @DisplayName("A collection's server verdict reaches a track that has none")
  fun collectionVerdictReachesTrack() {
    val free = track("a")
    assertTrue(PremiumGate.isLocked(free, collection(locked = true, tracks = listOf(free)), hasPremium = false))
  }

  // MARK: - Collections

  @Test
  @DisplayName("A collection reads locked from its flag or a locking verdict")
  fun collectionLock() {
    assertFalse(PremiumGate.isLocked(collection(tracks = emptyList()), hasPremium = false))
    assertTrue(PremiumGate.isLocked(collection(premium = true, tracks = emptyList()), hasPremium = false))
    assertTrue(PremiumGate.isLocked(collection(locked = true, tracks = emptyList()), hasPremium = false))
    assertFalse(PremiumGate.isLocked(collection(premium = true, tracks = emptyList()), hasPremium = true))
  }

  @Test
  @DisplayName("A free collection holding a premium track is not itself locked")
  fun mixedCollectionNotLocked() {
    val home = collection(tracks = listOf(track("a"), track("b", premium = true)))
    assertFalse(PremiumGate.isLocked(home, hasPremium = false))
  }

  // MARK: - Queues

  @Test
  @DisplayName("The playable queue drops locked tracks and keeps order")
  fun playableFilter() {
    val home = collection(tracks = listOf(track("a"), track("b", premium = true), track("c")))
    assertEquals(listOf("a", "c"), PremiumGate.playable(home, hasPremium = false).map { it.track.id })
    assertEquals(listOf("a", "b", "c"), PremiumGate.playable(home, hasPremium = true).map { it.track.id })
  }

  @Test
  @DisplayName("A premium collection's queue is empty for the free plan")
  fun premiumCollectionQueueEmpty() {
    val home = collection(premium = true, tracks = listOf(track("a"), track("b")))
    assertTrue(PremiumGate.playable(home, hasPremium = false).isEmpty())
  }

  @Test
  @DisplayName("Mixed-origin playlist entries are each judged by their own collection")
  fun playlistEntries() {
    val entries = listOf(
      SoundQueueEntry(track("a"), collection(tracks = emptyList())),
      SoundQueueEntry(track("b"), collection(premium = true, tracks = emptyList())),
    )
    assertEquals(listOf("a"), PremiumGate.playable(entries, hasPremium = false).map { it.track.id })
  }

  // MARK: - Withheld audio

  @Test
  @DisplayName("A premium track the server sent without audio never starts, even for a member")
  fun withheldNeverStarts() {
    val withheld = track("a", premium = true, withheld = true)
    val home = collection(tracks = listOf(withheld))
    assertTrue(PremiumGate.isWithheld(withheld, home))
    assertFalse(PremiumGate.canStart(withheld, home, hasPremium = true))
    assertTrue(PremiumGate.playable(home, hasPremium = true).isEmpty())
  }

  @Test
  @DisplayName("A free track without audio is fixture content, not a withholding")
  fun freeWithoutAudioIsNotWithheld() {
    val fixture = track("a", withheld = true)
    val home = collection(tracks = listOf(fixture))
    assertFalse(PremiumGate.isWithheld(fixture, home))
    assertTrue(PremiumGate.canStart(fixture, home, hasPremium = false))
  }

  @Test
  @DisplayName("A track withheld inside a premium collection is withheld by it")
  fun withheldByCollection() {
    val free = track("a", withheld = true)
    assertTrue(PremiumGate.isWithheld(free, collection(premium = true, tracks = listOf(free))))
  }

  // MARK: - Plants

  @Test
  @DisplayName("A premium plant is locked for the free plan, open for a member")
  fun premiumPlantLock() {
    val moonflower = Plant.moonflowerFixture
    assertTrue(PremiumGate.isLocked(moonflower, growingId = Plant.oakFixture.id, hasPremium = false))
    assertFalse(PremiumGate.isLocked(moonflower, growingId = Plant.oakFixture.id, hasPremium = true))
    assertFalse(PremiumGate.isLocked(Plant.oakFixture, growingId = Plant.lotusFixture.id, hasPremium = false))
  }

  @Test
  @DisplayName("The plant you are growing is never locked, even after a lapse")
  fun growingNeverLocked() {
    val lapsed = Plant.moonflowerFixture.copy(isLocked = true)
    assertFalse(PremiumGate.isLocked(lapsed, growingId = lapsed.id, hasPremium = false))
  }

  @Test
  @DisplayName("The server's plant verdict beats the client rule, both ways")
  fun serverPlantVerdict() {
    val grandfathered = Plant.moonflowerFixture.copy(isLocked = false)
    assertFalse(PremiumGate.isLocked(grandfathered, growingId = null, hasPremium = false))
    val lockedFree = Plant.oakFixture.copy(isLocked = true)
    assertTrue(PremiumGate.isLocked(lockedFree, growingId = null, hasPremium = false))
  }
}
