package io.appbeyond.freelance.deep.feature.mindgarden.model

/**
 * One form on a plant's growth ladder, as the admin-managed catalog defines it.
 * [threshold] is the CUMULATIVE sunlight required to *reach* this form — the
 * first stage is always 0 — so the card's banked figure never resets on an
 * evolution.
 *
 * Ported from Deep/Deep/Features/MindGarden/Models/Plant.swift. The portrait
 * fields (`mascotURL`, `mascotBgURL`, `heroVideoURL`) stay on the iOS side:
 * they're server-served asset URLs with an iOS-only bundled-video fallback,
 * not part of the pure growth derivation, and belong at the UI/networking
 * edge rather than in this module.
 */
data class PlantStage(
  val id: String,
  /** The form's name, e.g. "Young Oak" — spoken by the growth card, never
   * pictured until reached. */
  val name: String,
  /** Cumulative sunlight needed to reach this form; strictly increasing along
   * the ladder, first always 0. */
  val threshold: Int,
)
