package io.appbeyond.freelance.deep.feature.rewards.store

import io.appbeyond.freelance.deep.shared.persistence.BlobStoring
import io.appbeyond.freelance.deep.shared.persistence.InstantAsStringSerializer
import io.appbeyond.freelance.deep.shared.persistence.StoreJson
import io.appbeyond.freelance.deep.shared.persistence.readOrNull
import io.appbeyond.freelance.deep.shared.persistence.writeQuietly
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * Remembers the day the continuity beat was last witnessed, so the rhythm is
 * noticed once a day across every practice: a DEEP Session and a Global Pause
 * on the same day share the one moment rather than each claiming it.
 *
 * Ported from Deep/Deep/Features/Rewards/Models/ContinuityWitness.swift. One
 * instant is the whole state; the day it falls on is read in [zone], so the
 * boundary follows the member's timezone. iOS reads its `UserDefaults` stamp
 * synchronously in `init`; here the blob is read on first use, so every member
 * that depends on it suspends.
 *
 * Persisted blob: `{"lastWitnessedAt":"2026-10-09T05:00:00Z"}`.
 */
class ContinuityWitness(
  private val blob: BlobStoring,
  private val clock: Clock,
  private val zone: ZoneId,
) {

  @Serializable
  private data class Blob(
    @Serializable(with = InstantAsStringSerializer::class)
    val lastWitnessedAt: Instant? = null,
  )

  private val _lastWitnessed = MutableStateFlow<Instant?>(null)

  /** The last moment the rhythm was witnessed; null before the first one. */
  val lastWitnessed: StateFlow<Instant?> = _lastWitnessed.asStateFlow()

  private val restoreLock = Mutex()

  @Volatile
  private var restored = false

  /** Serialises every mutation together with its write, so a stamp being
   * written can never land after a reset has cleared the blob. */
  private val mutationLock = Mutex()

  /** Bumped by [resetLocalState]; a witness asked for before a reset is
   * dropped rather than stamped onto the next account. */
  @Volatile
  private var generation = 0L

  /**
   * Loads the persisted stamp. Safe to call any number of times; every other
   * member calls it first, so calling it eagerly at launch is only a warm-up.
   */
  suspend fun restore() {
    if (restored) return
    restoreLock.withLock {
      if (restored) return
      val stored = blob.readOrNull()?.let { json ->
        runCatching { StoreJson.decodeFromString(Blob.serializer(), json) }.getOrNull()
      }
      _lastWitnessed.value = stored?.lastWitnessedAt
      restored = true
    }
  }

  /**
   * Whether today's beat has already been shown. Derived rather than stored,
   * so a session left open past midnight reads false on its own — no timer.
   */
  suspend fun hasWitnessedToday(): Boolean {
    restore()
    return witnessedToday()
  }

  private fun witnessedToday(): Boolean {
    val last = _lastWitnessed.value ?: return false
    return LocalDate.ofInstant(last, zone) == LocalDate.ofInstant(clock.instant(), zone)
  }

  /**
   * Stamps today. Called as the continuity screen appears — not when the
   * ritual is composed — so an ending the member walks away from doesn't
   * spend the day's one witnessing. A no-op if today is already stamped, or
   * if the account was reset since the call began. The stamp and its write
   * complete together even if the caller is cancelled.
   */
  suspend fun witnessToday() {
    restore()
    val stamp = generation
    withContext(NonCancellable) {
      mutationLock.withLock {
        if (generation != stamp || witnessedToday()) return@withLock
        val now = clock.instant()
        _lastWitnessed.value = now
        blob.writeQuietly(StoreJson.encodeToString(Blob.serializer(), Blob(now)))
      }
    }
  }

  /**
   * Forgets the signed-out account's day, so the next account's first
   * practice meets its own rhythm. Log out and account deletion call this.
   */
  suspend fun resetLocalState() {
    restore()
    generation++
    withContext(NonCancellable) {
      mutationLock.withLock {
        _lastWitnessed.value = null
        blob.writeQuietly(null)
      }
    }
  }
}
