package io.appbeyond.freelance.deep.feature.mindgarden.store

import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenGrowth
import io.appbeyond.freelance.deep.feature.mindgarden.model.GardenSnapshot
import io.appbeyond.freelance.deep.feature.mindgarden.model.Plant
import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import io.appbeyond.freelance.deep.feature.rewards.model.WalletSummary
import io.appbeyond.freelance.deep.feature.rewards.store.RewardsRemote
import io.appbeyond.freelance.deep.shared.persistence.BlobStoring
import io.appbeyond.freelance.deep.shared.persistence.StoreJson
import io.appbeyond.freelance.deep.shared.persistence.readOrNull
import io.appbeyond.freelance.deep.shared.persistence.writeQuietly
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable

/**
 * The garden's single source of truth: the selected plant, its banked
 * sunlight, the per-plant tallies behind the picker, and the catalog. Server
 * truth arrives through [refresh] / [apply]; optimistic credits keep the UI
 * instant and are reconciled by the next absolute figure, never double-counted.
 *
 * Ported from Deep/Deep/Features/MindGarden/Store/GardenStore.swift. The
 * snapshot persists as one JSON blob, so an offline cold launch still renders
 * the last known garden:
 *
 * ```
 * {"plant":{"id":"oak","name":"Oak","tagline":"…","palette":"mist",
 *   "stages":[{"id":"oak-stage-0","name":"Oak Seedling","threshold":0},…]},
 *  "sunlight":240,"sunlightByPlant":{"oak":240}}
 * ```
 *
 * Null fields (an absent `imageUrl`, `mascotUrl`, …, or `plant` before the
 * first snapshot) are omitted rather than written as `null`.
 *
 * Everything observable is one immutable [State] on one [StateFlow], so the
 * plant and its sunlight can never be seen out of step. Differences from iOS:
 *
 * - DIVERGENCE: the catalog load is a visible [PlantCatalog] state with a
 *   [PlantCatalog.Failed] the picker can retry ([retryCatalog]), not an
 *   endless skeleton.
 * - DIVERGENCE: a snapshot with no garden (`garden: null`) leaves the garden
 *   untouched but still forwards its wallet to [heartsChanged].
 * - Every async call is stamped with a generation; one that lands after
 *   [resetLocalState] is dropped, so a previous account's garden or wallet
 *   can never reappear for the next one. (iOS relies on `@MainActor` ordering
 *   and has no such guard.)
 * - A refused plant switch reverts to the last server-confirmed plant rather
 *   than the immediately previous one, and a switch superseded by a newer one
 *   leaves the outcome to that newer switch — so rapid taps can't strand a
 *   refused plant on screen. (iOS reverts to the captured previous plant.)
 * - Committed mutations are persisted non-cancellably.
 * - The persisted blob is read on first use ([restore]) rather than in the
 *   constructor; every suspending member restores first.
 */
class GardenStore(
  private val remote: RewardsRemote,
  private val blob: BlobStoring,
) {

  /** Where the picker catalog is. App content, not user state. */
  sealed interface PlantCatalog {
    /** Not asked for yet. */
    data object Idle : PlantCatalog

    data object Loading : PlantCatalog

    /** The last load failed — the picker shows a retry. */
    data object Failed : PlantCatalog

    data class Loaded(override val plants: List<Plant>) : PlantCatalog

    /** The plants, when loaded; empty otherwise. */
    val plants: List<Plant> get() = emptyList()
  }

  data class State(
    /** The selected plant with its stage ladder; null until the first
     * snapshot (server or persisted) lands. */
    val plant: Plant? = null,
    /** Sunlight banked into the selected plant, cumulative over its life. */
    val sunlight: Int = 0,
    /** Lifetime sunlight per plant id — unselected plants keep theirs. */
    val sunlightByPlant: Map<String, Int> = emptyMap(),
    val catalog: PlantCatalog = PlantCatalog.Idle,
    val isRefreshing: Boolean = false,
    /** Set when a plant switch was rolled back — the picker shows its quiet
     * caption (the words live with the UI so they can be translated). Cleared
     * on the next attempt. */
    val switchFailed: Boolean = false,
  ) {
    /** The derivation everything renders from; null until a plant is known. */
    val growth: GardenGrowth? get() = plant?.let { GardenGrowth(plant = it, sunlight = sunlight) }
  }

  /** The persisted shape — everything an offline launch needs to draw. */
  @Serializable
  private data class Blob(
    val plant: Plant? = null,
    val sunlight: Int = 0,
    val sunlightByPlant: Map<String, Int> = emptyMap(),
  )

  private val _state = MutableStateFlow(State())

  val state: StateFlow<State> = _state.asStateFlow()

  /**
   * Wallet snapshots ride the garden fetch; the app points this at
   * `HeartLedger.hydrate` so one fetch hydrates both stores.
   */
  @Volatile
  var heartsChanged: (suspend (WalletSummary) -> Unit)? = null

  /** Guards every write to [_state], [generation] and [touched]. Never held
   * across a suspension. */
  private val lock = Any()

  /** Bumped by [resetLocalState]; async work captures it and drops its
   * result when it has moved. */
  private var generation = 0L

  /** Set by any mutation, so a late [restore] never overwrites newer state. */
  private var touched = false

  /** Bumped by every optimistic [selectPlant]; a switch that settles after a
   * newer one started neither adopts its plant nor rolls back. */
  private var selection = 0L

  /** The plant the server last confirmed (or the blob/seed held) — what a
   * refused switch falls back to, so a chain of refused switches can never
   * leave a refused plant on screen. */
  private var confirmedPlant: Plant? = null

  private val restoreLock = Mutex()

  @Volatile
  private var restored = false

  /** Serialises blob writes; each write encodes the state current at that
   * moment, so the last write is always the newest state. */
  private val persistLock = Mutex()

  // MARK: - Persistence

  /**
   * Adopts the persisted snapshot, once. Every suspending member calls this
   * first; calling it eagerly at launch just warms the garden before the
   * first refresh.
   */
  suspend fun restore() {
    if (restored) return
    restoreLock.withLock {
      if (restored) return
      val stored = blob.readOrNull()?.let { json ->
        runCatching { StoreJson.decodeFromString(Blob.serializer(), json) }.getOrNull()
      }
      synchronized(lock) {
        if (stored != null && !touched) {
          confirmedPlant = stored.plant
          _state.update {
            it.copy(plant = stored.plant, sunlight = stored.sunlight, sunlightByPlant = stored.sunlightByPlant)
          }
        }
      }
      restored = true
    }
  }

  // MARK: - Server truth

  /**
   * Pulls the garden (and the wallet riding it). A call while one is already
   * in flight is a no-op. Errors are swallowed — the persisted snapshot is
   * already on screen and the next refresh retries.
   */
  suspend fun refresh() {
    restore()
    val started = synchronized(lock) {
      if (_state.value.isRefreshing) {
        null
      } else {
        _state.update { it.copy(isRefreshing = true) }
        generation
      }
    } ?: return

    try {
      val snapshot = try {
        remote.garden()
      } catch (cancelled: CancellationException) {
        throw cancelled
      } catch (_: Exception) {
        null
      }
      if (snapshot != null) adopt(snapshot, started)
    } finally {
      synchronized(lock) {
        if (generation == started) _state.update { it.copy(isRefreshing = false) }
      }
    }
  }

  /** Fetches the picker catalog unless it is loading or already loaded. */
  suspend fun loadCatalogIfNeeded() = loadCatalog(force = false)

  /** Loads the catalog again after a [PlantCatalog.Failed]. */
  suspend fun retryCatalog() = loadCatalog(force = true)

  /**
   * Switches the selected plant — optimistically, resumed at whatever
   * sunlight it had already earned, reverted with a quiet caption if the
   * server refuses.
   *
   * Once the optimistic switch has played, its persistence, the request and
   * the settlement all run to completion even if the caller is cancelled, so
   * a switch is always either confirmed or reverted. A refusal reverts to the
   * last server-confirmed plant, reading its sunlight from the current tallies
   * (so an award applied meanwhile is kept) — and only if no newer switch or
   * sign-out happened since; a superseded switch leaves the outcome to the
   * newer one.
   */
  suspend fun selectPlant(newPlant: Plant) {
    restore()
    val switch = synchronized(lock) {
      val current = _state.value
      if (newPlant.id == current.plant?.id) return
      touched = true
      selection++
      _state.update {
        it.copy(plant = newPlant, sunlight = it.sunlightByPlant[newPlant.id] ?: 0, switchFailed = false)
      }
      PendingSwitch(generation, selection)
    }

    withContext(NonCancellable) {
      persist()
      val snapshot = try {
        remote.selectPlant(newPlant.id)
      } catch (_: Exception) {
        null
      }
      if (snapshot != null) {
        adopt(snapshot, switch.generation, switch.selection)
        return@withContext
      }
      val reverted = synchronized(lock) {
        if (generation != switch.generation || selection != switch.selection) return@synchronized false
        val fallback = confirmedPlant
        _state.update {
          it.copy(
            plant = fallback,
            sunlight = fallback?.let { plant -> it.sunlightByPlant[plant.id] } ?: 0,
            switchFailed = true,
          )
        }
        true
      }
      if (reverted) persist()
    }
  }

  // MARK: - Awards

  /**
   * Applies a settled award: an absolute SETS the plant's tally, so the
   * optimistic tick is reconciled rather than double-counted. The delta is
   * only a fallback for responses that carried no snapshot. An award for an
   * unselected plant moves only that plant's tally.
   */
  suspend fun apply(grant: AwardGrant) {
    restore()
    val plantId = grant.plantId ?: return
    val absolute = grant.plantSunlight
    if (absolute == null && grant.sunlight <= 0) return
    synchronized(lock) {
      touched = true
      _state.update { state ->
        val selected = plantId == state.plant?.id
        if (absolute != null) {
          state.copy(
            sunlightByPlant = state.sunlightByPlant + (plantId to absolute),
            sunlight = if (selected) absolute else state.sunlight,
          )
        } else {
          state.copy(
            sunlightByPlant = state.sunlightByPlant +
              (plantId to (state.sunlightByPlant[plantId] ?: 0) + grant.sunlight),
            sunlight = if (selected) state.sunlight + grant.sunlight else state.sunlight,
          )
        }
      }
    }
    persist()
  }

  /**
   * Optimistic credit the moment a practice completes — the halo ticks
   * instantly; the practice sync's absolute figures reconcile it.
   *
   * @return the sunlight actually credited: 0 without a plant, or for a
   *   non-positive [amount].
   */
  suspend fun creditSunlight(amount: Int = 1): Int {
    restore()
    val credited = synchronized(lock) {
      val plant = _state.value.plant
      if (amount <= 0 || plant == null) return@synchronized 0
      touched = true
      _state.update {
        it.copy(
          sunlight = it.sunlight + amount,
          sunlightByPlant = it.sunlightByPlant + (plant.id to (it.sunlightByPlant[plant.id] ?: 0) + amount),
        )
      }
      amount
    }
    if (credited > 0) persist()
    return credited
  }

  /**
   * Forgets everything tied to the signed-out account — the persisted blob
   * included — so the next account opens on the loading skeleton, never a
   * previous user's garden. The catalog stays: it is app content, not user
   * state. Anything still in flight for the old account is dropped when it
   * lands.
   */
  suspend fun resetLocalState() {
    restore()
    synchronized(lock) {
      generation++
      touched = true
      confirmedPlant = null
      _state.update { State(catalog = it.catalog) }
    }
    withContext(NonCancellable) { persistLock.withLock { blob.writeQuietly(null) } }
  }

  // MARK: - Fixtures

  /**
   * Preloads a snapshot without touching the remote or the blob — previews and
   * tests seed known states through this.
   */
  fun seed(plant: Plant?, sunlight: Int, sunlightByPlant: Map<String, Int> = emptyMap()) {
    synchronized(lock) {
      touched = true
      confirmedPlant = plant
      _state.update {
        it.copy(
          plant = plant,
          sunlight = sunlight,
          sunlightByPlant = sunlightByPlant.ifEmpty { plant?.let { p -> mapOf(p.id to sunlight) } ?: emptyMap() },
        )
      }
    }
  }

  // MARK: - Internals

  private class PendingSwitch(val generation: Long, val selection: Long)

  private suspend fun loadCatalog(force: Boolean) {
    val start = synchronized(lock) {
      val catalog = _state.value.catalog
      val settled = catalog is PlantCatalog.Loaded && catalog.plants.isNotEmpty()
      if (catalog is PlantCatalog.Loading || (!force && settled)) return@synchronized false
      _state.update { it.copy(catalog = PlantCatalog.Loading) }
      true
    }
    if (!start) return

    val outcome = try {
      PlantCatalog.Loaded(remote.plants())
    } catch (cancelled: CancellationException) {
      synchronized(lock) { _state.update { it.copy(catalog = PlantCatalog.Idle) } }
      throw cancelled
    } catch (_: Exception) {
      PlantCatalog.Failed
    }
    synchronized(lock) { _state.update { it.copy(catalog = outcome) } }
  }

  /**
   * Adopts a server snapshot taken under [stamp]: the garden when there is
   * one, then the wallet riding it. Both are dropped if the store was reset
   * since — checked again after every suspension, so a reset that lands while
   * the garden is being written still keeps the stale wallet out.
   *
   * A plant-switch response passes its [selectionStamp]: if a newer switch
   * has started since, its plot only becomes the confirmed fallback and the
   * screen keeps showing the newer optimistic choice.
   */
  private suspend fun adopt(snapshot: GardenSnapshot, stamp: Long, selectionStamp: Long? = null) {
    val plot = snapshot.plot
    val adopted = synchronized(lock) {
      if (generation != stamp) return
      if (plot == null) return@synchronized false
      confirmedPlant = plot.plant
      if (selectionStamp != null && selection != selectionStamp) return@synchronized false
      touched = true
      _state.update {
        it.copy(plant = plot.plant, sunlight = plot.sunlight, sunlightByPlant = plot.sunlightByPlant)
      }
      true
    }
    if (adopted) persist()
    val wallet = snapshot.wallet ?: return
    if (synchronized(lock) { generation != stamp }) return
    heartsChanged?.invoke(wallet)
  }

  /**
   * Writes the state current at that moment. Non-cancellable: a mutation that
   * has been committed to memory is always committed to disk too.
   */
  private suspend fun persist() = withContext(NonCancellable) {
    persistLock.withLock {
      val state = _state.value
      val json = StoreJson.encodeToString(
        Blob.serializer(),
        Blob(plant = state.plant, sunlight = state.sunlight, sunlightByPlant = state.sunlightByPlant),
      )
      blob.writeQuietly(json)
    }
  }
}
