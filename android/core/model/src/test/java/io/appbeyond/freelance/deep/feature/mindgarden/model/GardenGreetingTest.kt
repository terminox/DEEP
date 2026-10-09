package io.appbeyond.freelance.deep.feature.mindgarden.model

import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenGreeting.TimeOfDay
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.ZonedDateTime
import kotlin.test.assertEquals

/**
 * No iOS suite covers `GardenGreeting`; these pin the two things that must
 * match it — the time-of-day hour bands and the daily quote rotation.
 *
 * The expected quote indexes were computed with swift-foundation itself
 * (`Calendar(identifier: .gregorian).ordinality(of: .day, in: .era, for:)`,
 * modulo 8), so the same date shows the same line on both platforms.
 */
class GardenGreetingTest {

  private val bangkok: ZoneId = ZoneId.of("Asia/Bangkok")

  @Test
  @DisplayName("The salutation follows the local hour: 5–11 morning, 12–16 afternoon, else evening")
  fun salutationBands() {
    val expected = mapOf(
      0 to TimeOfDay.Evening,
      4 to TimeOfDay.Evening,
      5 to TimeOfDay.Morning,
      11 to TimeOfDay.Morning,
      12 to TimeOfDay.Afternoon,
      16 to TimeOfDay.Afternoon,
      17 to TimeOfDay.Evening,
      23 to TimeOfDay.Evening,
    )
    for ((hour, timeOfDay) in expected) {
      assertEquals(timeOfDay, GardenGreeting.timeOfDay(hour), "hour $hour")
    }
  }

  @Test
  @DisplayName("The quote index matches Swift's day-in-era ordinality on known dates")
  fun quoteIndexMatchesSwift() {
    // Swift ordinals: 1970-01-01 → 719163, 2024-01-01 → 738886,
    // 2026-07-23 → 739820, 2026-10-09 → 739898.
    assertEquals(3, GardenGreeting.quoteIndex(LocalDate.of(1970, 1, 1)))
    assertEquals(6, GardenGreeting.quoteIndex(LocalDate.of(2024, 1, 1)))
    assertEquals(4, GardenGreeting.quoteIndex(LocalDate.of(2026, 7, 23)))
    assertEquals(2, GardenGreeting.quoteIndex(LocalDate.of(2026, 10, 9)))
  }

  @Test
  @DisplayName("Consecutive days walk the pool in order")
  fun rotatesDaily() {
    val start = LocalDate.of(2026, 10, 9)
    val indexes = (0L until 9L).map { GardenGreeting.quoteIndex(start.plusDays(it)) }

    assertEquals(listOf(2, 3, 4, 5, 6, 7, 0, 1, 2), indexes)
  }

  @Test
  @DisplayName("The current greeting reads the hour and day in the member's zone")
  fun currentUsesZone() {
    // 2026-10-08 20:00 UTC is already 03:00 on the 9th in Bangkok.
    val instant: Instant = ZonedDateTime.of(2026, 10, 8, 20, 0, 0, 0, ZoneOffset.UTC).toInstant()
    val clock = Clock.fixed(instant, ZoneOffset.UTC)

    val bangkokGreeting = GardenGreeting.current(clock, bangkok)
    assertEquals(TimeOfDay.Evening, bangkokGreeting.timeOfDay)
    assertEquals(2, bangkokGreeting.quoteIndex)

    val utcGreeting = GardenGreeting.current(clock, ZoneOffset.UTC)
    assertEquals(TimeOfDay.Evening, utcGreeting.timeOfDay)
    assertEquals(1, utcGreeting.quoteIndex)
  }

  @Test
  @DisplayName("A Bangkok morning greets the morning")
  fun morning() {
    val clock = Clock.fixed(ZonedDateTime.of(2026, 10, 9, 8, 30, 0, 0, bangkok).toInstant(), bangkok)

    assertEquals(
      GardenGreeting(timeOfDay = TimeOfDay.Morning, quoteIndex = 2),
      GardenGreeting.current(clock, bangkok),
    )
  }
}
