package io.appbeyond.freelance.deep.feature.globalpause.store

import org.junit.jupiter.api.Test
import java.time.Duration
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * The lounge radio's one rule of its own: a join that asks for what is already
 * playing changes nothing. The lounge re-resolves its stage on every edge and
 * schedule refresh, and each of those must not restart the set mid-bar.
 */
class LoungeRadioTest {

  private val url = "https://x/lounge.mp3"

  private fun seconds(value: Long) = Duration.ofSeconds(value)

  @Test
  fun aNearbyOffsetOnTheSameTrackIsAlreadyTuned() {
    assertTrue(LoungeRadio.isAlreadyTuned(url, seconds(60), url, seconds(60)))
    assertTrue(LoungeRadio.isAlreadyTuned(url, seconds(60), url, Duration.ofMillis(62_900)))
    assertTrue(LoungeRadio.isAlreadyTuned(url, Duration.ofMillis(62_900), url, seconds(60)))
  }

  @Test
  fun aRealDriftIsARealign() {
    assertFalse(LoungeRadio.isAlreadyTuned(url, seconds(60), url, seconds(63)))
    assertFalse(LoungeRadio.isAlreadyTuned(url, seconds(63), url, seconds(60)))
  }

  @Test
  fun anotherTrackOrNothingPlayingIsAFreshJoin() {
    assertFalse(LoungeRadio.isAlreadyTuned("https://x/other.mp3", seconds(60), url, seconds(60)))
    assertFalse(LoungeRadio.isAlreadyTuned(null, null, url, seconds(60)))
    assertFalse(LoungeRadio.isAlreadyTuned(url, null, url, seconds(60)))
  }

  @Test
  fun theMockKeepsTheMembersMuteAcrossARejoin() {
    // The lounge re-applies its own mute after every join, but a fake that
    // dropped it would preview an unmuted pill over a muted room.
    val radio = MockLoungeRadioPlayer()
    radio.join(url, seconds(10))
    radio.setMuted(true)
    radio.join(url, seconds(40))
    assertEquals(LoungeRadioState.OnAir(isMuted = true), radio.state.value)

    radio.stop()
    assertEquals(LoungeRadioState.Off, radio.state.value)
    radio.setMuted(false)
    assertEquals(LoungeRadioState.Off, radio.state.value, "muting nothing turns nothing on")
  }
}
