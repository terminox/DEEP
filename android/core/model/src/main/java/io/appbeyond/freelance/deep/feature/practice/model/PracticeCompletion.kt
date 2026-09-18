package io.appbeyond.freelance.deep.feature.practice.model

import java.time.Instant
import java.util.UUID

/**
 * One finished guided session, as the journal remembers it — what was
 * practised, for how long, and when. [isSynced] tracks whether the completion
 * has reached the backend yet; unsynced entries wait quietly for the next
 * push.
 *
 * Ported from Deep/Deep/Features/Practice/Models/PracticeCompletion.swift.
 */
data class PracticeCompletion(
  val id: UUID,
  /** The session's title at the time of practice, e.g. "Balancing breath". */
  val title: String,
  val durationSeconds: Int,
  val completedAt: Instant,
  val isSynced: Boolean,
)
