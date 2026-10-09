package io.appbeyond.freelance.deep.feature.mindgarden.store

import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenSnapshot
import io.appbeyond.freelance.deep.feature.mindgarden.model.Plant
import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import io.appbeyond.freelance.deep.feature.rewards.model.WalletSummary
import io.appbeyond.freelance.deep.feature.rewards.store.GatedRewardsRemote
import io.appbeyond.freelance.deep.feature.rewards.store.MockRewardsRemote
import io.appbeyond.freelance.deep.feature.rewards.store.RewardsRemote
import io.appbeyond.freelance.deep.shared.persistence.BlobStoring
import io.appbeyond.freelance.deep.shared.persistence.GatedBlobStore
import io.appbeyond.freelance.deep.shared.persistence.InMemoryBlobStore
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Ported from Deep/DeepTests/GardenStoreTests.swift, plus the Android-only
 * behaviour: a garden-less snapshot, the visible catalog failure, and
 * responses that land after a sign-out.
 *
 * The garden store's contract: server refresh adopts and persists, awards
 * reconcile by absolute set, plant switches are optimistic with a revert, and
 * the wallet riding the garden fetch reaches the hearts sink.
 */
@OptIn(ExperimentalCoroutinesApi::class) // runCurrent, to park a response mid-flight.
class GardenStoreTest {

  private fun store(remote: RewardsRemote = MockRewardsRemote(), blob: BlobStoring = InMemoryBlobStore()) =
    GardenStore(remote = remote, blob = blob)

  // MARK: - Refresh & persistence

  @Test
  @DisplayName("Refresh adopts the server snapshot and persists it for a cold launch")
  fun refreshAdoptsAndPersists() = runTest {
    val blob = InMemoryBlobStore()
    val remote = MockRewardsRemote(sunlightByPlant = mapOf(Plant.oakFixture.id to 260))
    val store = store(remote, blob)
    assertNull(store.state.value.growth) // Nothing persisted yet.

    store.refresh()
    assertEquals("oak", store.state.value.plant?.id)
    assertEquals(260, store.state.value.sunlight)
    assertEquals(1, store.state.value.growth?.stageIndex)

    // A second instance on the same blob renders offline from it.
    val cold = store(MockRewardsRemote(), blob)
    cold.restore()
    assertEquals("oak", cold.state.value.plant?.id)
    assertEquals(260, cold.state.value.sunlight)
    assertEquals(Plant.oakFixture, cold.state.value.plant, "The whole stage ladder survives the blob.")
  }

  @Test
  @DisplayName("A failed refresh keeps the persisted snapshot untouched")
  fun failedRefreshKeepsSnapshot() = runTest {
    val remote = MockRewardsRemote()
    val store = store(remote)
    store.refresh()

    remote.failsGarden = true
    remote.sunlightByPlant = mapOf(Plant.oakFixture.id to 9_999)
    store.refresh()

    assertEquals(240, store.state.value.sunlight)
    assertFalse(store.state.value.isRefreshing)
  }

  @Test
  @DisplayName("The wallet riding the garden fetch reaches the hearts sink")
  fun refreshForwardsWallet() = runTest {
    val store = store()
    val received = mutableListOf<WalletSummary>()
    store.heartsChanged = { received += it }

    store.refresh()
    assertEquals(listOf(WalletSummary.sample), received)
  }

  @Test
  @DisplayName("A snapshot with no garden leaves the garden alone but still forwards the wallet")
  fun nullGardenKeepsWallet() = runTest {
    val remote = object : RewardsRemote by MockRewardsRemote() {
      override suspend fun garden() = GardenSnapshot(plot = null, wallet = WalletSummary.fresh)
    }
    val store = store(remote)
    store.seed(plant = Plant.oakFixture, sunlight = 240)
    val received = mutableListOf<WalletSummary>()
    store.heartsChanged = { received += it }

    store.refresh()

    assertEquals("oak", store.state.value.plant?.id)
    assertEquals(240, store.state.value.sunlight)
    assertEquals(listOf(WalletSummary.fresh), received)
  }

  @Test
  @DisplayName("The persisted blob is the plant, its sunlight and the per-plant tallies")
  fun blobShape() = runTest {
    val blob = InMemoryBlobStore()
    store(MockRewardsRemote(sunlightByPlant = mapOf("oak" to 260, "sakura" to 12)), blob).refresh()

    val json = assertNotNull(blob.value)
    assertTrue(json.startsWith("{\"plant\":{\"id\":\"oak\""), json)
    assertTrue(json.contains("\"sunlight\":260"), json)
    assertTrue(json.contains("\"sunlightByPlant\":{\"oak\":260,\"sakura\":12}"), json)
  }

  // MARK: - Awards

  @Test
  @DisplayName("Applying a grant with an absolute reconciles an optimistic tick, never doubles it")
  fun applyReconcilesAbsolutes() = runTest {
    val store = store()
    store.seed(plant = Plant.oakFixture, sunlight = 240)

    assertEquals(1, store.creditSunlight(1)) // The completion beat's optimistic tick.
    assertEquals(241, store.state.value.sunlight)

    store.apply(AwardGrant(hearts = 1, sunlight = 1, plantId = "oak", plantSunlight = 241))
    assertEquals(241, store.state.value.sunlight)
    assertEquals(241, store.state.value.sunlightByPlant["oak"])
  }

  @Test
  @DisplayName("A grant for an unselected plant only moves that plant's tally")
  fun applyToUnselectedPlant() = runTest {
    val store = store()
    store.seed(plant = Plant.oakFixture, sunlight = 240)

    store.apply(AwardGrant(hearts = 1, sunlight = 1, plantId = "sakura", plantSunlight = 12))

    assertEquals(240, store.state.value.sunlight)
    assertEquals(12, store.state.value.sunlightByPlant["sakura"])
  }

  @Test
  @DisplayName("A grant without an absolute falls back to its delta")
  fun applyDeltaFallback() = runTest {
    val store = store()
    store.seed(plant = Plant.oakFixture, sunlight = 240)

    store.apply(AwardGrant(hearts = 5, sunlight = 5, plantId = "oak"))
    store.apply(AwardGrant(hearts = 1, sunlight = 1, plantId = "lotus"))

    assertEquals(245, store.state.value.sunlight)
    assertEquals(245, store.state.value.sunlightByPlant["oak"])
    assertEquals(1, store.state.value.sunlightByPlant["lotus"])
  }

  @Test
  @DisplayName("Credit without a plant is a quiet no-op")
  fun creditWithoutPlant() = runTest {
    val store = store()
    assertEquals(0, store.creditSunlight(1))
    assertEquals(0, store.state.value.sunlight)
  }

  // MARK: - Plant switching

  @Test
  @DisplayName("Switching plants adopts immediately and resumes the new plant's sunlight")
  fun selectPlantOptimistic() = runTest {
    val remote = MockRewardsRemote(
      sunlightByPlant = mapOf(Plant.oakFixture.id to 240, Plant.sakuraFixture.id to 90),
    )
    val store = store(remote)
    store.refresh()

    store.selectPlant(Plant.sakuraFixture)
    assertEquals("sakura", store.state.value.plant?.id)
    assertEquals(90, store.state.value.sunlight)
    assertFalse(store.state.value.switchFailed)
    assertEquals("sakura", remote.selectedPlantId)
  }

  @Test
  @DisplayName("A refused switch reverts to the previous plant with a quiet caption")
  fun selectPlantReverts() = runTest {
    val remote = MockRewardsRemote()
    val store = store(remote)
    store.refresh()

    remote.failsSelectPlant = true
    store.selectPlant(Plant.sakuraFixture)

    assertEquals("oak", store.state.value.plant?.id)
    assertEquals(240, store.state.value.sunlight)
    assertTrue(store.state.value.switchFailed)
  }

  @Test
  @DisplayName("The optimistic switch shows before the server answers")
  fun selectPlantIsOptimistic() = runTest {
    val remote = GatedRewardsRemote(MockRewardsRemote(sunlightByPlant = mapOf("oak" to 240, "sakura" to 90)))
    val store = store(remote)
    store.seed(plant = Plant.oakFixture, sunlight = 240, sunlightByPlant = mapOf("oak" to 240, "sakura" to 90))

    val switching = launch { store.selectPlant(Plant.sakuraFixture) }
    runCurrent()
    assertEquals("sakura", store.state.value.plant?.id)
    assertEquals(90, store.state.value.sunlight)

    remote.gate.complete(Unit)
    switching.join()
    assertEquals("sakura", store.state.value.plant?.id)
  }

  // MARK: - Catalog

  @Test
  @DisplayName("A failed catalog load is a visible failure the picker can retry")
  fun catalogFailureIsRetryable() = runTest {
    val remote = MockRewardsRemote()
    remote.failsPlants = true
    val store = store(remote)

    store.loadCatalogIfNeeded()
    assertEquals(GardenStore.PlantCatalog.Failed, store.state.value.catalog)

    remote.failsPlants = false
    store.retryCatalog()
    val loaded = assertIs<GardenStore.PlantCatalog.Loaded>(store.state.value.catalog)
    assertEquals(Plant.fixtures, loaded.plants)
  }

  @Test
  @DisplayName("A loaded catalog is not fetched again, and survives a sign-out")
  fun catalogLoadsOnce() = runTest {
    val remote = MockRewardsRemote()
    val store = store(remote)
    store.loadCatalogIfNeeded()

    remote.failsPlants = true
    store.loadCatalogIfNeeded()
    store.resetLocalState()

    assertEquals(Plant.fixtures, store.state.value.catalog.plants)
  }

  // MARK: - Sign-out

  @Test
  @DisplayName("Signing out forgets the garden and its blob")
  fun resetForgetsGarden() = runTest {
    val blob = InMemoryBlobStore()
    val store = store(blob = blob)
    store.refresh()

    store.resetLocalState()

    assertNull(store.state.value.plant)
    assertEquals(0, store.state.value.sunlight)
    assertTrue(store.state.value.sunlightByPlant.isEmpty())
    assertNull(blob.value)
  }

  @Test
  @DisplayName("A garden fetch that lands after sign-out is dropped, wallet included")
  fun lateRefreshAfterResetIsDropped() = runTest {
    val blob = InMemoryBlobStore()
    val remote = GatedRewardsRemote()
    val store = store(remote, blob)
    val received = mutableListOf<WalletSummary>()
    store.heartsChanged = { received += it }

    val refreshing = launch { store.refresh() }
    runCurrent()
    assertTrue(store.state.value.isRefreshing)

    store.resetLocalState()
    assertFalse(store.state.value.isRefreshing, "The next account may refresh straight away.")
    remote.gate.complete(Unit)
    refreshing.join()

    assertNull(store.state.value.plant)
    assertTrue(received.isEmpty())
    assertNull(blob.value)
  }

  @Test
  @DisplayName("A plant switch that settles after sign-out neither adopts nor reverts")
  fun lateSwitchAfterResetIsDropped() = runTest {
    val remote = GatedRewardsRemote()
    remote.delegate.failsSelectPlant = true
    val store = store(remote)
    store.seed(plant = Plant.oakFixture, sunlight = 240)

    val switching = launch { store.selectPlant(Plant.sakuraFixture) }
    runCurrent()
    store.resetLocalState()
    remote.gate.complete(Unit)
    switching.join()

    assertNull(store.state.value.plant)
    assertFalse(store.state.value.switchFailed)
  }

  // MARK: - Races (peer review)

  @Test
  @DisplayName("A sign-out while the fetched garden is being written keeps the stale wallet out")
  fun resetDuringAdoptPersistDropsWallet() = runTest {
    val blob = GatedBlobStore()
    val store = store(MockRewardsRemote(), blob)
    store.restore()
    val received = mutableListOf<WalletSummary>()
    store.heartsChanged = { received += it }
    blob.armed = true

    val refreshing = launch { store.refresh() }
    runCurrent() // Parked writing the adopted garden.
    val resetting = launch { store.resetLocalState() }
    runCurrent()
    blob.gate.complete(Unit)
    refreshing.join()
    resetting.join()

    assertTrue(received.isEmpty())
    assertNull(store.state.value.plant)
    assertNull(blob.value)
  }

  @Test
  @DisplayName("A refused switch keeps an award applied while it was in flight")
  fun refusedSwitchKeepsConcurrentAward() = runTest {
    val remote = GatedRewardsRemote()
    remote.delegate.failsSelectPlant = true
    val store = store(remote)
    store.seed(plant = Plant.oakFixture, sunlight = 240)

    val switching = launch { store.selectPlant(Plant.sakuraFixture) }
    runCurrent()
    store.apply(AwardGrant(hearts = 1, sunlight = 1, plantId = "oak", plantSunlight = 250))
    remote.gate.complete(Unit)
    switching.join()

    assertEquals("oak", store.state.value.plant?.id)
    assertEquals(250, store.state.value.sunlight)
    assertTrue(store.state.value.switchFailed)
  }

  @Test
  @DisplayName("Two refused switches in a row land back on the confirmed plant")
  fun chainedRefusalsRevertToConfirmedPlant() = runTest {
    val remote = GatedRewardsRemote()
    remote.delegate.failsSelectPlant = true
    val store = store(remote)
    store.seed(plant = Plant.oakFixture, sunlight = 240)

    val first = launch { store.selectPlant(Plant.sakuraFixture) }
    runCurrent()
    val second = launch { store.selectPlant(Plant.lotusFixture) }
    runCurrent()
    assertEquals("lotus", store.state.value.plant?.id)
    remote.gate.complete(Unit)
    first.join()
    second.join()

    assertEquals("oak", store.state.value.plant?.id)
    assertEquals(240, store.state.value.sunlight)
  }

  @Test
  @DisplayName("A switch cancelled while saving its optimistic choice still reaches the server")
  fun cancelledSwitchStillSettles() = runTest {
    val remote = MockRewardsRemote(sunlightByPlant = mapOf("oak" to 240, "sakura" to 90))
    val blob = GatedBlobStore()
    val store = store(remote, blob)
    store.seed(plant = Plant.oakFixture, sunlight = 240, sunlightByPlant = mapOf("oak" to 240, "sakura" to 90))
    blob.armed = true

    val switching = launch { store.selectPlant(Plant.sakuraFixture) }
    runCurrent() // Parked persisting the optimistic switch.
    switching.cancel()
    blob.gate.complete(Unit)
    switching.join()

    assertEquals("sakura", remote.selectedPlantId)
    assertEquals("sakura", store.state.value.plant?.id)
    assertFalse(store.state.value.switchFailed)
  }
}
