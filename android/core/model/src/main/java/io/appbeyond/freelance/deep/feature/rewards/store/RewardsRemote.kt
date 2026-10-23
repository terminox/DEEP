package io.appbeyond.freelance.deep.feature.rewards.store

import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenSnapshot
import io.appbeyond.freelance.deep.feature.mindgarden.model.Plant
import io.appbeyond.freelance.deep.feature.rewards.model.WalletSummary
import java.util.UUID

/**
 * The backend seam for hearts, sunlight and the plant catalog. `GardenStore`
 * and `HeartLedger` depend on this so tests and previews run against
 * [MockRewardsRemote]; the shipped conformer in `:app` maps deep-api's DTOs
 * into these types (`/me/garden`, `/garden/plants`, `/me/garden/plant`,
 * `/me/wallet`, `/me/hearts/spend`).
 *
 * Ported from Deep/Deep/Features/Rewards/RewardsRemote.swift. Every member
 * throws on any failure; the stores decide what a failure means.
 */
interface RewardsRemote {

  /** `GET /me/garden` — the selected plant and the wallet riding it. */
  suspend fun garden(): GardenSnapshot

  /** `GET /garden/plants` — the picker catalog: every active plant with its
   * stages, DEEP Premium ones marked [Plant.isLocked] for a caller who may
   * not select them. */
  suspend fun plants(): List<Plant>

  /** `PUT /me/garden/plant` — switches the selected plant; sunlight already
   * banked is preserved. Throws [PlantLockedException] when the server
   * refuses a DEEP Premium plant (403 `premium_locked`). */
  suspend fun selectPlant(id: String): GardenSnapshot

  /** `GET /me/wallet`. */
  suspend fun wallet(): WalletSummary

  /**
   * `POST /me/hearts/spend`. [id] is a client-generated UUID, so a retry of
   * the same spend is idempotent server-side.
   */
  suspend fun spend(id: UUID, amount: Int, category: String, projectId: String?): WalletSummary
}

/**
 * [RewardsRemote.selectPlant]'s refusal of a DEEP Premium plant this member may
 * not grow — deep-api's 403 `premium_locked`. Its own type, so `GardenStore`
 * can tell "locked" from "couldn't reach the server" without knowing HTTP.
 */
class PlantLockedException : Exception("premium_locked")
