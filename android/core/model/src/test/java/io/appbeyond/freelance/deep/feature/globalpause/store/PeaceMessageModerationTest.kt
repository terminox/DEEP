package io.appbeyond.freelance.deep.feature.globalpause.store

import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessage
import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessageReportReason
import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessagesPage
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Report and Block from a peace message card: the card leaves at the tap,
 * comes back only on a refusal, and a block refetches the feed so the rest of
 * that author's messages go too.
 */
class PeaceMessageModerationTest {

  private val now = Instant.ofEpochSecond(1_800_000_000)
  private val clock = Clock.fixed(now, ZoneOffset.UTC)

  private fun fixture() = FixturePauseEventRemote(clock = clock)

  private fun moderation(remote: FixturePauseEventRemote, feed: PeaceMessageFeed) =
    PeaceMessageModeration(feed = feed, sendReport = remote::report, sendBlock = remote::blockAuthor)

  private fun PeaceMessageFeed.visibleIds() = state.value.visible.map { it.id }

  @Test
  @DisplayName("A report hides the message at the tap, before the server answers")
  fun reportHidesAtOnce() = runTest {
    val gate = CompletableDeferred<Unit>()
    val feed = PeaceMessageFeed { _, _ -> PeaceMessagesPage(listOf(message("a"), message("b")), null) }
    feed.loadInitial()
    val moderation = PeaceMessageModeration(feed, sendReport = { _, _ -> gate.await() }, sendBlock = { null })

    var landed: Boolean? = null
    launch { landed = moderation.report(message("a"), PeaceMessageReportReason.Spam) }
    runCurrent()
    assertEquals(listOf("b"), feed.visibleIds())

    gate.complete(Unit)
    runCurrent()
    assertEquals(true, landed)
    assertEquals(listOf("b"), feed.visibleIds())
  }

  @Test
  @DisplayName("A report carries its reason, and the server leaves the message out from then on")
  fun reportReachesServer() = runTest {
    val remote = fixture()
    val feed = PeaceMessageFeed { limit, cursor -> remote.messages(limit, cursor) }
    feed.loadInitial()
    val target = feed.state.value.visible.first()

    assertTrue(moderation(remote, feed).report(target, PeaceMessageReportReason.Harassment))
    assertEquals(listOf("${target.id}:harassment"), remote.reports)

    feed.refresh()
    assertFalse(target.id in feed.state.value.messages.map { it.id })
  }

  @Test
  @DisplayName("A refused report brings the card back")
  fun refusedReportRestores() = runTest {
    val remote = fixture().apply { moderationFailures = 1 }
    val feed = PeaceMessageFeed { limit, cursor -> remote.messages(limit, cursor) }
    feed.loadInitial()
    val before = feed.visibleIds()

    assertFalse(moderation(remote, feed).report(feed.state.value.visible.first(), PeaceMessageReportReason.Offensive))
    assertEquals(before, feed.visibleIds())
    assertTrue(remote.reports.isEmpty())
  }

  @Test
  @DisplayName("A block refetches, so every message by that author goes")
  fun blockRefetches() = runTest {
    val remote = fixture()
    var fetches = 0
    val feed = PeaceMessageFeed { limit, cursor ->
      fetches += 1
      remote.messages(limit, cursor)
    }
    feed.loadInitial()
    val haruki = feed.state.value.visible.first { it.displayName == "Haruki" }

    assertTrue(moderation(remote, feed).block(haruki))
    assertEquals(2, fetches)
    // Gone from what the server sent back, not only hidden here.
    assertFalse(feed.state.value.messages.any { it.displayName == "Haruki" })
    assertEquals(listOf("Haruki"), remote.blockedMembers().map { it.displayName })
  }

  @Test
  @DisplayName("A refused block brings the card back and refetches nothing")
  fun refusedBlockRestores() = runTest {
    val remote = fixture()
    var fetches = 0
    val feed = PeaceMessageFeed { limit, cursor ->
      fetches += 1
      remote.messages(limit, cursor)
    }
    feed.loadInitial()
    remote.moderationFailures = 1
    val before = feed.visibleIds()

    assertFalse(moderation(remote, feed).block(feed.state.value.visible.first()))
    assertEquals(before, feed.visibleIds())
    assertEquals(1, fetches)
  }

  @Test
  @DisplayName("A hidden message stays hidden when a later page or refresh carries it again")
  fun hiddenSurvivesPaging() = runTest {
    val feed = PeaceMessageFeed { _, cursor ->
      if (cursor == null) PeaceMessagesPage(listOf(message("a"), message("b")), "next")
      else PeaceMessagesPage(listOf(message("c")), null)
    }
    feed.loadInitial()
    feed.hide("a")
    feed.loadMore()
    assertEquals(listOf("b", "c"), feed.visibleIds())

    feed.refresh()
    assertEquals(listOf("b"), feed.visibleIds())

    feed.unhide("a")
    assertEquals(listOf("a", "b"), feed.visibleIds())
  }

  @Test
  @DisplayName("Only the member's own posts read as theirs")
  fun isMine() = runTest {
    val remote = fixture()
    val posted = remote.postMessage("Thank you", "TH", null).message
    assertTrue(posted.isMine)
    assertFalse(FixturePauseEventRemote.sampleMessages(now).any { it.isMine })
    // Absent from the wire reads false.
    assertFalse(PeaceMessage("x", "Nan", "TH", "Peace", null, now).isMine)
  }

  private fun message(id: String) = PeaceMessage(id, "Nan", "TH", "Peace", null, now)
}
