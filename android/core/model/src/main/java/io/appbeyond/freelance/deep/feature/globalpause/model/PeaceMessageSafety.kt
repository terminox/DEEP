package io.appbeyond.freelance.deep.feature.globalpause.model

import java.time.Instant

/*
 * What a member can do about a peace message that isn't theirs: report it, or
 * block whoever wrote it. The store rules for user-generated content ask for
 * both, and DEEP answers them the same way on iOS and Android.
 */

/** Why a message was reported — `POST /pause/messages/:id/report`'s `reason`. */
enum class PeaceMessageReportReason(val wire: String) {
  Offensive("offensive"),
  Harassment("harassment"),
  Spam("spam"),
  Other("other"),
}

/**
 * Someone the member has blocked, as `GET /me/blocks` lists them. The
 * blocked member's own id never leaves the server.
 *
 * @property id the block's id, which `DELETE /me/blocks/:id` takes.
 * @property displayName the blocked member's current name.
 */
data class BlockedMember(
  val id: String,
  val displayName: String,
  val createdAt: Instant,
)
