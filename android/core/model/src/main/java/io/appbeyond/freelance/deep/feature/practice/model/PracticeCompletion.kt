package io.appbeyond.freelance.deep.feature.practice.model

import io.appbeyond.freelance.deep.shared.persistence.InstantAsStringSerializer
import io.appbeyond.freelance.deep.shared.persistence.UuidAsStringSerializer
import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

/**
 * One finished guided session, as the journal remembers it — what was
 * practised, for how long, and when. [isSynced] tracks whether the completion
 * has reached the backend yet; unsynced entries wait quietly for the next
 * push.
 *
 * Ported from Deep/Deep/Features/Practice/Models/PracticeCompletion.swift.
 * `@Serializable` (as iOS's `Codable`) because the practice journal persists
 * its entries whole: `{"id":"…uuid…","title":"Balancing breath",
 * "durationSeconds":300,"completedAt":"2026-07-23T05:00:00Z","isSynced":false}`.
 */
@Serializable
data class PracticeCompletion(
  @Serializable(with = UuidAsStringSerializer::class)
  val id: UUID,
  /** The session's title at the time of practice, e.g. "Balancing breath". */
  val title: String,
  val durationSeconds: Int,
  @Serializable(with = InstantAsStringSerializer::class)
  val completedAt: Instant,
  val isSynced: Boolean,
)
