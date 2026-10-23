package io.appbeyond.freelance.deep.feature.deepsound.store

import io.appbeyond.freelance.deep.feature.deepsound.model.SoundShelf
import io.appbeyond.freelance.deep.feature.deepsound.model.TrackLyrics
import io.appbeyond.freelance.deep.networking.SoundService
import io.appbeyond.freelance.deep.networking.apiCall
import io.appbeyond.freelance.deep.networking.toDomain
import io.appbeyond.freelance.deep.networking.toShelves

/**
 * [SoundLibrary] over deep-api. The Android twin of `APISoundContentRepository.swift`,
 * minus `pauseHome()` — see [SoundLibrary]'s doc for why. The DTO → domain
 * mapping itself lives in `SoundDtos.kt`, next to the wire shapes it reads.
 */
class ApiSoundLibrary(private val service: SoundService) : SoundLibrary {

  /** Anonymous content, the same for every member, so it outlives a sign-out. */
  @Volatile private var lastShelves: List<SoundShelf>? = null

  override val cachedShelves: List<SoundShelf>? get() = lastShelves

  override suspend fun shelves(): List<SoundShelf> =
    apiCall { service.home() }.toShelves().also { lastShelves = it }

  override suspend fun lyrics(trackId: String): List<TrackLyrics> =
    apiCall { service.lyrics(trackId) }.toDomain()
}
