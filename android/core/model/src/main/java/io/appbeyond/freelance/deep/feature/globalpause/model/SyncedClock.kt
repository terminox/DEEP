package io.appbeyond.freelance.deep.feature.globalpause.model

import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.ZoneId

/**
 * The Global Pause clock: device time corrected toward the server's.
 *
 * Phase boundaries are shared instants — a device clock a minute off would
 * start the meditation a minute out of sync with the world. Every pause
 * response carries `serverNow`; syncing keeps a running offset so [now] tracks
 * the server without ever touching the device clock. This is also what makes
 * the dev server's time travel work (`POST /dev/pause/time-travel`): the server
 * reports a pinned `serverNow` and every client simply follows.
 *
 * Ported from Deep/Deep/Features/GlobalPause/Session/SyncedClock.swift. It is
 * also a [java.time.Clock], so anything that takes a clock — a formatter, a
 * day calculation — can be handed server time directly.
 *
 * @param device the clock being corrected. The system clock in the app; a
 *   test scheduler's virtual clock in tests.
 */
class SyncedClock(
  private val device: Clock = Clock.systemUTC(),
) : Clock() {

  /** serverNow − deviceNow at the last sync. Zero until the first one. */
  @Volatile
  var serverOffset: Duration = Duration.ZERO
    private set

  /** The server's now, as best this device knows it. */
  fun now(): Instant = device.instant().plus(serverOffset)

  /** Adopts the server's reading of now. */
  fun sync(serverNow: Instant) {
    serverOffset = Duration.between(device.instant(), serverNow)
  }

  override fun instant(): Instant = now()

  override fun getZone(): ZoneId = device.zone

  override fun withZone(zone: ZoneId): Clock =
    SyncedClock(device.withZone(zone)).also { it.serverOffset = serverOffset }
}
