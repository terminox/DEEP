package io.appbeyond.freelance.deep.networking

import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenPlot
import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenSnapshot
import io.appbeyond.freelance.deep.feature.mindgarden.model.Plant
import io.appbeyond.freelance.deep.feature.mindgarden.model.PlantStage
import io.appbeyond.freelance.deep.feature.rewards.model.AwardCap
import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import io.appbeyond.freelance.deep.feature.rewards.model.AwardKind
import io.appbeyond.freelance.deep.feature.rewards.model.AwardOutcome
import io.appbeyond.freelance.deep.feature.rewards.model.PlantProgress
import io.appbeyond.freelance.deep.feature.rewards.model.RewardRules
import io.appbeyond.freelance.deep.feature.rewards.model.WalletSummary
import kotlinx.serialization.Serializable

/*
 * Wire shapes for hearts, sunlight and the plant catalog, ported from the
 * reward DTOs in `DTOs.swift` (`WalletDTO`, `PlantDTO`, `PlantStageDTO`,
 * `GardenResponseDTO`, `AwardOutcomeDTO`, `PlantProgressDTO`, …) and checked
 * against what `deep-api/src/lib/serialize.ts` actually writes
 * (`serializeWallet`, `serializePlant`, `serializePlantStage`,
 * `serializeGarden`, `serializeAwardOutcome`) and `rewardPayload.ts`
 * (`{ wallet, plant }`, the tail every award-bearing route shares).
 *
 * Tolerant by construction, as the Swift DTOs are: every field the app can
 * live without is optional here and defaulted in the mapping, so a server that
 * drops or adds a column never fails a fetch. The one exception is
 * [WalletDto.heartsBalance] — iOS requires it too, and a wallet without a
 * balance defaulted to 0 would silently zero the member's hearts on screen.
 */

// MARK: - Wallet

/** The wallet as `serializeWallet` writes it. */
@Serializable
data class WalletDto(
  val heartsBalance: Int,
  val heartsEarned: Int? = null,
  val heartsGiven: Int? = null,
  val earnedToday: Int? = null,
  val remainingToday: Int? = null,
  val dailyCap: Int? = null,
  val givenByCategory: Map<String, Int>? = null,
)

/** `GET /me/wallet`. */
@Serializable
data class WalletResponseDto(
  val wallet: WalletDto,
)

/** `POST /me/hearts/spend` body. [id] is the client's idempotency UUID. */
@Serializable
data class SpendHeartsRequest(
  val id: String,
  val amount: Int,
  val category: String,
  // Omitted rather than sent as `null` when absent (DeepJson's
  // explicitNulls = false): zod's `.optional()` refuses an explicit null.
  val projectId: String? = null,
)

/** `POST /me/hearts/spend` — the recorded spend is not read; the wallet is. */
@Serializable
data class SpendResponseDto(
  val wallet: WalletDto,
)

// MARK: - Plants and the garden

/** One form on a plant's ladder, as `serializePlantStage` writes it. */
@Serializable
data class PlantStageDto(
  val id: String,
  val plantId: String? = null,
  val name: String,
  val displayOrder: Int = 0,
  val sunlightRequired: Int = 0,
  val mascotUrl: String? = null,
  val mascotBgUrl: String? = null,
  val heroVideoUrl: String? = null,
)

/**
 * A plant, as `serializePlant` writes it. [stages] is present on the catalog
 * (`serializePlantWithStages`) and absent on the garden's `selectedPlant`,
 * whose ladder rides beside it as [GardenDto.stages].
 */
@Serializable
data class PlantDto(
  val id: String,
  val name: String,
  val tagline: String? = null,
  val imageUrl: String? = null,
  val palette: String? = null,
  val displayOrder: Int = 0,
  val isPremium: Boolean = false,
  val isDefault: Boolean = false,
  val isActive: Boolean = true,
  val stages: List<PlantStageDto>? = null,
)

/** `GET /garden/plants` — active, non-premium plants with their stages. */
@Serializable
data class PlantsResponseDto(
  val plants: List<PlantDto> = emptyList(),
)

/** The `garden` half of `/me/garden`, as `serializeGarden` writes it. */
@Serializable
data class GardenDto(
  val selectedPlant: PlantDto? = null,
  val sunlight: Int = 0,
  val currentStageIndex: Int? = null,
  val stages: List<PlantStageDto>? = null,
  val sunlightByPlant: Map<String, Int> = emptyMap(),
)

/**
 * `GET /me/garden` and `PUT /me/garden/plant`. [garden] is null when the
 * catalog has no eligible plant at all (`gardenPayload` in `routes/garden.ts`).
 */
@Serializable
data class GardenResponseDto(
  val garden: GardenDto? = null,
  val wallet: WalletDto? = null,
)

/** `PUT /me/garden/plant` body. */
@Serializable
data class SelectPlantRequest(
  val plantId: String,
)

// MARK: - Awards

/** One award decision, as `serializeAwardOutcome` writes it. */
@Serializable
data class AwardOutcomeDto(
  val kind: String? = null,
  val granted: Boolean? = null,
  val heartsGranted: Int? = null,
  val sunlightGranted: Int? = null,
  val plantId: String? = null,
  val cappedBy: String? = null,
)

/** The selected plant after an award (`plantSnapshot` in `rewardPayload.ts`). */
@Serializable
data class PlantProgressDto(
  val plantId: String,
  val sunlight: Int = 0,
  val currentStageIndex: Int? = null,
)

/**
 * A single-award response — `POST /me/sound/listens` today, and the pause
 * claim when it lands: the outcome plus the shared `{ wallet, plant }` tail.
 */
@Serializable
data class AwardResponseDto(
  val award: AwardOutcomeDto? = null,
  val wallet: WalletDto? = null,
  val plant: PlantProgressDto? = null,
)

// MARK: - Mapping down to :core:model

/** Ported from `HeartsSummary(dto:)`: absent figures read 0, an absent cap the rule's. */
fun WalletDto.toDomain(): WalletSummary = WalletSummary(
  heartsBalance = heartsBalance,
  heartsEarned = heartsEarned ?: 0,
  heartsGiven = heartsGiven ?: 0,
  earnedToday = earnedToday ?: 0,
  remainingToday = remainingToday ?: 0,
  dailyCap = dailyCap ?: RewardRules.dailyHeartsCap,
  givenByCategory = givenByCategory ?: emptyMap(),
)

/** Ported from `PlantStage(dto:)`: the server's `sunlightRequired` is the cumulative threshold. */
fun PlantStageDto.toDomain(): PlantStage = PlantStage(
  id = id,
  name = name,
  threshold = sunlightRequired,
  mascotUrl = mascotUrl,
  mascotBgUrl = mascotBgUrl,
  heroVideoUrl = heroVideoUrl,
)

/**
 * Ported from `Plant(dto:stages:)`. The ladder is taken from the plant itself
 * when it carries one, else from [siblingStages] (the garden's), and is
 * re-sorted by `displayOrder` here rather than trusted to arrive in order —
 * `GardenGrowth` reads the list as the evolution order.
 */
fun PlantDto.toDomain(siblingStages: List<PlantStageDto>? = null): Plant = Plant(
  id = id,
  name = name,
  tagline = tagline ?: "",
  imageUrl = imageUrl,
  palette = palette ?: Plant.DEFAULT_PALETTE,
  stages = (stages ?: siblingStages ?: emptyList())
    .sortedBy { it.displayOrder }
    .map { it.toDomain() },
)

/** The picker catalog, in the admin's display order. */
fun PlantsResponseDto.toDomain(): List<Plant> =
  plants.sortedBy { it.displayOrder }.map { it.toDomain() }

/**
 * Ported from `GardenSnapshot(dto:)`, with the nullable plot core's
 * [GardenSnapshot] documents: no garden, or a garden with no selected plant,
 * still hands its wallet on.
 */
fun GardenResponseDto.toDomain(): GardenSnapshot = GardenSnapshot(
  plot = garden?.let { garden ->
    garden.selectedPlant?.let { plant ->
      GardenPlot(
        plant = plant.toDomain(siblingStages = garden.stages),
        sunlight = garden.sunlight,
        sunlightByPlant = garden.sunlightByPlant,
      )
    }
  },
  wallet = wallet?.toDomain(),
)

/** Unknown kinds and cap reasons from a newer server read as null, never a failure. */
fun AwardOutcomeDto.toDomain(): AwardOutcome = AwardOutcome(
  kind = AwardKind.fromWire(kind),
  granted = granted == true,
  heartsGranted = heartsGranted ?: 0,
  sunlightGranted = sunlightGranted ?: 0,
  plantId = plantId,
  cappedBy = AwardCap.fromWire(cappedBy),
)

fun PlantProgressDto.toDomain(): PlantProgress = PlantProgress(
  plantId = plantId,
  sunlight = sunlight,
  currentStageIndex = currentStageIndex,
)

/**
 * The one fold every award-bearing response goes through — practice sync,
 * track listens, and the pause claim to come — so the wire trio always
 * becomes a grant the same way (`AwardGrant(outcomes:wallet:plant:)` on iOS).
 */
fun foldAwards(
  outcomes: List<AwardOutcomeDto>,
  wallet: WalletDto?,
  plant: PlantProgressDto?,
): AwardGrant? = AwardGrant.fold(
  outcomes = outcomes.map { it.toDomain() },
  wallet = wallet?.toDomain(),
  plant = plant?.toDomain(),
)

/** A single-award response folded into its grant; null when it carried nothing. */
fun AwardResponseDto.toGrant(): AwardGrant? = foldAwards(listOfNotNull(award), wallet, plant)
