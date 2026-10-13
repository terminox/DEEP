package io.appbeyond.freelance.deep.feature.globalpause.store

import io.appbeyond.freelance.deep.shared.persistence.InMemoryBlobStore
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals

class PresenceIdStoreTest {

  @Test
  @DisplayName("One identity per install, kept across launches")
  fun stableAcrossLaunches() = runTest {
    val blob = InMemoryBlobStore()
    val first = PresenceIdStore(blob).id()
    assertEquals(first, PresenceIdStore(blob).id())
    assertEquals(1, blob.writes)
  }

  @Test
  @DisplayName("A stored id the server would refuse is replaced")
  fun refusesAMalformedId() = runTest {
    val blob = InMemoryBlobStore(initial = "short")
    val id = PresenceIdStore(blob).id()
    assertNotEquals("short", id)
    assertEquals(id, blob.value)
  }
}
