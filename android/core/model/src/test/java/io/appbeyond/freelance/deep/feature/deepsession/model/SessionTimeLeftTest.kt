package io.appbeyond.freelance.deep.feature.deepsession.model

import io.appbeyond.freelance.deep.feature.deepsession.model.SessionTimeLeft.AboutAMinute
import io.appbeyond.freelance.deep.feature.deepsession.model.SessionTimeLeft.AboutMinutes
import io.appbeyond.freelance.deep.feature.deepsession.model.SessionTimeLeft.AlmostThere
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.minutes
import kotlin.time.Duration.Companion.seconds
import kotlin.time.Duration.Companion.ZERO

/** The buckets of `DeepSessionView.remainingLine`, boundary by boundary. */
class SessionTimeLeftTest {

  @Test
  @DisplayName("Under thirty seconds is almost there")
  fun almostThere() {
    assertEquals(AlmostThere, SessionTimeLeft.of(ZERO))
    assertEquals(AlmostThere, SessionTimeLeft.of(29_999.milliseconds))
  }

  @Test
  @DisplayName("Thirty seconds up to ninety is about a minute")
  fun aboutAMinute() {
    assertEquals(AboutAMinute, SessionTimeLeft.of(30.seconds))
    assertEquals(AboutAMinute, SessionTimeLeft.of(89_999.milliseconds))
  }

  @Test
  @DisplayName("Ninety seconds and over rounds to the nearest minute, half up")
  fun aboutMinutes() {
    assertEquals(AboutMinutes(2), SessionTimeLeft.of(90.seconds))
    assertEquals(AboutMinutes(2), SessionTimeLeft.of(149.seconds))
    assertEquals(AboutMinutes(3), SessionTimeLeft.of(150.seconds))
    assertEquals(AboutMinutes(10), SessionTimeLeft.of(10.minutes))
  }

  @Test
  @DisplayName("A ten-minute session opens on about ten minutes left")
  fun freshSession() {
    val session = DeepSession(id = "t", title = "", tagline = "", cycles = 6).lasting(10)
    assertEquals(AboutMinutes(10), SessionTimeLeft.of(session.duration))
  }
}
