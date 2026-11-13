package io.appbeyond.freelance.deep.feature.globalpause.store

import io.appbeyond.freelance.deep.feature.globalpause.model.BlockedMember
import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessage
import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessageReportReason
import kotlinx.coroutines.CancellationException

/**
 * Report and Block from a peace message card, in the order the member should
 * feel them: the card leaves the feed at the tap, the server is told, and the
 * card comes back only if the server refused. iOS behaves the same.
 *
 * - **Report** hides that one message. The server leaves it out of this
 *   member's feeds from then on, so nothing needs refetching.
 * - **Block** hides the tapped message, then refetches the feed: the server
 *   now leaves out everything by that author, and the client never learns who
 *   the author is, so a refetch is the honest way to find the rest of their
 *   messages. A failed refetch keeps the feed as it was; the next pull catches
 *   up.
 *
 * @param sendReport `POST /pause/messages/:id/report`.
 * @param sendBlock `POST /pause/messages/:id/block-author`.
 */
class PeaceMessageModeration(
  private val feed: PeaceMessageFeed,
  private val sendReport: suspend (messageId: String, reason: PeaceMessageReportReason) -> Unit,
  private val sendBlock: suspend (messageId: String) -> BlockedMember?,
) {

  /** True when the report landed; false when it failed and the card is back. */
  suspend fun report(message: PeaceMessage, reason: PeaceMessageReportReason): Boolean =
    hidingWhile(message) { sendReport(message.id, reason) }

  /** True when the block landed and the feed was asked again; false when it failed and the card is back. */
  suspend fun block(message: PeaceMessage): Boolean {
    val blocked = hidingWhile(message) { sendBlock(message.id) }
    if (blocked) feed.refresh()
    return blocked
  }

  private suspend fun hidingWhile(message: PeaceMessage, call: suspend () -> Unit): Boolean {
    feed.hide(message.id)
    return try {
      call()
      true
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (_: Exception) {
      feed.unhide(message.id)
      false
    }
  }
}
