package io.appbeyond.freelance.deep.feature.deepsound

import io.appbeyond.freelance.deep.feature.deepsound.model.SoundCollection
import io.appbeyond.freelance.deep.feature.deepsound.model.SoundTrack
import io.appbeyond.freelance.deep.feature.deepsound.model.TrackKind

/**
 * Sample Deep Sound content for previews and tests — the two "Sleep" collections
 * from `Deep/Deep/Features/DeepSound/Models/SoundLibrary.swift`.
 *
 * Hermetic on purpose: no `audioUrl`, so nothing can stream, and no `imageUrl`,
 * so a preview never reaches for the network and `ArtworkImage` paints the
 * palette gradient instead. Ids are prefixed `fixture-` so one can never be
 * mistaken for a real row in a log or a listen report.
 */
object SoundFixtures {

  val oceanDepths = SoundCollection(
    id = "fixture-ocean-depths",
    title = "Ocean Depths",
    subtitle = "Slow tides for deep rest",
    palette = "tide",
    imageUrl = null,
    categoryId = "fixture-sleep",
    tracks = listOf(
      track("fixture-drifting-tide", "Drifting Tide", minutes = 6, seconds = 12),
      track("fixture-beneath-the-surface", "Beneath the Surface", minutes = 8, seconds = 40),
      track("fixture-moonlit-current", "Moonlit Current", minutes = 5, seconds = 28),
      track("fixture-still-water", "Still Water", minutes = 9, seconds = 4),
    ),
  )

  val eveningLight = SoundCollection(
    id = "fixture-evening-light",
    title = "Evening Light",
    subtitle = "Wind down as the day softens",
    palette = "dusk",
    imageUrl = null,
    categoryId = "fixture-sleep",
    tracks = listOf(
      track("fixture-last-warmth", "Last Warmth", minutes = 7, seconds = 2),
      track("fixture-fading-gold", "Fading Gold", minutes = 6, seconds = 36),
      track("fixture-quiet-sky", "Quiet Sky", minutes = 8, seconds = 18),
    ),
  )

  val sleep: List<SoundCollection> = listOf(oceanDepths, eveningLight)

  private fun track(
    id: String,
    title: String,
    minutes: Int,
    seconds: Int,
    kind: TrackKind = TrackKind.Instrumental,
  ) = SoundTrack(id = id, title = title, durationSeconds = minutes * 60 + seconds, kind = kind)
}
