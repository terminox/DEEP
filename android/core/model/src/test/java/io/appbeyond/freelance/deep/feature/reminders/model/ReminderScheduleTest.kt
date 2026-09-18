package io.appbeyond.freelance.deep.feature.reminders.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Ported from Deep/DeepTests/ReminderScheduleTests.swift.
 *
 * The reminder's date maths, tested as the pure function it is — the
 * `PracticeMath` pattern. Everything here runs off a fixed [ZonedDateTime],
 * so no test depends on when it runs.
 *
 * Two cases from the Swift suite are not ported: `identifiersAreStablePerDay`
 * exercises `ReminderScheduler.identifier`, a method on the
 * `UNUserNotificationCenter`-backed scheduling *service* (not a Models type,
 * and not pure of a platform notification API); `copyRotatesDaily` exercises
 * `ReminderCopy.forDay`, which resolves iOS-localized strings via
 * `Bundle.app`/`Locale.app`. Neither is in this module's "no Android
 * dependency" pure-logic scope — both land with the platform-specific
 * reminder work in week 5.
 */
class ReminderScheduleTest {
  private val zone: ZoneId = ZoneId.of("Asia/Bangkok")

  private fun date(iso: String): ZonedDateTime =
    ZonedDateTime.parse(iso).withZoneSameInstant(zone)

  private val enabled = DailyReminder(isEnabled = true, hour = 21, minute = 0)

  @Test
  @DisplayName("a disabled reminder queues nothing")
  fun disabledQueuesNothing() {
    val occurrences = ReminderSchedule.occurrences(
      after = date("2026-09-01T08:00:00+07:00"),
      reminder = DailyReminder(isEnabled = false, hour = 21, minute = 0),
      goalMetToday = false,
    )
    assertTrue(occurrences.isEmpty())
  }

  @Test
  @DisplayName("fills the whole window, one per day")
  fun fillsWindow() {
    val occurrences = ReminderSchedule.occurrences(
      after = date("2026-09-01T08:00:00+07:00"),
      reminder = enabled,
      goalMetToday = false,
    )
    assertEquals(ReminderSchedule.horizon, occurrences.size)

    val days = occurrences.map { it.toLocalDate() }.toSet()
    assertEquals(occurrences.size, days.size, "each occurrence falls on its own day")

    // Every one lands on the chosen clock face.
    for (occurrence in occurrences) {
      assertEquals(21, occurrence.hour)
      assertEquals(0, occurrence.minute)
    }
  }

  @Test
  @DisplayName("today is included when the time is still ahead")
  fun includesTodayBeforeTheHour() {
    val now = date("2026-09-01T08:00:00+07:00")
    val occurrences = ReminderSchedule.occurrences(after = now, reminder = enabled, goalMetToday = false)
    assertEquals(now.toLocalDate(), occurrences[0].toLocalDate())
  }

  @Test
  @DisplayName("today is skipped once its time has passed")
  fun skipsTodayAfterTheHour() {
    val now = date("2026-09-01T21:30:00+07:00")
    val occurrences = ReminderSchedule.occurrences(after = now, reminder = enabled, goalMetToday = false)
    assertFalse(occurrences[0].toLocalDate() == now.toLocalDate())
    assertEquals(ReminderSchedule.horizon, occurrences.size, "the window still fills")
  }

  @Test
  @DisplayName("a day whose practice is done stays quiet")
  fun skipsTodayWhenGoalMet() {
    val now = date("2026-09-01T08:00:00+07:00")
    val occurrences = ReminderSchedule.occurrences(after = now, reminder = enabled, goalMetToday = true)
    assertFalse(occurrences[0].toLocalDate() == now.toLocalDate())
    // Tomorrow is not skipped — only today can be known to be complete.
    val tomorrow = now.plusDays(1)
    assertEquals(tomorrow.toLocalDate(), occurrences[0].toLocalDate())
  }

  @Test
  @DisplayName("the window stays under the system's 64-request cap")
  fun staysUnderSystemCap() {
    assertTrue(ReminderSchedule.horizon < 64)
  }

  @Test
  @DisplayName("every occurrence is in the future")
  fun allFuture() {
    val now = date("2026-09-01T20:59:59+07:00")
    val occurrences = ReminderSchedule.occurrences(after = now, reminder = enabled, goalMetToday = false)
    assertTrue(occurrences.all { it.isAfter(now) })
  }
}
