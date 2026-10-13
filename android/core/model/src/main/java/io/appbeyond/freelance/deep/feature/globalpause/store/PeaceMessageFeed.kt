package io.appbeyond.freelance.deep.feature.globalpause.store

import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessage
import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessagesPage
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * The peace-message feed in Fuku's Lounge, keyset-paged: the first page on
 * arrival, more as the last card scrolls into view, the whole thing replaced
 * on a pull.
 *
 * Ported from the paging in Deep/Deep/Features/GlobalPause/Screens/GlobalPauseLobbyView.swift,
 * lifted out of the screen so it can be tested:
 *
 * - [loadInitial] runs once; a failure leaves the section hidden for the next
 *   visit to retry.
 * - [loadMore] keeps its cursor on failure, so the tail retries the next time
 *   it scrolls into view, and drops ids it already holds.
 * - [refresh] replaces the feed and bumps an epoch, so a [loadMore] still in
 *   flight from the old feed can tell its page is stale. A failed refresh keeps
 *   the feed it had.
 *
 * Not thread-safe by design: one screen drives it from the main thread.
 *
 * @param fetch one page — `GET /pause/messages?limit=&cursor=`.
 */
class PeaceMessageFeed(
  private val pageSize: Int = PAGE_SIZE,
  private val fetch: suspend (limit: Int, cursor: String?) -> PeaceMessagesPage,
) {

  data class State(
    val messages: List<PeaceMessage> = emptyList(),
    val nextCursor: String? = null,
    val isLoadingMore: Boolean = false,
  )

  private val _state = MutableStateFlow(State())
  val state: StateFlow<State> = _state.asStateFlow()

  private var epoch = 0

  suspend fun loadInitial() {
    if (_state.value.messages.isNotEmpty()) return
    val page = attempt { fetch(pageSize, null) } ?: return
    _state.update { it.copy(messages = page.messages, nextCursor = page.nextCursor) }
  }

  suspend fun loadMore() {
    val current = _state.value
    val cursor = current.nextCursor ?: return
    if (current.isLoadingMore) return
    _state.update { it.copy(isLoadingMore = true) }
    val started = epoch
    try {
      val page = attempt { fetch(pageSize, cursor) } ?: return
      // A refresh replaced the feed mid-flight.
      if (started != epoch) return
      _state.update { state ->
        val known = state.messages.mapTo(HashSet()) { it.id }
        state.copy(
          messages = state.messages + page.messages.filter { it.id !in known },
          nextCursor = page.nextCursor,
        )
      }
    } finally {
      _state.update { it.copy(isLoadingMore = false) }
    }
  }

  suspend fun refresh() {
    val page = attempt { fetch(pageSize, null) } ?: return
    epoch += 1
    _state.update { it.copy(messages = page.messages, nextCursor = page.nextCursor) }
  }

  private suspend fun <T> attempt(block: suspend () -> T): T? =
    try {
      block()
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (_: Exception) {
      null
    }

  companion object {
    const val PAGE_SIZE = 20

    /**
     * The feed as shown: whatever has been paged in, with the member's own
     * message from tonight seated at the head. It was written after the feed
     * was fetched, and the session is presented over the lounge — which stays
     * composed underneath — so deriving it keeps the lounge honest whenever it
     * draws. The de-dupe means a later page that catches up with it changes
     * nothing.
     */
    fun displayed(messages: List<PeaceMessage>, posted: PeaceMessage?): List<PeaceMessage> =
      if (posted == null || messages.any { it.id == posted.id }) messages else listOf(posted) + messages
  }
}
