package io.appbeyond.freelance.deep.networking

import io.appbeyond.freelance.deep.onboarding.model.MindTree
import io.appbeyond.freelance.deep.onboarding.model.OnboardingConfig
import io.appbeyond.freelance.deep.onboarding.model.QuizOption
import io.appbeyond.freelance.deep.onboarding.model.QuizQuestion
import kotlinx.serialization.Serializable

/*
 * Wire shapes for deep-api's onboarding routes, ported from the
 * `OnboardingConfigDTO` / `OnboardingProfileDTO` family in `DTOs.swift`.
 * [QuizOptionDto.palette] and [MindTreeDto.palette] travel as the bare server
 * string on both ends of this file — unlike iOS, nothing here maps it to an
 * `ArtworkPalette` case; `QuizOption`/`MindTree` in `:core:model` keep it a
 * plain `String`.
 *
 * `OnboardingProfileDto` maps to the store-layer `OnboardingProfile`
 * (`OnboardingStoreContracts.kt`) inline in `ApiOnboardingRemote`, not here —
 * this file only maps down to `:core:model` types, so the networking layer
 * never has to know a feature package exists.
 */

@Serializable
data class QuizOptionDto(
  val id: String,
  val title: String,
  val subtitle: String? = null,
  val palette: String,
)

@Serializable
data class QuizQuestionDto(
  val id: String,
  val prompt: String,
  val options: List<QuizOptionDto> = emptyList(),
)

@Serializable
data class MindTreeDto(
  val id: String,
  val name: String,
  val tagline: String,
  val imageUrl: String? = null,
  val palette: String,
)

/** `GET /onboarding/config` (anon). */
@Serializable
data class OnboardingConfigDto(
  val questions: List<QuizQuestionDto> = emptyList(),
  val mindTrees: List<MindTreeDto> = emptyList(),
)

/** `GET /me/onboarding`, and the reply from `PUT /me/onboarding`. */
@Serializable
data class OnboardingProfileDto(
  val quizAnswers: Map<String, String> = emptyMap(),
  val mindTree: String? = null,
  val completed: Boolean = false,
)

/** `PUT /me/onboarding` — always the FULL state; the server replaces wholesale. */
@Serializable
data class OnboardingPutRequestDto(
  val quizAnswers: Map<String, String>,
  val mindTree: String?,
  val completed: Boolean,
)

fun OnboardingConfigDto.toDomain(): OnboardingConfig = OnboardingConfig(
  questions = questions.map { it.toDomain() },
  mindTrees = mindTrees.map { it.toDomain() },
)

private fun QuizQuestionDto.toDomain(): QuizQuestion = QuizQuestion(
  id = id,
  prompt = prompt,
  options = options.map { it.toDomain() },
)

private fun QuizOptionDto.toDomain(): QuizOption = QuizOption(
  id = id,
  title = title,
  subtitle = subtitle,
  palette = palette,
)

private fun MindTreeDto.toDomain(): MindTree = MindTree(
  id = id,
  name = name,
  tagline = tagline,
  imageUrl = imageUrl,
  palette = palette,
)
