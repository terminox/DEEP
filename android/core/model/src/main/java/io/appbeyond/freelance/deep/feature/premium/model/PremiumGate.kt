package io.appbeyond.freelance.deep.feature.premium.model

import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueueEntry
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundTrack
import io.appbeyond.freelance.deep.feature.mindgarden.model.Plant

/**
 * Every DEEP Premium lock decision in the app, in one place.
 *
 * Screens never write their own "is this locked" expression: they ask here,
 * passing the one answer `PremiumAccess.hasPremium` gives them. Pure — no
 * Compose, no stores — so each rule is a unit test away. Ported from
 * Deep/Deep/Features/Premium/Models/PremiumGate.swift.
 *
 * Two inputs:
 *
 * 1. **The server's verdict** (`isLocked` on a track or collection), present
 *    whenever the content was fetched from a server that knows who asked.
 *    For sounds it can only *add* a lock: a `false` verdict was true for the
 *    member who fetched it, and a copy kept from before a lapse (a saved
 *    playlist offline, a detail screen whose re-fetch failed) would otherwise
 *    keep playing premium audio after the membership ended. That is also why
 *    a sound's `isLocked` stays a plain `Boolean` here where iOS made it
 *    optional: absent and `false` mean the same thing to a rule that only
 *    reads `true`.
 * 2. **The client rule** (`isPremium`), which always applies to a listener
 *    without DEEP Premium.
 *
 * Plants are the exception: there the server's verdict wins both ways,
 * because it is how a grandfathered plant stays open, and a plant carries no
 * audio to leak — so [Plant.isLocked] is nullable, and only null falls back
 * to [Plant.isPremium].
 *
 * Either way, `hasPremium == true` always unlocks *visually*: a member whose
 * purchase the server hasn't heard about yet is never shown a lock. The worst
 * that costs is a tap on a track whose audio the server still withholds, and
 * [canStart] keeps that tap from starting silence.
 */
object PremiumGate {

  // MARK: - Sounds

  /**
   * Whether a collection as a whole reads as locked — the badge on its
   * artwork. A free collection holding a premium track is not locked; that
   * track is.
   */
  fun isLocked(collection: SoundCollection, hasPremium: Boolean): Boolean =
    !hasPremium && (collection.isLocked || collection.isPremium)

  /**
   * Whether one track is locked *within the collection it is played from* —
   * so a free track inside a premium collection is locked by its collection.
   */
  fun isLocked(track: SoundTrack, collection: SoundCollection, hasPremium: Boolean): Boolean =
    !hasPremium && (track.isLocked || track.isPremium || isLocked(collection, hasPremium))

  /**
   * Whether the server withheld this premium track's audio. A track like that
   * must never start: the player would load it and play silence. It happens
   * to a member whose purchase the server hasn't heard about yet — unlocked
   * on the store's word, still withheld by the server — and to content kept
   * across a lapse. A free track without audio is fixture content, not a
   * withholding, and is left to the player.
   */
  fun isWithheld(track: SoundTrack, collection: SoundCollection): Boolean =
    track.audioUrl == null &&
      (track.isLocked || track.isPremium || collection.isLocked || collection.isPremium)

  /** Whether tapping this track may start it. */
  fun canStart(track: SoundTrack, collection: SoundCollection, hasPremium: Boolean): Boolean =
    !isLocked(track, collection, hasPremium) && !isWithheld(track, collection)

  /**
   * The entries a queue may hold, in order: Play, Shuffle and a tapped row
   * all queue these, so a run never carries on into a locked sound — or into
   * one the server withheld.
   */
  fun playable(entries: List<SoundQueueEntry>, hasPremium: Boolean): List<SoundQueueEntry> =
    entries.filter { canStart(it.track, it.collection, hasPremium) }

  /** A collection's tracks as playable queue entries. */
  fun playable(collection: SoundCollection, hasPremium: Boolean): List<SoundQueueEntry> =
    playable(collection.queue(), hasPremium)

  // MARK: - Plants

  /**
   * Whether a plant is locked for this member. The plant they are already
   * growing never is — not even after a lapse: taking someone's garden away
   * is a punishment, and only switching *to* a premium plant needs the
   * membership.
   */
  fun isLocked(plant: Plant, growingId: String?, hasPremium: Boolean): Boolean {
    if (plant.id == growingId || hasPremium) return false
    return plant.isLocked ?: plant.isPremium
  }
}
