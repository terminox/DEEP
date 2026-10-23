package io.appbeyond.freelance.deep.networking

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.PUT

/**
 * Hearts, sunlight and the plant catalog (`routes/garden.ts`,
 * `routes/hearts.ts`). Paths are relative — see [PauseHomeService] for why.
 *
 * Every `/me/…` route keys "today" to the member's local day, which the one
 * shared client stamps on as `X-Device-Timezone`; that is why this rides the
 * shared Retrofit rather than a client of its own.
 */
interface RewardsService {

  /** Auth required. The selected plant at its earned stage, plus the wallet. */
  @GET("me/garden")
  suspend fun garden(): GardenResponseDto

  /** Anonymous. Published, non-premium plants with their stage ladders. */
  @GET("garden/plants")
  suspend fun plants(): PlantsResponseDto

  /** 404 `plant_not_found`, 403 `premium_locked`; otherwise the same body as [garden]. */
  @PUT("me/garden/plant")
  suspend fun selectPlant(@Body body: SelectPlantRequest): GardenResponseDto

  @GET("me/wallet")
  suspend fun wallet(): WalletResponseDto

  /** Idempotent by [SpendHeartsRequest.id]; 409 `insufficient_hearts` when the balance is short. */
  @POST("me/hearts/spend")
  suspend fun spend(@Body body: SpendHeartsRequest): SpendResponseDto
}
