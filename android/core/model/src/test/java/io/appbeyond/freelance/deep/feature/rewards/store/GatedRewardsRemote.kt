package io.appbeyond.freelance.deep.feature.rewards.store

import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenSnapshot
import io.appbeyond.freelance.deep.feature.mindgarden.model.Plant
import io.appbeyond.freelance.deep.feature.rewards.model.WalletSummary
import kotlinx.coroutines.CompletableDeferred
import java.util.UUID

/**
 * A [RewardsRemote] whose garden, plant-switch and spend calls park on [gate]
 * until a test opens it, then answer from [delegate] — so a test can reset a
 * store while a response is in flight and watch what happens when it lands.
 */
class GatedRewardsRemote(
  val delegate: MockRewardsRemote = MockRewardsRemote(),
) : RewardsRemote {

  val gate = CompletableDeferred<Unit>()

  override suspend fun garden(): GardenSnapshot {
    gate.await()
    return delegate.garden()
  }

  override suspend fun plants(): List<Plant> = delegate.plants()

  override suspend fun selectPlant(id: String): GardenSnapshot {
    gate.await()
    return delegate.selectPlant(id)
  }

  override suspend fun wallet(): WalletSummary = delegate.wallet()

  override suspend fun spend(id: UUID, amount: Int, category: String, projectId: String?): WalletSummary {
    gate.await()
    return delegate.spend(id, amount, category, projectId)
  }
}
