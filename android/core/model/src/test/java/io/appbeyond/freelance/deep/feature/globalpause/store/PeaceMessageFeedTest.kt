package io.appbeyond.freelance.deep.feature.globalpause.store

import io.appbeyond.freelance.deep.feature.globalpause.model.Intention
import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessage
import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessagesPage
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import java.time.Instant
import java.util.Locale
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull

/**
 * The lounge's peace-message feed: keyset paging lifted out of
 * `GlobalPauseLobbyView`, and the message's own small readings.
 */
class PeaceMessageFeedTest {

  private val now = Instant.ofEpochSecond(1_800_000_000)
  private val all = FixturePauseEventRemote.sampleMessages(now)

  private fun message(id: String, intention: String? = null) =
    PeaceMessage(id, "Nan", "TH", "Peace", intention, now)

  @Test
  @DisplayName("Pages append in order, then the feed is exhausted")
  fun pagesAppend() = runTest {
    val remote = FixturePauseEventRemote()
    val feed = PeaceMessageFeed(pageSize = 4) { limit, cursor -> remote.messages(limit, cursor) }

    feed.loadInitial()
    assertEquals(4, feed.state.value.messages.size)
    assertEquals("4", feed.state.value.nextCursor)

    feed.loadMore()
    feed.loadMore()
    assertEquals(10, feed.state.value.messages.size)
    assertNull(feed.state.value.nextCursor)
    assertEquals(all.map { it.id }, feed.state.value.messages.map { it.id })

    // Nothing left: a further reach for more asks nobody.
    feed.loadMore()
    assertEquals(10, feed.state.value.messages.size)
  }

  @Test
  @DisplayName("A page that overlaps what's held adds only the new ids")
  fun deDupesOverlap() = runTest {
    val pages = ArrayDeque(
      listOf(
        PeaceMessagesPage(listOf(message("a"), message("b")), "c1"),
        PeaceMessagesPage(listOf(message("b"), message("c")), null),
      ),
    )
    val feed = PeaceMessageFeed { _, _ -> pages.removeFirst() }
    feed.loadInitial()
    feed.loadMore()
    assertEquals(listOf("a", "b", "c"), feed.state.value.messages.map { it.id })
  }

  @Test
  @DisplayName("A failed page keeps its cursor so the tail can retry")
  fun failedPageKeepsCursor() = runTest {
    var fail = false
    val feed = PeaceMessageFeed { _, cursor ->
      if (fail) throw java.io.IOException("offline")
      if (cursor == null) PeaceMessagesPage(listOf(message("a")), "next") else PeaceMessagesPage(listOf(message("b")), null)
    }
    feed.loadInitial()
    fail = true
    feed.loadMore()
    assertEquals("next", feed.state.value.nextCursor)
    assertFalse(feed.state.value.isLoadingMore)

    fail = false
    feed.loadMore()
    assertEquals(listOf("a", "b"), feed.state.value.messages.map { it.id })
  }

  @Test
  @DisplayName("A refresh landing mid-page makes the stale page drop")
  fun refreshBeatsAStalePage() = runTest {
    val gate = CompletableDeferred<Unit>()
    val feed = PeaceMessageFeed { _, cursor ->
      when (cursor) {
        null -> PeaceMessagesPage(listOf(message("fresh")), "c")
        else -> {
          gate.await()
          PeaceMessagesPage(listOf(message("stale")), null)
        }
      }
    }
    feed.loadInitial()
    val more = launch { feed.loadMore() }
    runCurrent()
    feed.refresh()
    gate.complete(Unit)
    more.join()

    assertEquals(listOf("fresh"), feed.state.value.messages.map { it.id })
    assertFalse(feed.state.value.isLoadingMore)
  }

  @Test
  @DisplayName("A failed refresh keeps the feed it had")
  fun failedRefreshKeepsTheFeed() = runTest {
    var fail = false
    val feed = PeaceMessageFeed { _, _ ->
      if (fail) throw java.io.IOException("offline") else PeaceMessagesPage(listOf(message("a")), null)
    }
    feed.loadInitial()
    fail = true
    feed.refresh()
    assertEquals(listOf("a"), feed.state.value.messages.map { it.id })
  }

  @Test
  @DisplayName("Tonight's own message heads a feed fetched before it, once")
  fun ownMessageHeadsTheFeed() {
    val mine = message("mine")
    val shown = PeaceMessageFeed.displayed(listOf(message("a")), mine)
    assertEquals(listOf("mine", "a"), shown.map { it.id })

    // A later page that caught up with it changes nothing.
    val caughtUp = PeaceMessageFeed.displayed(listOf(mine, message("a")), mine)
    assertEquals(listOf("mine", "a"), caughtUp.map { it.id })
  }

  @Test
  @DisplayName("A tag reads as tonight's label, else as the key humanised")
  fun intentionLabels() {
    val options = listOf(Intention("someone-i-love", "คนที่ฉันรัก"))
    assertEquals("คนที่ฉันรัก", message("1", "someone-i-love").intentionLabel(options))
    // A word retired in the admin still reads on the older messages that carry it.
    assertEquals("Inner Calm", message("2", "inner-calm").intentionLabel(options))
    assertNull(message("3", null).intentionLabel(options))
  }

  @Test
  @DisplayName("The place is the country's name in the member's language, or nothing")
  fun countryNames() {
    assertEquals("Japan", message("1").copy(countryIso = "JP").countryName(Locale.ENGLISH))
    assertEquals("ญี่ปุ่น", message("1").copy(countryIso = "JP").countryName(Locale.forLanguageTag("th")))
    assertEquals("", message("1").copy(countryIso = null).countryName(Locale.ENGLISH))
  }
}
