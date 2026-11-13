package io.appbeyond.freelance.deep.feature.globalpause.store

import io.appbeyond.freelance.deep.feature.globalpause.model.BlockedMember
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import java.time.Instant
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** Settings → Blocked members: loading, the empty state, and Unblock. */
class BlockedMembersListTest {

  private val now = Instant.ofEpochSecond(1_800_000_000)
  private fun member(id: String, name: String) = BlockedMember(id, name, now)

  private val nan = member("b1", "Nan")
  private val noah = member("b2", "Noah")
  private val mira = member("b3", "Mira")

  @Test
  @DisplayName("Loads the list the server keeps, newest first as sent")
  fun loads() = runTest {
    val list = BlockedMembersList(fetch = { listOf(nan, noah) }, remove = {})
    assertEquals(BlockedMembersList.Phase.Loading, list.state.value.phase)
    list.load()
    assertEquals(BlockedMembersList.Phase.Loaded, list.state.value.phase)
    assertEquals(listOf("Nan", "Noah"), list.state.value.members.map { it.displayName })
    assertFalse(list.state.value.isEmpty)
  }

  @Test
  @DisplayName("Nobody blocked reads as the empty state, not a failure")
  fun empty() = runTest {
    val list = BlockedMembersList(fetch = { emptyList() }, remove = {})
    list.load()
    assertTrue(list.state.value.isEmpty)
  }

  @Test
  @DisplayName("A failed first load says so; Try again recovers")
  fun failedLoadRetries() = runTest {
    var fail = true
    val list = BlockedMembersList(fetch = { if (fail) throw java.io.IOException("offline") else listOf(nan) }, remove = {})
    list.load()
    assertEquals(BlockedMembersList.Phase.Failed, list.state.value.phase)
    assertFalse(list.state.value.isEmpty)

    fail = false
    list.load()
    assertEquals(listOf(nan), list.state.value.members)
  }

  @Test
  @DisplayName("A failed reload keeps the list already shown")
  fun failedReloadKeepsList() = runTest {
    var fail = false
    val list = BlockedMembersList(fetch = { if (fail) throw java.io.IOException("offline") else listOf(nan) }, remove = {})
    list.load()
    fail = true
    list.load()
    assertEquals(BlockedMembersList.Phase.Loaded, list.state.value.phase)
    assertEquals(listOf(nan), list.state.value.members)
  }

  @Test
  @DisplayName("Unblock removes the row and tells the server")
  fun unblocks() = runTest {
    val removed = mutableListOf<String>()
    val list = BlockedMembersList(fetch = { listOf(nan, noah) }, remove = { removed += it })
    list.load()
    assertTrue(list.unblock(nan))
    assertEquals(listOf("b1"), removed)
    assertEquals(listOf(noah), list.state.value.members)
  }

  @Test
  @DisplayName("Unblocking the last one lands on the empty state")
  fun unblockLast() = runTest {
    val list = BlockedMembersList(fetch = { listOf(nan) }, remove = {})
    list.load()
    list.unblock(nan)
    assertTrue(list.state.value.isEmpty)
  }

  @Test
  @DisplayName("A refused unblock puts the row back where it was")
  fun refusedUnblockRestores() = runTest {
    val list = BlockedMembersList(fetch = { listOf(nan, noah, mira) }, remove = { throw java.io.IOException("offline") })
    list.load()
    assertFalse(list.unblock(noah))
    assertEquals(listOf(nan, noah, mira), list.state.value.members)
    assertTrue(list.state.value.unblockFailed)
  }

  @Test
  @DisplayName("Against the fixture: block, list, unblock, and the author's messages return")
  fun roundTrip() = runTest {
    val remote = FixturePauseEventRemote()
    val target = remote.messages(20, null).messages.first { it.displayName == "Amara" }
    remote.blockAuthor(target.id)
    assertFalse(remote.messages(20, null).messages.any { it.displayName == "Amara" })

    val list = BlockedMembersList(fetch = remote::blockedMembers, remove = remote::unblock)
    list.load()
    assertEquals(listOf("Amara"), list.state.value.members.map { it.displayName })

    // Blocking again is idempotent.
    remote.blockAuthor(target.id)
    assertEquals(1, remote.blockedMembers().size)

    list.unblock(list.state.value.members.single())
    assertTrue(list.state.value.isEmpty)
    assertTrue(remote.messages(20, null).messages.any { it.displayName == "Amara" })
  }
}
