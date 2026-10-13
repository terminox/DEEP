package io.appbeyond.freelance.deep.feature.reminders.store

import io.appbeyond.freelance.deep.feature.practice.store.MockPracticeRemote
import io.appbeyond.freelance.deep.feature.practice.store.PracticeJournal
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

    val permission = store.enable(practisedToday = false, prompt = prompt)

    assertEquals(ReminderPermission.Granted, permission)
    assertTrue(store.reminder.isEnabled)
    assertEquals(ReminderSchedule.horizon, scheduler.queue.size)
  }

  @Test
  @DisplayName("a refused prompt leaves the toggle off and the queue empty")
  fun refusedPermissionLeavesItOff() = runTest {
    val scheduler = MockReminderScheduler(ReminderPermission.Unasked, grantsWhenAsked = false)
    val store = store(scheduler)

    val permission = store.enable(practisedToday = false, prompt = prompt)

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

    store.enable(practisedToday = false, prompt = prompt)
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
    store.enable(practisedToday = false, prompt = prompt)

    store.setTime(hour = 7, minute = 30, practisedToday = false)

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
    store.enable(practisedToday = false, prompt = prompt)
    assertTrue(store.reminder.isEnabled)

    // Someone turns notifications off for DEEP while the app is asleep.
    val revoked = MockReminderScheduler(ReminderPermission.Denied)
    val reopened = store(revoked, blob)
    reopened.reschedule(practisedToday = false)

    assertFalse(reopened.reminder.isEnabled)
    assertTrue(revoked.queue.isEmpty())
  }

  @Test
  @DisplayName("a completed day is dropped from the queue")
  fun goalMetDropsToday() = runTest {
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler)

    store.enable(practisedToday = true, prompt = prompt)

    assertTrue(scheduler.queue.none { it.toLocalDate() == now.toLocalDate() })
  }

  @Test
  @DisplayName("the setting survives a relaunch")
  fun settingPersists() = runTest {
    val blob = InMemoryBlobStore()
    val store = store(MockReminderScheduler(ReminderPermission.Granted), blob)
    store.enable(practisedToday = false, prompt = prompt)
    store.setTime(hour = 6, minute = 15, practisedToday = false)

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
    store.enable(practisedToday = false, prompt = { prompted = true; true })
    assertFalse(prompted)
  }

  @Test
  @DisplayName("a reminder that is off reschedules to an empty queue")
  fun rescheduleWhileOffClears() = runTest {
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler)
    scheduler.replaceQueue(listOf(now.plusHours(1)))

    store.reschedule(practisedToday = false)

    assertTrue(scheduler.queue.isEmpty())
  }

  @Test
  @DisplayName("an account exit resets the time as well as the switch, and the reset persists")
  fun resetForgetsTheTime() = runTest {
    val blob = InMemoryBlobStore()
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler, blob)
    store.enable(practisedToday = false, prompt = prompt)
    store.setTime(hour = 23, minute = 15, practisedToday = false)

    store.reset()

    assertEquals(DailyReminder.initial, store.reminder)
    assertTrue(scheduler.queue.isEmpty())
    val nextMember = store(MockReminderScheduler(ReminderPermission.Granted), blob)
    nextMember.restore()
    assertEquals(DailyReminder.initial, nextMember.reminder, "The next member never inherits 23:15.")
    nextMember.enable(practisedToday = false, prompt = prompt)
    assertEquals(21, nextMember.reminder.hour)
    assertEquals(0, nextMember.reminder.minute)
  }

  @Test
  @DisplayName("once today's nudge has posted, a later time the same day arms tomorrow (B22)")
  fun postedTodayArmsTomorrow() = runTest {
    // `now` is 08:00. The nudge was set for 07:30 and has just gone out.
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler)
    store.enable(practisedToday = false, prompt = prompt)
    store.markPosted(now.toLocalDate())

    store.setTime(hour = 9, minute = 0, practisedToday = false)

    val first = scheduler.queue.first()
    assertEquals(now.toLocalDate().plusDays(1), first.toLocalDate(), "Not a second nudge at 09:00 today.")
    assertEquals(9, first.hour)

    // The foreground rebuild agrees.
    store.reschedule(practisedToday = false)
    assertEquals(now.toLocalDate().plusDays(1), scheduler.queue.first().toLocalDate())
  }

  @Test
  @DisplayName("a nudge posted yesterday leaves today's later time armed")
  fun postedYesterdayKeepsToday() = runTest {
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler)
    store.enable(practisedToday = false, prompt = prompt)
    store.markPosted(now.toLocalDate().minusDays(1))

    store.setTime(hour = 9, minute = 0, practisedToday = false)

    assertEquals(now.toLocalDate(), scheduler.queue.first().toLocalDate())
  }

  @Test
  @DisplayName("the posted day survives a relaunch, and an account exit forgets it")
  fun postedDayPersists() = runTest {
    val blob = InMemoryBlobStore()
    val store = store(MockReminderScheduler(ReminderPermission.Granted), blob)
    store.enable(practisedToday = false, prompt = prompt)
    store.markPosted(now.toLocalDate())

    val relaunched = store(MockReminderScheduler(ReminderPermission.Granted), blob)
    relaunched.restore()
    assertTrue(relaunched.reminder.postedOn(now.toLocalDate()))

    relaunched.reset()
    assertFalse(relaunched.reminder.postedOn(now.toLocalDate()))
  }

  // MARK: - B24: the delivery window

  @Test
  @DisplayName("opening the app inside the delivery window keeps today's undelivered nudge (B24)")
  fun rebuildInsideWindowKeepsToday() = runTest {
    // `now` is 08:00; the 07:55 nudge is armed and may still be pending.
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler)
    store.enable(practisedToday = false, prompt = prompt)
    store.setTime(hour = 7, minute = 55, practisedToday = false)

    store.reschedule(practisedToday = false)

    val first = scheduler.queue.first()
    assertEquals(now.toLocalDate(), first.toLocalDate(), "Not pushed to tomorrow by a foreground.")
    assertEquals(7, first.hour)
    assertEquals(55, first.minute)
    assertEquals(now.toLocalDate().plusDays(1), scheduler.queue[1].toLocalDate())
    assertEquals(ReminderSchedule.horizon, scheduler.queue.size)
  }

  @Test
  @DisplayName("past the delivery window, a rebuild moves on to tomorrow")
  fun rebuildPastWindowMovesOn() = runTest {
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler)
    store.enable(practisedToday = false, prompt = prompt)
    store.setTime(hour = 7, minute = 45, practisedToday = false)

    store.reschedule(practisedToday = false)

    assertEquals(now.toLocalDate().plusDays(1), scheduler.queue.first().toLocalDate())
  }

  @Test
  @DisplayName("inside the window, a nudge already posted or a practised day is not kept")
  fun rebuildInsideWindowHonoursTheDay() = runTest {
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler)
    store.enable(practisedToday = false, prompt = prompt)
    store.setTime(hour = 7, minute = 55, practisedToday = false)

    store.reschedule(practisedToday = true)
    assertEquals(now.toLocalDate().plusDays(1), scheduler.queue.first().toLocalDate())

    store.markPosted(now.toLocalDate())
    store.reschedule(practisedToday = false)
    assertEquals(now.toLocalDate().plusDays(1), scheduler.queue.first().toLocalDate())
  }

  @Test
  @DisplayName("choosing a minute just behind now arms tomorrow, never an instant nudge")
  fun setTimeBehindNowArmsTomorrow() = runTest {
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler)
    store.enable(practisedToday = false, prompt = prompt)

    store.setTime(hour = 7, minute = 58, practisedToday = false)

    assertEquals(now.toLocalDate().plusDays(1), scheduler.queue.first().toLocalDate())
  }

  @Test
  @DisplayName("a nudge delivered past midnight is booked to its own evening, and that evening alone")
  fun lateNudgeBooksItsOwnDay() = runTest {
    // An evening nudge whose delivery slipped past midnight: the receiver books
    // yesterday. Tonight's occurrence must still be armed.
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler)
    store.enable(practisedToday = false, prompt = prompt)
    store.markPosted(now.toLocalDate().minusDays(1))

    store.reschedule(practisedToday = false)

    assertEquals(now.toLocalDate(), scheduler.queue.first().toLocalDate())
  }

  // MARK: - B23: a Global Pause rests the reminder (iOS PR #62)

  @Test
  @DisplayName("a Global Pause sat this morning moves tonight's reminder to tomorrow")
  fun pauseThisMorningMovesTonight() = runTest {
    val journal = PracticeJournal(MockPracticeRemote(), InMemoryBlobStore(), clock, zone)
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler)
    store.enable(practisedToday = journal.reminderRestsToday(), prompt = prompt)
    assertEquals(now.toLocalDate(), scheduler.queue.first().toLocalDate(), "Tonight's 21:00 is armed.")

    // The claim lands eligible at 08:00; the app reschedules at once.
    journal.recordPauseDay(clock.instant())
    store.reschedule(practisedToday = journal.reminderRestsToday())

    assertTrue(scheduler.queue.none { it.toLocalDate() == now.toLocalDate() })
    assertEquals(now.toLocalDate().plusDays(1), scheduler.queue.first().toLocalDate())
    assertEquals(ReminderSchedule.horizon, scheduler.queue.size, "The window still fills.")
  }

  @Test
  @DisplayName("minutes short of the goal, with no pause, leave tonight's reminder in place")
  fun shortPracticeLeavesTonight() = runTest {
    val journal = PracticeJournal(MockPracticeRemote(), InMemoryBlobStore(), clock, zone)
    journal.record("Balancing breath", durationSeconds = 60)
    val scheduler = MockReminderScheduler(ReminderPermission.Granted)
    val store = store(scheduler)
    store.enable(practisedToday = journal.reminderRestsToday(), prompt = prompt)

    assertEquals(now.toLocalDate(), scheduler.queue.first().toLocalDate())
  }
}
