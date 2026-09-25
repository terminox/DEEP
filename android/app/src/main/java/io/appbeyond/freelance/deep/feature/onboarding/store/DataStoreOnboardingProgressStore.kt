package io.appbeyond.freelance.deep.feature.onboarding.store

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import io.appbeyond.freelance.deep.networking.DeepJson
import io.appbeyond.freelance.deep.onboarding.model.OnboardingState
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import java.io.IOException

/**
 * [OnboardingProgressStore] backed by a single JSON blob in Preferences
 * DataStore — the Android twin of `OnboardingProgressDefaultsStore.swift`.
 *
 * The whole [OnboardingState] is re-encoded under one key on every mutation,
 * so there are no per-field keys to keep in sync and a partially-completed
 * flow survives relaunch. A corrupt or pre-week-2 blob decodes to
 * [OnboardingState.Fresh] rather than failing the launch — the flow is
 * replayable, so the cost of losing a saved blob is a re-answered quiz, not a
 * crash.
 *
 * **Loading is eager, not synchronous.** [state] starts at
 * [OnboardingState.Fresh] the instant this is constructed — screens can
 * `collectAsState()` it immediately — and is corrected on [scope] once the
 * real DataStore read lands, exactly as an ordinary state update. That is
 * fine for a clean install, where Fresh already IS correct, but wrong for the
 * one moment it matters: a returning member whose onboarding was already
 * completed must never see the Fresh placeholder decide their root phase,
 * even for one frame. [awaitLoaded] exists for that caller. It is on this
 * concrete class rather than on [OnboardingProgressStore] on purpose — no
 * screen should need it, only the composition root deciding
 * [io.appbeyond.freelance.deep.onboarding.model.rootPhase] before the first
 * frame. `AppDependencies.awaitOnboardingLoaded()` is the one place that
 * calls it.
 *
 * **Mutations land in memory first, and on disk on [scope].** Every mutation
 * rewrites [state] synchronously, before its first suspension point, so
 * `state.value` is right the instant the call is made. The DataStore write is
 * then queued to one writer coroutine on [scope] — the process-lifetime scope
 * `AppDependencies` owns, never a screen's. Screens call these from a
 * `rememberCoroutineScope()`, and a member tapping Continue disposes that
 * scope; had the write run there, a pick still queued behind an earlier write
 * would be cancelled and lost, and the crafting beat would `PUT` answers
 * missing it — which the server takes wholesale. Queued writes land in the
 * order their mutations did. A caller may still await its write; cancelling
 * that wait never cancels the write itself.
 */
class DataStoreOnboardingProgressStore(
  context: Context,
  scope: CoroutineScope,
) : OnboardingProgressStore {

  private val store: DataStore<Preferences> = context.applicationContext.onboardingDataStore

  private val _state = MutableStateFlow(OnboardingState.Fresh)
  override val state: StateFlow<OnboardingState> = _state.asStateFlow()

  /**
   * Guards each read-modify-write of [state] together with its enqueue on
   * [writes], so the order writes are queued in is the order [state] changed
   * in. Held only for that non-suspending instant, never across disk I/O.
   */
  private val lock = Any()

  /** Set by the first mutation; the initial load then leaves [state] alone. */
  private var mutated = false

  /** Pending disk writes, drained in order by the one writer on [scope]. */
  private val writes = Channel<PendingWrite>(Channel.UNLIMITED)

  private val loaded = CompletableDeferred<Unit>()

  init {
    scope.launch {
      val persisted = readPersisted()
      // A mutation that beat the load already describes what the member did
      // on top of the Fresh placeholder; the root awaits the load before its
      // first frame, so in practice this is always the untouched case.
      synchronized(lock) {
        if (!mutated) _state.value = persisted
      }
      loaded.complete(Unit)

      // Started only after the load, so a queued write can never be
      // overwritten on disk by the stale value the load is reading.
      for (write in writes) {
        try {
          persist(write.state)
        } catch (e: CancellationException) {
          throw e
        } catch (unwritable: Exception) {
          // The in-memory state stays authoritative for this run; the next
          // mutation rewrites the whole blob anyway.
        }
        write.done.complete(Unit)
      }
    }
  }

  /** Suspends until the first DataStore read has landed in [state]. */
  suspend fun awaitLoaded() {
    loaded.await()
  }

  override suspend fun recordAnswer(questionId: String, optionId: String) {
    mutate { it.recordingAnswer(questionId, optionId) }
  }

  override suspend fun recordMindTree(id: String) {
    mutate { it.recordingMindTree(id) }
  }

  override suspend fun completeOnboarding() {
    mutate { it.completed() }
  }

  override suspend fun hydrate(quizAnswers: Map<String, String>, mindTree: String?, completed: Boolean) {
    mutate { OnboardingState.hydrated(quizAnswers, mindTree, completed) }
  }

  override suspend fun reset() {
    mutate { OnboardingState.Fresh }
  }

  /**
   * Applies [transform] to [state] synchronously, queues the result for disk,
   * then waits for that write. Only the wait is cancellable.
   */
  private suspend fun mutate(transform: (OnboardingState) -> OnboardingState) {
    val write = synchronized(lock) {
      mutated = true
      val next = transform(_state.value)
      _state.value = next
      PendingWrite(next).also { writes.trySend(it) }
    }
    write.done.await()
  }

  private suspend fun readPersisted(): OnboardingState = withContext(Dispatchers.IO) {
    val stored = try {
      store.data.first()
    } catch (unreadable: IOException) {
      emptyPreferences()
    }

    stored[STATE_KEY]
      ?.let { json ->
        runCatching { DeepJson.decodeFromString(OnboardingStateDto.serializer(), json) }.getOrNull()
      }
      ?.toDomain()
      ?: OnboardingState.Fresh
  }

  private suspend fun persist(state: OnboardingState) {
    withContext(Dispatchers.IO) {
      val json = DeepJson.encodeToString(OnboardingStateDto.serializer(), state.toDto())
      store.edit { it[STATE_KEY] = json }
    }
  }

  private companion object {
    val STATE_KEY = stringPreferencesKey("deep.onboarding.state")
  }
}

/** One queued disk write, and the signal its awaiting caller resumes on. */
private class PendingWrite(val state: OnboardingState) {
  val done = CompletableDeferred<Unit>()
}

/** Wire shape for the one JSON blob [DataStoreOnboardingProgressStore] persists. */
@Serializable
private data class OnboardingStateDto(
  val hasCompletedOnboarding: Boolean = false,
  val quizAnswers: Map<String, String> = emptyMap(),
  val mindTree: String? = null,
)

private fun OnboardingState.toDto() =
  OnboardingStateDto(hasCompletedOnboarding = hasCompletedOnboarding, quizAnswers = quizAnswers, mindTree = mindTree)

private fun OnboardingStateDto.toDomain() =
  OnboardingState(hasCompletedOnboarding = hasCompletedOnboarding, quizAnswers = quizAnswers, mindTree = mindTree)

private val Context.onboardingDataStore: DataStore<Preferences> by preferencesDataStore(
  name = "deep.onboarding"
)
