package io.appbeyond.freelance.deep.shared.persistence

import kotlinx.coroutines.CompletableDeferred

/**
 * An in-memory blob whose writes park on [gate] while [armed] — so a test can
 * hold a store mid-persist and reset or cancel it there.
 */
class GatedBlobStore(initial: String? = null) : BlobStoring {

  @Volatile
  var value: String? = initial
    private set

  @Volatile
  var armed = false

  val gate = CompletableDeferred<Unit>()

  override suspend fun read(): String? = value

  override suspend fun write(value: String?) {
    if (armed) gate.await()
    this.value = value
  }
}
