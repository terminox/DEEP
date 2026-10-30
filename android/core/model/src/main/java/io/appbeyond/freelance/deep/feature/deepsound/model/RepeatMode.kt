package io.appbeyond.freelance.deep.feature.deepsound.model

/**
 * How a queue carries on once a track plays to its end.
 *
 * Ported from `RepeatMode` in Deep/Deep/Features/DeepSound/Player/SoundQueue.swift.
 */
enum class RepeatMode(
  /** iOS's raw value, which is also what Android persists. */
  val raw: String,
) {
  /** Play through to the last track, then stop. */
  Off("off"),

  /** Run the whole queue again after the last track. */
  All("all"),

  /** Play the current track again and again. */
  One("one"),
  ;

  /** The mode the Repeat control steps to — off, all, one, and round again. */
  val next: RepeatMode
    get() = when (this) {
      Off -> All
      All -> One
      One -> Off
    }

  companion object {
    /** The mode stored as [raw]; null for nothing stored, or a value this build doesn't know. */
    fun of(raw: String?): RepeatMode? = entries.firstOrNull { it.raw == raw }
  }
}
