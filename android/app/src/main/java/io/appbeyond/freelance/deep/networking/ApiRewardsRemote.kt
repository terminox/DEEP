package io.appbeyond.freelance.deep.networking

import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenSnapshot
import io.appbeyond.freelance.deep.feature.mindgarden.model.Plant
import io.appbeyond.freelance.deep.feature.rewards.model.WalletSummary
import io.appbeyond.freelance.deep.feature.rewards.store.RewardsRemote
import java.util.UUID

/**
 * [RewardsRemote] over deep-api — the Android twin of `APIRewardsRemote` in
 * `RewardsRemote.swift`, minus `reportListen` and `claimPauseAward`: on Android
 * each award producer owns its own call (the listen report lives with the
 * player, `ApiTrackListenReporter`) and hands its folded grant to the shared
 * ingest, so this seam stays the garden-and-wallet one `GardenStore` and
 * `HeartLedger` need.
 *
 * Every failure surfaces as a [DeepApiException] through [apiCall]; the
 * stores decide what a failure means. The DTO mapping lives in `RewardDtos.kt`.
 */
class ApiRewardsRemote(private val service: RewardsService) : RewardsRemote {

  override suspend fun garden(): GardenSnapshot = apiCall { service.garden() }.toDomain()

  override suspend fun plants(): List<Plant> = apiCall { service.plants() }.toDomain()

  override suspend fun selectPlant(id: String): GardenSnapshot =
    apiCall { service.selectPlant(SelectPlantRequest(plantId = id)) }.toDomain()

  override suspend fun wallet(): WalletSummary = apiCall { service.wallet() }.wallet.toDomain()

  override suspend fun spend(id: UUID, amount: Int, category: String, projectId: String?): WalletSummary =
    apiCall {
      service.spend(
        SpendHeartsRequest(id = id.toString(), amount = amount, category = category, projectId = projectId),
      )
    }.wallet.toDomain()
}
