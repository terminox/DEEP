package io.appbeyond.freelance.deep.feature.rewards.store

import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenPlot
import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenSnapshot
import io.appbeyond.freelance.deep.feature.mindgarden.model.Plant
import io.appbeyond.freelance.deep.feature.rewards.model.WalletSummary
import java.util.UUID

/**
 * Hermetic stand-in for previews and tests: a small in-memory garden + wallet
 * that behaves like the server, with per-call failure switches for exercising
 * rollback paths. Never wired by the shipped app.
 *
 * Ported from `MockRewardsRemote` in Deep/Deep/Features/Rewards/RewardsRemote.swift.
 */
class MockRewardsRemote(
  var catalog: List<Plant> = Plant.fixtures,
  var selectedPlantId: String? = Plant.oakFixture.id,
  var sunlightByPlant: Map<String, Int> = mapOf(Plant.oakFixture.id to 240),
  var walletSummary: WalletSummary = WalletSummary.sample,
) : RewardsRemote {

  /** Thrown by a call whose failure switch is on. */
  class Failure : Exception("MockRewardsRemote failure")

  /** One spend the mock accepted — the idempotency id and payload that would
   * have gone over the wire. */
  data class Spend(val id: UUID, val amount: Int, val category: String, val projectId: String?)

  // Failure switches — every matching call throws while set.
  var failsGarden = false
  var failsPlants = false
  var failsSelectPlant = false
  var failsSpend = false

  /** Spends accepted, newest last. */
  val spends: MutableList<Spend> = mutableListOf()

  private val snapshot: GardenSnapshot
    get() {
      val plant = catalog.firstOrNull { it.id == selectedPlantId } ?: catalog.firstOrNull()
      return GardenSnapshot(
        plot = plant?.let {
          GardenPlot(plant = it, sunlight = sunlightByPlant[it.id] ?: 0, sunlightByPlant = sunlightByPlant)
        },
        wallet = walletSummary,
      )
    }

  override suspend fun garden(): GardenSnapshot {
    if (failsGarden) throw Failure()
    return snapshot
  }

  override suspend fun plants(): List<Plant> {
    if (failsPlants) throw Failure()
    return catalog
  }

  override suspend fun selectPlant(id: String): GardenSnapshot {
    if (failsSelectPlant || catalog.none { it.id == id }) throw Failure()
    selectedPlantId = id
    return snapshot
  }

  override suspend fun wallet(): WalletSummary = walletSummary

  override suspend fun spend(id: UUID, amount: Int, category: String, projectId: String?): WalletSummary {
    if (failsSpend || walletSummary.heartsBalance < amount) throw Failure()
    spends += Spend(id, amount, category, projectId)
    val given = walletSummary.givenByCategory.toMutableMap()
    given[category] = (given[category] ?: 0) + amount
    walletSummary = walletSummary.copy(
      heartsBalance = walletSummary.heartsBalance - amount,
      heartsGiven = walletSummary.heartsGiven + amount,
      givenByCategory = given,
    )
    return walletSummary
  }
}
