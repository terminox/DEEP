package io.appbeyond.freelance.deep.feature.globalpause.store

import io.appbeyond.freelance.deep.feature.globalpause.model.Intention
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseJoinPoint
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseLiveSnapshot
import io.appbeyond.freelance.deep.feature.globalpause.model.PausePhaseKey
import io.appbeyond.freelance.deep.feature.globalpause.model.PausePhaseWindow
import io.appbeyond.freelance.deep.feature.globalpause.model.PauseSchedule
import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessage
import io.appbeyond.freelance.deep.feature.globalpause.model.PeaceMessagesPage
import io.appbeyond.freelance.deep.feature.globalpause.model.PostedPeaceMessage
import io.appbeyond.freelance.deep.feature.rewards.model.AwardGrant
import kotlinx.coroutines.delay
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.util.UUID

/**
 * Deterministic sample data for previews and tests — never wired by the
 * shipped app, which has no fixture fallback (a dead backend must look dead,
 * not like a working lounge).
 *
 * Ported from `FixturePauseEventRepository` in PauseEventRepository.swift,
 * plus the claim switches iOS keeps on `MockRewardsRemote`.
 *
 * @param clock what "now" is, for the schedule it resolves and the sample
 *   messages' ages.
 */
class FixturePauseEventRemote(
  private val clock: Clock = Clock.systemUTC(),
  var scheduleToServe: PauseSchedule = occurrence(meditationAt = clock.instant().plus(Duration.ofHours(2))),
) : PauseEventRemote {

  private val posted = mutableListOf<PeaceMessage>()

  // Claim switches, as iOS's MockRewardsRemote has them.

  /** Whether the server counts the night. */
  var pauseEligible = true

  /** How many claims fail before one lands, and with what. */
  var pauseClaimFailures = 0
  var pauseClaimError: Exception = java.io.IOException("offline")

  /** How long a claim takes to answer. */
  var pauseClaimDelay: Duration = Duration.ZERO

  var pauseClaimAttempts = 0
    private set

  private var claimedTonight = false

  /** How long a heartbeat takes to land. */
  var heartbeatDelay: Duration = Duration.ZERO

  /** Every presence call, in the order it lands — "beat:<id>" or "leave:<id>". */
  val presenceLog = mutableListOf<String>()

  var liveCalls = 0
    private set

  var scheduleCalls = 0
    private set

  override suspend fun schedule(): PauseSchedule {
    scheduleCalls += 1
    return scheduleToServe
  }

  override suspend fun live(): PauseLiveSnapshot {
    liveCalls += 1
    return PauseLiveSnapshot(
      serverNow = clock.instant(),
      participantCount = 4200 + posted.size,
      byCountry = mapOf("TH" to 1200, "JP" to 640, "US" to 580, "FR" to 320, "BR" to 410, "IN" to 700),
      byContinent = mapOf("AS" to 2612, "EU" to 1106, "NA" to 604, "SA" to 410, "AF" to 291, "OC" to 176),
      locations = listOf(
        PauseLiveSnapshot.GeoPoint(13.8f, 100.5f, 3), // Bangkok
        PauseLiveSnapshot.GeoPoint(35.0f, 135.8f, 1), // Kyoto
        PauseLiveSnapshot.GeoPoint(40.7f, -74.0f, 2), // New York
        PauseLiveSnapshot.GeoPoint(48.9f, 2.4f, 1), // Paris
        PauseLiveSnapshot.GeoPoint(-23.6f, -46.6f, 2), // São Paulo
        PauseLiveSnapshot.GeoPoint(-1.3f, 36.8f, 1), // Nairobi
      ),
      unlocatedByCountry = mapOf("FR" to 2),
      recentJoins = listOf(PauseLiveSnapshot.Join("TH", clock.instant(), 13.8f, 100.5f)),
    )
  }

  override suspend fun heartbeat(presenceId: String, countryIso: String?): PauseJoinPoint? {
    if (heartbeatDelay > Duration.ZERO) delay(heartbeatDelay.toMillis())
    presenceLog += "beat:$presenceId"
    // Bangkok — previews get a home to turn to.
    return PauseJoinPoint(13.8f, 100.5f)
  }

  override suspend fun leave(presenceId: String) {
    presenceLog += "leave:$presenceId"
  }

  override suspend fun messages(limit: Int, cursor: String?): PeaceMessagesPage {
    // Fixture cursor: the plain offset into the sample feed.
    val all = posted + sampleMessages(clock.instant())
    val offset = cursor?.toIntOrNull() ?: 0
    val page = all.drop(offset).take(limit)
    val next = offset + page.size
    return PeaceMessagesPage(page, if (next < all.size) next.toString() else null)
  }

  override suspend fun postMessage(text: String, countryIso: String?, intention: String?): PostedPeaceMessage {
    val message = PeaceMessage(
      id = UUID.randomUUID().toString(),
      displayName = "You",
      countryIso = countryIso,
      text = text,
      intention = intention,
      createdAt = clock.instant(),
    )
    val isFirstOfTheNight = posted.isEmpty()
    posted.add(0, message)
    return PostedPeaceMessage(
      message = message,
      award = if (isFirstOfTheNight) AwardGrant(hearts = 1, sunlight = 1, plantId = "oak") else null,
    )
  }

  override suspend fun submitReflection(intention: String?, mood: String?) = Unit

  override suspend fun claimPauseAward(): PauseAwardClaim {
    pauseClaimAttempts += 1
    if (pauseClaimDelay > Duration.ZERO) delay(pauseClaimDelay.toMillis())
    if (pauseClaimFailures > 0) {
      pauseClaimFailures -= 1
      throw pauseClaimError
    }
    if (!pauseEligible) return PauseAwardClaim(eligible = false, grant = null)
    // The ledger's unique on (user, kind, day): a second claim the same night
    // still counts, with nothing fresh to grant.
    if (claimedTonight) return PauseAwardClaim(eligible = true, grant = null)
    claimedTonight = true
    return PauseAwardClaim(eligible = true, grant = AwardGrant(hearts = 5, sunlight = 5, plantId = "oak"))
  }

  companion object {

    /**
     * One resolved occurrence around [meditationAt], in the shape of a real
     * one: a ten-minute lobby run-up, ten seconds of welcome, a ten-minute
     * meditation, then the rest of the window.
     */
    fun occurrence(
      meditationAt: Instant,
      nextMeditationAt: Instant? = null,
      lobbyAudioUrl: String? = null,
      lobbyDuration: Duration = Duration.ofSeconds(262),
      meditationDuration: Duration = Duration.ofMinutes(10),
    ): PauseSchedule {
      val lobby = meditationAt.minus(Duration.ofMinutes(10))
      val welcome = meditationAt.minusSeconds(10)
      val feedback = meditationAt.plus(meditationDuration)
      val end = feedback.plus(Duration.ofMinutes(10))
      return PauseSchedule(
        pauseDate = "2026-09-05",
        timezone = "Asia/Bangkok",
        phases = listOf(
          PausePhaseWindow(PausePhaseKey.Lobby, lobby, welcome),
          PausePhaseWindow(PausePhaseKey.Welcome, welcome, meditationAt),
          PausePhaseWindow(PausePhaseKey.Meditation, meditationAt, feedback),
          PausePhaseWindow(PausePhaseKey.Feedback, feedback, end),
        ),
        lobbyAudioUrl = lobbyAudioUrl,
        lobbyDuration = lobbyDuration,
        meditationAudioUrl = null,
        meditationDuration = meditationDuration,
        nextOccurrenceMeditationStart = nextMeditationAt,
        welcomeMessages = listOf(
          "Welcome. The world is about to pause together.",
          "Wherever you are, you are not alone.",
          "Settle in. We begin in a moment.",
        ),
        intentions = sampleIntentions,
      )
    }

    /** English labels for the seed's keys — previews only. */
    val sampleIntentions: List<Intention> = listOf(
      Intention("peace", "Peace"),
      Intention("healing", "Healing"),
      Intention("gratitude", "Gratitude"),
      Intention("someone-i-love", "Someone I love"),
      Intention("other", "Other"),
    )

    fun sampleMessages(now: Instant): List<PeaceMessage> {
      fun message(id: Int, name: String, iso: String, text: String, intention: String?, minutesAgo: Long) =
        PeaceMessage("fixture-$id", name, iso, text, intention, now.minus(Duration.ofMinutes(minutesAgo)))
      return listOf(
        message(1, "Nan", "TH", "Peace for every quiet heart tonight.", "peace", 60),
        message(2, "Haruki", "JP", "Breathing with you all from Kyoto.", "peace", 70),
        message(3, "Camille", "FR", "Ce soir, le monde respire ensemble.", "peace", 83),
        message(4, "Luana", "BR", "Sending warmth from São Paulo.", "someone-i-love", 93),
        message(5, "Amara", "KE", "May stillness find whoever needs it.", "healing", 105),
        message(6, "Noah", "US", "Grateful for this minute of quiet.", "gratitude", 118),
        message(7, "Mira", "IN", "Shanti. Shanti. Shanti.", "peace", 133),
        message(8, "Elin", "SE", "The lake is still here too. Goodnight.", null, 153),
        message(9, "Tomás", "AR", "Un abrazo enorme desde Buenos Aires.", "someone-i-love", 175),
        message(10, "Yuki", "JP", "May tomorrow be gentler than today.", null, 196),
      )
    }
  }
}
