package io.appbeyond.freelance.deep.feature.globalpause.store

import io.appbeyond.freelance.deep.feature.globalpause.model.BlockedMember
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Settings → Blocked members: who the member has blocked, and Unblock.
 *
 * - [load] reads `GET /me/blocks`. A failure with nothing loaded says so
 *   (with Try again); a failure over a list already shown keeps the list.
 * - [unblock] takes the row away at the tap and puts it back where it was if
 *   the server refuses, so the list never claims an unblock that didn't
 *   happen.
 *
 * Not thread-safe by design: one screen drives it from the main thread.
 *
 * @param fetch `GET /me/blocks`, newest first.
 * @param remove `DELETE /me/blocks/:id`.
 */
class BlockedMembersList(
  private val fetch: suspend () -> List<BlockedMember>,
  private val remove: suspend (blockId: String) -> Unit,
) {

  enum class Phase { Loading, Loaded, Failed }

  /**
   * @property unblockFailed the last unblock was refused and its row is back;
   *   cleared by the next unblock or load.
   */
  data class State(
    val phase: Phase = Phase.Loading,
    val members: List<BlockedMember> = emptyList(),
    val unblockFailed: Boolean = false,
  ) {
    val isEmpty: Boolean get() = phase == Phase.Loaded && members.isEmpty()
  }

  private val _state = MutableStateFlow(State())
  val state: StateFlow<State> = _state.asStateFlow()

  suspend fun load() {
    val hadList = _state.value.phase == Phase.Loaded
    if (!hadList) _state.update { it.copy(phase = Phase.Loading) }
    val members = attempt { fetch() }
    _state.update {
      when {
        members != null -> State(phase = Phase.Loaded, members = members)
        hadList -> it
        else -> it.copy(phase = Phase.Failed)
      }
    }
  }

  /** True when the server let them go. */
  suspend fun unblock(member: BlockedMember): Boolean {
    val index = _state.value.members.indexOfFirst { it.id == member.id }
    if (index < 0) return false
    _state.update { state -> state.copy(members = state.members.filterNot { it.id == member.id }, unblockFailed = false) }
    val removed = attempt { remove(member.id) } != null
    if (!removed) {
      _state.update { state ->
        val members = state.members.toMutableList()
        members.add(index.coerceAtMost(members.size), member)
        state.copy(members = members, unblockFailed = true)
      }
    }
    return removed
  }

  private suspend fun <T> attempt(block: suspend () -> T): T? =
    try {
      block()
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (_: Exception) {
      null
    }
}
