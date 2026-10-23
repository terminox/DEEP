package io.appbeyond.freelance.deep.feature.mindgarden.model

import io.appbeyond.freelance.deep.feature.rewards.model.WalletSummary

/**
 * The selected plant in the ground: the `garden` half of `GET /me/garden`.
 *
 * @property plant the selected plant with its full stage ladder.
 * @property sunlight sunlight banked into the selected plant.
 * @property sunlightByPlant lifetime sunlight per plant id — unselected plants
 *   keep theirs and resume where they left off.
 */
data class GardenPlot(
  val plant: Plant,
  val sunlight: Int,
  val sunlightByPlant: Map<String, Int>,
)

/**
 * The user's garden as the server holds it, plus the wallet riding the same
 * `{ garden, wallet }` envelope so one fetch hydrates both stores. Returned by
 * `GET /me/garden` and the plant-switch `PUT`.
 *
 * Ported from `GardenSnapshot` in Deep/Deep/Features/Rewards/RewardsRemote.swift.
 * DIVERGENCE: deep-api sends `garden: null` when the catalog has no eligible
 * plant at all, which iOS's DTO cannot decode (the whole fetch fails and the
 * wallet is lost with it). Here [plot] is nullable, so the wallet still reaches
 * the ledger and the garden simply stays as it was.
 */
data class GardenSnapshot(
  val plot: GardenPlot?,
  val wallet: WalletSummary?,
)
