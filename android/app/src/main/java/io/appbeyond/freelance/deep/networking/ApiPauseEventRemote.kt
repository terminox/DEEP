package io.appbeyond.freelance.deep.networking

import io.appbeyond.freelance.deep.feature.globalpause.model.PauseJoinPoint
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseLiveSnapshot
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseSchedule
import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessagesPage
import io.appbeyond.freelance.deep.feature.globalpause.model.PostedPeaceMessage
import io.appbeyond.freelance.deep.feature.globalpause.model.SyncedClock
import io.appbeyond.freelance.deep.feature.globalpause.store.PauseAwardClaim
import io.appbeyond.freelance.deep.feature.globalpause.store.PauseEventRemote
import kotlinx.coroutines.CancellationException

/**
 * [PauseEventRemote] over deep-api — the Android twin of
 * `APIPauseEventRepository`, plus the claim `APIRewardsRemote` makes there.
 *
 * Every response that carries `serverNow` is pushed into the shared [clock]
 * — the schedule, the live poll, the message feed and a posted message, as on
 * iOS — so the phase engine keeps agreeing with the server, dev time travel
 * included. Every failure surfaces as a [DeepApiException] through [apiCall];
 * a network failure is a [DeepApiException.Transport], which is what the
 * claim's retry looks for.
 */
class ApiPauseEventRemote(
  private val service: PauseEventService,
  private val clock: SyncedClock,
) : PauseEventRemote {

  override suspend fun schedule(): PauseSchedule {
    val dto = apiCall { service.schedule() }
    sync(dto.serverNow)
    return dto.toDomain()
  }

  override suspend fun live(): PauseLiveSnapshot {
    val snapshot = apiCall { service.live() }.toDomain()
    clock.sync(snapshot.serverNow)
    return snapshot
  }

  override suspend fun heartbeat(presenceId: String, countryIso: String?): PauseJoinPoint? =
    apiCall { service.heartbeat(PauseHeartbeatRequest(presenceId = presenceId, countryIso = countryIso)) }
      .location
      ?.let { PauseJoinPoint(lat = it.lat.toFloat(), lon = it.lon.toFloat()) }

  override suspend fun leave(presenceId: String) {
    try {
      apiCall { service.leave(presenceId) }
    } catch (cancelled: CancellationException) {
      throw cancelled
    } catch (_: DeepApiException) {
      // Best-effort: the server sweeps stale presence within a minute.
    }
  }

  override suspend fun messages(limit: Int, cursor: String?): PeaceMessagesPage {
    val dto = apiCall { service.messages(limit, cursor) }
    sync(dto.serverNow)
    return PeaceMessagesPage(messages = dto.messages.map { it.toDomain() }, nextCursor = dto.nextCursor)
  }

  override suspend fun postMessage(text: String, countryIso: String?, intention: String?): PostedPeaceMessage {
    val dto = apiCall {
      service.postMessage(PeaceMessagePostRequest(text = text, countryIso = countryIso, intention = intention))
    }
    sync(dto.serverNow)
    return PostedPeaceMessage(
      message = dto.message.toDomain(),
      // `duplicate` for every later message folds to a grant of nothing that
      // still carries the fresh wallet — the shared ingest reconciles on it.
      award = foldAwards(listOfNotNull(dto.award), dto.wallet, dto.plant)?.takeIf { it.hearts > 0 || it.sunlight > 0 },
    )
  }

  override suspend fun submitReflection(intention: String?, mood: String?) {
    apiCall { service.reflection(PauseReflectionRequest(intention = intention, mood = mood)) }
  }

  override suspend fun claimPauseAward(): PauseAwardClaim {
    val dto = apiCall { service.claimAward() }
    sync(dto.serverNow)
    return PauseAwardClaim(
      eligible = dto.eligible ?: true,
      // Folded as iOS folds it: an ineligible or already-claimed night still
      // hands back the wallet and plant, which reconcile the stores.
      grant = foldAwards(listOfNotNull(dto.award), dto.wallet, dto.plant),
    )
  }

  private fun sync(serverNow: String?) {
    serverNow?.let { runCatching { IsoInstantSerializer.parse(it) }.getOrNull() }?.let(clock::sync)
  }
}
