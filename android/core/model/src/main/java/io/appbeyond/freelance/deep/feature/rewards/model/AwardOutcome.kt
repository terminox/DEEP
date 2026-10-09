package io.appbeyond.freelance.deep.feature.rewards.model

/**
 * What earned an award — mirrors deep-api's `AwardKind` enum. The transport
 * maps the wire string through [fromWire]; an unknown kind from a newer server
 * reads as null rather than failing the response.
 */
enum class AwardKind(val wireName: String) {
  SESSION_COMPLETED("SESSION_COMPLETED"),
  TRACK_COMPLETED("TRACK_COMPLETED"),
  PAUSE_ATTENDED("PAUSE_ATTENDED"),
  PEACE_MESSAGE("PEACE_MESSAGE"),
  DAILY_CHECKIN("DAILY_CHECKIN");

  companion object {
    fun fromWire(value: String?): AwardKind? = entries.firstOrNull { it.wireName == value }
  }
}

/**
 * Why the server withheld an award — deep-api's `CapReason`. Only
 * [DAILY_CAP] means the day's hearts are full; the others are per-kind or
 * replay refusals the UI never surfaces as "full".
 */
enum class AwardCap(val wireName: String) {
  /** The day's hard hearts cap ([RewardRules.dailyHeartsCap]) would be exceeded. */
  DAILY_CAP("daily_cap"),

  /** This kind's own per-day limit is spent (e.g. a fifth DEEP Session). */
  KIND_CAP("kind_cap"),

  /** The same source was already awarded — a replayed sync. */
  DUPLICATE("duplicate");

  companion object {
    fun fromWire(value: String?): AwardCap? = entries.firstOrNull { it.wireName == value }
  }
}

/**
 * One award decision as the server reports it (`serializeAwardOutcome`).
 * Missing wire fields map to the defaults here, which is exactly how iOS's
 * fold reads its optional DTO fields (`granted == true`, `?? 0`).
 */
data class AwardOutcome(
  val kind: AwardKind? = null,
  val granted: Boolean = false,
  val heartsGranted: Int = 0,
  val sunlightGranted: Int = 0,
  val plantId: String? = null,
  val cappedBy: AwardCap? = null,
)

/**
 * The credited plant's post-award progress (`PlantProgressDTO`), riding
 * award responses beside the wallet.
 */
data class PlantProgress(
  val plantId: String,
  val sunlight: Int,
  val currentStageIndex: Int? = null,
)
