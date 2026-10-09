package io.appbeyond.freelance.deep.feature.mindgarden.model

import kotlinx.serialization.Serializable

/**
 * One form on a plant's growth ladder, as the admin-managed catalog defines it.
 * [threshold] is the CUMULATIVE sunlight required to *reach* this form — the
 * first stage is always 0 — so the card's banked figure never resets on an
 * evolution. Asset URLs are optional: fixture stages and half-authored catalog
 * entries simply fall back to gradient artwork.
 *
 * Ported from Deep/Deep/Features/MindGarden/Models/Plant.swift. URLs stay
 * plain strings — the image and video loaders parse them at the UI edge — and
 * the type is `@Serializable` because the garden store's persisted blob carries
 * the selected plant whole, as iOS's `Codable` conformance does.
 */
@Serializable
data class PlantStage(
  val id: String,
  /** The form's name, e.g. "Young Oak" — spoken by the growth card, never
   * pictured until reached. */
  val name: String,
  /** Cumulative sunlight needed to reach this form; strictly increasing along
   * the ladder, first always 0. */
  val threshold: Int,
  /** The form's portrait, background removed. */
  val mascotUrl: String? = null,
  /** The portrait on its painted background, when one exists. */
  val mascotBgUrl: String? = null,
  /** The looping hero video for this form, when one exists. */
  val heroVideoUrl: String? = null,
)
