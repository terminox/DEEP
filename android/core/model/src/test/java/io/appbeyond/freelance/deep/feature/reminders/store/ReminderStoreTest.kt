package io.appbeyond.freelance.deep.feature.reminders.store

import io.appbeyond.freelance.deep.feature.reminders.model.DailyReminder
import io.appbeyond.freelance.deep.feature.reminders.model.ReminderSchedule
import io.appbeyond.freelance.deep.shared.persistence.InMemoryBlobStore
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import java.time.Clock
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Ported from Deep/DeepTests/ReminderStoreTests.swift.
 *
 * The store's contract with the system schedule: it should never claim the
 * reminder is on over a schedule that cannot exist, and every settings change
 * should leave the schedule agreeing with the settings.
 */
class ReminderStoreTest {
  private val zone: ZoneId = ZoneId.of("Asia/Bangkok")

  private val now: ZonedDateTime = ZonedDateTime.parse("2026-09-01T08:00:00+07:00").withZoneSameInstant(zone)

  private val clock: Clock = Clock.fixed(now.toInstant(), zone)

  /** A prompt that must never be shown — the mock decides the answer. */
  private val prompt: suspend () -> Boolean = { true }

  private fun store(scheduler: MockReminderScheduler, blob: InMemoryBlobStore = InMemoryBlobStore()) =
    ReminderStore(scheduler = scheduler, blob = blob, clock = clock, zone = { zone })

  @Test
  @DisplayName("starts off, with an empty queue")
  fun startsOff() = runTest {
    val scheduler = MockReminderScheduler()
    val store = store(scheduler)
    store.restore()
    assertFalse(store.reminder.isEnabled)
    assertTrue(scheduler.queue.isEmpty())
  }

  @Test
  @DisplayName("granting permission fills the queue")
  fun enableFillsQueue() = runTest {
    val scheduler = MockReminderScheduler(ReminderPermission.Unasked, grantsWhenAsked = true)
    val store = store(scheduler)

    val permission = store.enable(goalMetToday = false, prompt = prompt)

    assertEquals(ReminderPermission.Granted, permission)
    assertTrue(store.reminder.isEnabled)
    assertEquals(ReminderSchedule.horizon, scheduler.queue.size)
  }

  @Test
  @DisplayName("a refused prompt leaves the toggle off and the queue empty")
  fun refusedPermissionLeavesItOff() = runTest {
    val scheduler = MockReminderScheduler(ReminderPermission.Unasked, grantsWhenAsked = false)
    val store = store(scheduler)

    val permission = store.enable(goalMetToday = false, prompt = prompt)

    assertEquals(ReminderPermission.Denied, permission)
    assertFalse(store.reminder.isEnabled, "never claim it is on over a queue that can't exist")
    assertTrue(scheduler.queue.isEmpty())
    assertEquals(ReminderPermission.Denied, store.state.value.permission)
  }

  @Test
  @DisplayName("switching off clears the queue")
  fun disableClearsQueue() = runTest {
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler)

    store.enable(goalMetToday = false, prompt = prompt)
    assertTrue(scheduler.queue.isNotEmpty())

    store.disable()
    assertFalse(store.reminder.isEnabled)
    assertTrue(scheduler.queue.isEmpty())
  }

  @Test
  @DisplayName("changing the time rewrites the queue to the new hour")
  fun timeChangeRewritesQueue() = runTest {
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler)
    store.enable(goalMetToday = false, prompt = prompt)

    store.setTime(hour = 7, minute = 30, goalMetToday = false)

    assertEquals(7, store.reminder.hour)
    assertEquals(30, store.reminder.minute)
    assertTrue(scheduler.queue.isNotEmpty())
    for (occurrence in scheduler.queue) {
      assertEquals(7, occurrence.hour)
      assertEquals(30, occurrence.minute)
    }
  }

  @Test
  @DisplayName("permission revoked in system settings switches the reminder off")
  fun revokedPermissionTurnsItOff() = runTest {
    val blob = InMemoryBlobStore()
    val store = store(MockReminderScheduler(ReminderPermission.Granted), blob)
    store.enable(goalMetToday = false, prompt = prompt)
    assertTrue(store.reminder.isEnabled)

    // Someone turns notifications off for DEEP while the app is asleep.
    val revoked = MockReminderScheduler(ReminderPermission.Denied)
    val reopened = store(revoked, blob)
    reopened.reschedule(goalMetToday = false)

    assertFalse(reopened.reminder.isEnabled)
    assertTrue(revoked.queue.isEmpty())
  }

  @Test
  @DisplayName("a completed day is dropped from the queue")
  fun goalMetDropsToday() = runTest {
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler)

    store.enable(goalMetToday = true, prompt = prompt)

    assertTrue(scheduler.queue.none { it.toLocalDate() == now.toLocalDate() })
  }

  @Test
  @DisplayName("the setting survives a relaunch")
  fun settingPersists() = runTest {
    val blob = InMemoryBlobStore()
    val store = store(MockReminderScheduler(ReminderPermission.Granted), blob)
    store.enable(goalMetToday = false, prompt = prompt)
    store.setTime(hour = 6, minute = 15, goalMetToday = false)

    val relaunched = store(MockReminderScheduler(ReminderPermission.Granted), blob)
    relaunched.restore()
    assertTrue(relaunched.reminder.isEnabled)
    assertEquals(6, relaunched.reminder.hour)
    assertEquals(15, relaunched.reminder.minute)
  }

  @Test
  @DisplayName("an already-granted permission never shows a prompt")
  fun grantedSkipsPrompt() = runTest {
    var prompted = false
    val store = store(MockReminderScheduler(ReminderPermission.Granted))
    store.enable(goalMetToday = false, prompt = { prompted = true; true })
    assertFalse(prompted)
  }

  @Test
  @DisplayName("a reminder that is off reschedules to an empty queue")
  fun rescheduleWhileOffClears() = runTest {
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler)
    scheduler.replaceQueue(listOf(now.plusHours(1)))

    store.reschedule(goalMetToday = false)

    assertTrue(scheduler.queue.isEmpty())
  }

  @Test
  @DisplayName("an account exit resets the time as well as the switch, and the reset persists")
  fun resetForgetsTheTime() = runTest {
    val blob = InMemoryBlobStore()
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler, blob)
    store.enable(goalMetToday = false, prompt = prompt)
    store.setTime(hour = 23, minute = 15, goalMetToday = false)

    store.reset()

    assertEquals(DailyReminder.initial, store.reminder)
    assertTrue(scheduler.queue.isEmpty())
    val nextMember = store(MockReminderScheduler(ReminderPermission.Granted), blob)
    nextMember.restore()
    assertEquals(DailyReminder.initial, nextMember.reminder, "The next member never inherits 23:15.")
    nextMember.enable(goalMetToday = false, prompt = prompt)
    assertEquals(21, nextMember.reminder.hour)
    assertEquals(0, nextMember.reminder.minute)
  }

  @Test
  @DisplayName("once today's nudge has posted, a later time the same day arms tomorrow (B22)")
  fun postedTodayArmsTomorrow() = runTest {
    // `now` is 08:00. The nudge was set for 07:30 and has just gone out.
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler)
    store.enable(goalMetToday = false, prompt = prompt)
    store.markPosted(now.toLocalDate())

    store.setTime(hour = 9, minute = 0, goalMetToday = false)

    val first = scheduler.queue.first()
    assertEquals(now.toLocalDate().plusDays(1), first.toLocalDate(), "Not a second nudge at 09:00 today.")
    assertEquals(9, first.hour)

    // The foreground rebuild agrees.
    store.reschedule(goalMetToday = false)
    assertEquals(now.toLocalDate().plusDays(1), scheduler.queue.first().toLocalDate())
  }

  @Test
  @DisplayName("a nudge posted yesterday leaves today's later time armed")
  fun postedYesterdayKeepsToday() = runTest {
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler)
    store.enable(goalMetToday = false, prompt = prompt)
    store.markPosted(now.toLocalDate().minusDays(1))

    store.setTime(hour = 9, minute = 0, goalMetToday = false)

    assertEquals(now.toLocalDate(), scheduler.queue.first().toLocalDate())
  }

  @Test
  @DisplayName("the posted day survives a relaunch, and an account exit forgets it")
  fun postedDayPersists() = runTest {
    val blob = InMemoryBlobStore()
    val store = store(MockReminderScheduler(ReminderPermission.Granted), blob)
    store.enable(goalMetToday = false, prompt = prompt)
    store.markPosted(now.toLocalDate())

    val relaunched = store(MockReminderScheduler(ReminderPermission.Granted), blob)
    relaunched.restore()
    assertTrue(relaunched.reminder.postedOn(now.toLocalDate()))

    relaunched.reset()
    assertFalse(relaunched.reminder.postedOn(now.toLocalDate()))
  }
}
