package io.appbeyond.freelance.deep.networking

import io.appbeyond.freelance.deep.feature.practice.model.PracticeCompletion
import io.appbeyond.freelance.deep.feature.practice.store.PracticePushResult
import io.appbeyond.freelance.deep.feature.practice.store.PracticeRemote

/**
 * [PracticeRemote] over deep-api — the Android twin of `APIPracticeRemote` in
 * `PracticeRemote.swift`. Batching (at most 200 a request), retry and the
 * generation guard all live in `PracticeJournal`; this only speaks the wire.
 *
 * Every failure surfaces as a [DeepApiException] through [apiCall], which the
 * journal reads as "leave it unsynced for the next push".
 */
class ApiPracticeRemote(private val service: PracticeService) : PracticeRemote {

  override suspend fun push(sessions: List<PracticeCompletion>): PracticePushResult =
    apiCall { service.push(PracticeSyncRequest(sessions.map { it.toRequest() })) }.toDomain()

  override suspend fun pull(): List<PracticeCompletion> = apiCall { service.sessions() }.toDomain()
}
