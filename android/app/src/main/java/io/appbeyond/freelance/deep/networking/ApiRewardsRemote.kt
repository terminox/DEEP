package io.appbeyond.freelance.deep.networking

import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenSnapshot
import io.appbeyond.freelance.deep.feature.mindgarden.model.Plant
import io.appbeyond.freelance.deep.feature.rewards.model.WalletSummary
import io.appbeyond.freelance.deep.feature.rewards.store.PlantLockedException
import io.appbeyond.freelance.deep.feature.rewards.store.RewardsRemote
import java.util.UUID

/**
 * [RewardsRemote] over deep-api — the Android twin of `APIRewardsRemote` in
 * `RewardsRemote.swift`, minus `reportListen` and `claimPauseAward`: on Android
 * each award producer owns its own call (the listen report is
 * `SoundListensService.reportListen`, behind `ListenReporter`'s durable
 * queue) and hands its folded grant to the shared
 * ingest, so this seam stays the garden-and-wallet one `GardenStore` and
 * `HeartLedger` need.
 *
 * Every failure surfaces as a [DeepApiException] through [apiCall]; the
 * stores decide what a failure means. The DTO mapping lives in `RewardDtos.kt`.
 */
class ApiRewardsRemote(private val service: RewardsService) : RewardsRemote {

  override suspend fun garden(): GardenSnapshot = apiCall { service.garden() }.toDomain()

  override suspend fun plants(): List<Plant> = apiCall { service.plants() }.toDomain()

  /** A 403 `premium_locked` becomes [PlantLockedException], so `GardenStore`
   * can tell a DEEP Premium refusal from a lost connection. */
  override suspend fun selectPlant(id: String): GardenSnapshot =
    try {
      apiCall { service.selectPlant(SelectPlantRequest(plantId = id)) }.toDomain()
    } catch (refused: DeepApiException.Http) {
      if (refused.code == PREMIUM_LOCKED) throw PlantLockedException() else throw refused
    }

  override suspend fun wallet(): WalletSummary = apiCall { service.wallet() }.wallet.toDomain()

  override suspend fun spend(id: UUID, amount: Int, category: String, projectId: String?): WalletSummary =
    apiCall {
      service.spend(
        SpendHeartsRequest(id = id.toString(), amount = amount, category = category, projectId = projectId),
      )
    }.wallet.toDomain()
}

/** deep-api's `error.code` for DEEP Premium content this caller may not use. */
private const val PREMIUM_LOCKED = "premium_locked"
