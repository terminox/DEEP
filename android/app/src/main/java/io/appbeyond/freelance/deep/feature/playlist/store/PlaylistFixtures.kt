package io.appbeyond.freelance.deep.feature.playlist.store

import io.appbeyond.freelance.deep.feature.deepsound.model.SoundQueueEntry
import io.appbeyond.freelance.deep.feature.deepsound.store.SoundLibraryFixtures

/**
 * Saved sounds for [MockPlaylistStore.sample], drawn from [SoundLibraryFixtures].
 * The Android twin of `PlaylistFixtures.swift`.
 *
 * Deliberately spread across three different collections: a playlist's whole
 * point is that consecutive sounds come from different places, and a fixture
 * that took them all from one album would hide every bug in that.
 */
object PlaylistFixtures {

  /** A few sounds saved, newest first. */
  val saved: List<SoundQueueEntry> = listOf(
    SoundQueueEntry(SoundLibraryFixtures.sleep[0].tracks[1], SoundLibraryFixtures.sleep[0]),
    SoundQueueEntry(SoundLibraryFixtures.morning[1].tracks[0], SoundLibraryFixtures.morning[1]),
    SoundQueueEntry(SoundLibraryFixtures.calm[0].tracks[0], SoundLibraryFixtures.calm[0]),
  )
}
