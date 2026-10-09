package io.appbeyond.freelance.deep.feature.practice.store

import io.appbeyond.freelance.deep.feature.practice.model.PracticeCompletion
import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import java.util.UUID

/**
 * What one push settled: the ids the server accepted, plus the awards the
 * newly-stored sessions earned — already folded into a single grant
 * ([AwardGrant.fold]). [grant] is null when nothing was granted or capped and
 * no snapshot rode along.
 *
 * Ported from `PracticeSyncResult` in Deep/Deep/Features/Practice/Store/PracticeRemote.swift.
 */
data class PracticePushResult(
  val synced: List<UUID>,
  val grant: AwardGrant?,
)

/**
 * The backend seam for practice: offer completed sessions up
 * (`POST /me/practice/sessions`, at most [PracticeJournal.MAX_PUSH_BATCH] per
 * call), pull the full log back down (`GET /me/practice/sessions`). Every
 * member throws on any failure.
 */
interface PracticeRemote {

  /** Uploads completions; the result carries the accepted ids and any awards. */
  suspend fun push(sessions: List<PracticeCompletion>): PracticePushResult

  /** The server's whole log for the signed-in member. */
  suspend fun pull(): List<PracticeCompletion>
}

/**
 * Hermetic stand-in for previews and tests — accepts everything, remembers
 * nothing, awards nothing unless [grant] is set. Never wired by the shipped
 * app.
 */
class MockPracticeRemote(
  /** Handed back on every push. */
  var grant: AwardGrant? = null,
) : PracticeRemote {

  override suspend fun push(sessions: List<PracticeCompletion>): PracticePushResult =
    PracticePushResult(synced = sessions.map { it.id }, grant = grant)

  override suspend fun pull(): List<PracticeCompletion> = emptyList()
}
