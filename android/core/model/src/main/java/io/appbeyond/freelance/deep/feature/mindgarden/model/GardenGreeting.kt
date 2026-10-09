package io.appbeyond.freelance.deep.feature.mindgarden.model

import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.temporal.ChronoUnit

/**
 * What the garden opens with — a time-of-day salutation and the day's line of
 * encouragement — as *which* ones, never the words. The words are string
 * resources in the app (`garden_salutation_*`, `garden_quotes`), so they can be
 * translated; this model only decides the band and the index. A plain value
 * with fixtures so previews stay hermetic; live callers use [current].
 *
 * Ported from Deep/Deep/Features/MindGarden/Models/GardenGreeting.swift. The
 * daily rotation must land on the same line iOS shows on the same date, so
 * [quoteIndex] reproduces `Calendar.ordinality(of: .day, in: .era, for:)`
 * exactly — see there.
 */
data class GardenGreeting(
  val timeOfDay: TimeOfDay,
  /** Index into the app's quote pool, always within `0 until QUOTE_COUNT`. */
  val quoteIndex: Int,
) {
  enum class TimeOfDay { Morning, Afternoon, Evening }

  companion object {
    /** How many lines of encouragement the pool holds. The app's `garden_quotes`
     * array must carry exactly this many, in iOS's order. */
    const val QUOTE_COUNT = 8

    /** The first day of the Gregorian era — ordinal 1. */
    private val ERA_START: LocalDate = LocalDate.of(1, 1, 1)

    /**
     * The greeting for a given moment: salutation from the local hour, quote
     * rotated deterministically by the local day, so it changes daily but
     * holds still all day.
     */
    fun current(clock: Clock, zone: ZoneId): GardenGreeting {
      val now = ZonedDateTime.ofInstant(clock.instant(), zone)
      return GardenGreeting(
        timeOfDay = timeOfDay(now.hour),
        quoteIndex = quoteIndex(now.toLocalDate()),
      )
    }

    /** 5–11 morning, 12–16 afternoon, everything else evening. */
    fun timeOfDay(hour: Int): TimeOfDay = when (hour) {
      in 5..11 -> TimeOfDay.Morning
      in 12..16 -> TimeOfDay.Afternoon
      else -> TimeOfDay.Evening
    }

    /**
     * The quote for a local [day]: its 1-based ordinal within the Gregorian
     * era, modulo the pool.
     *
     * Swift's `Calendar(identifier: .gregorian).ordinality(of: .day, in: .era,
     * for:)` counts proleptically from 0001-01-01 (verified on swift-foundation:
     * 1970-01-01 → 719163, 2026-10-09 → 739898), which is exactly
     * `java.time`'s ISO calendar — so the ordinal is days since 0001-01-01,
     * plus one.
     */
    fun quoteIndex(day: LocalDate): Int {
      val ordinal = ChronoUnit.DAYS.between(ERA_START, day) + 1
      return Math.floorMod(ordinal, QUOTE_COUNT.toLong()).toInt()
    }

    val sample = GardenGreeting(timeOfDay = TimeOfDay.Morning, quoteIndex = 0)

    /** Evening fixture carrying the longest quote (index 4), to exercise text wrapping. */
    val evening = GardenGreeting(timeOfDay = TimeOfDay.Evening, quoteIndex = 4)
  }
}
