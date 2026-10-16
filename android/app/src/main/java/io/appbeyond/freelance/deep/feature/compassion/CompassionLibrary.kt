package io.appbeyond.freelance.deep.feature.compassion

import android.content.res.Resources
import androidx.annotation.StringRes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalResources
import io.appbeyond.freelance.deep.R
import io.appbeyond.freelance.deep.feature.compassion.model.CompassionCatalog
import io.appbeyond.freelance.deep.shared.components.ArtworkPalette

// MARK: - Content

/** The real-world organisation a cause's donations flow to. */
@Immutable
data class CompassionPartner(
  val name: String,
  val blurb: String,
  /** Where the partner operates, e.g. "Thailand" or "Global". */
  val scope: String,
  val since: Int,
  val website: String,
  val symbol: ImageVector,
)

/** A concrete initiative within a cause — the thing hearts visibly move. */
@Immutable
data class CompassionProject(
  val id: String,
  val title: String,
  val blurb: String,
  val palette: ArtworkPalette,
  val symbol: ImageVector,
  val peopleReached: Int,
  /** Progress toward this project's current goal, `0..1`. */
  val progress: Float,
)

/**
 * A cause the app supports. Hearts sent here are pooled across the community;
 * DEEP then donates real money to the partner in proportion to the hearts that
 * reached it. The pooled totals are not here — they move, so they live on the
 * heart ledger's `pool`; this is the cause as written.
 */
@Immutable
data class CompassionCause(
  val id: String,
  val name: String,
  val tagline: String,
  val symbol: ImageVector,
  val palette: ArtworkPalette,
  val peopleReached: Int,
  val partner: CompassionPartner,
  val projects: List<CompassionProject>,
)

/** A real-world outcome reported back — the "from the field" feed. */
@Immutable
data class FieldReport(
  val id: String,
  val causeName: String,
  val title: String,
  val blurb: String,
  val location: String,
  val daysAgo: Int,
  val symbol: ImageVector,
  val palette: ArtworkPalette,
)

/** The whole portfolio as written, in the language being read. */
@Immutable
data class CompassionContent(
  val causes: List<CompassionCause>,
  val reports: List<FieldReport>,
) {
  /** A cause by id, or null. */
  fun cause(id: String): CompassionCause? = causes.firstOrNull { it.id == id }

  /** People reached across every cause — a community figure. */
  val peopleReached: Int get() = causes.sumOf { it.peopleReached }
}

// MARK: - Library

/**
 * The static catalogue of causes, partners, projects and field reports, kept
 * local exactly as iOS keeps it.
 *
 * Ported from Deep/Deep/Features/CompassionPortfolio/Models/CompassionLibrary.swift.
 * The figures come from `:core:model`'s [CompassionCatalog] (one source, so the
 * ledger's pool and these screens agree); the words come from
 * `strings_compassion.xml`, named explicitly rather than looked up by id at run
 * time, so resource shrinking keeps every one of them.
 *
 * Each cause wears its own palette — the order and pairings iOS ships.
 */
object CompassionLibrary {

  private class CauseCopy(
    @param:StringRes val name: Int,
    @param:StringRes val tagline: Int,
    @param:StringRes val partner: Int,
    @param:StringRes val partnerBlurb: Int,
    @param:StringRes val scope: Int,
    val symbol: ImageVector,
    val partnerSymbol: ImageVector,
    val palette: ArtworkPalette,
  )

  private class ProjectCopy(
    @param:StringRes val title: Int,
    @param:StringRes val blurb: Int,
    val symbol: ImageVector,
    val palette: ArtworkPalette,
  )

  private class ReportCopy(
    @param:StringRes val title: Int,
    @param:StringRes val blurb: Int,
    @param:StringRes val location: Int,
    val symbol: ImageVector,
    val palette: ArtworkPalette,
  )

  private val causeCopy: Map<String, CauseCopy> = mapOf(
    "peace" to CauseCopy(
      R.string.cause_peace_name, R.string.cause_peace_tagline, R.string.cause_peace_partner,
      R.string.cause_peace_partner_blurb, R.string.cause_scope_global,
      CompassionIcons.BirdFill, CompassionIcons.HandsAndSparklesFill, ArtworkPalette.Aurora,
    ),
    "healthcare" to CauseCopy(
      R.string.cause_healthcare_name, R.string.cause_healthcare_tagline, R.string.cause_healthcare_partner,
      R.string.cause_healthcare_partner_blurb, R.string.cause_scope_thailand,
      CompassionIcons.CrossFill, CompassionIcons.Stethoscope, ArtworkPalette.Bloom,
    ),
    "education" to CauseCopy(
      R.string.cause_education_name, R.string.cause_education_tagline, R.string.cause_education_partner,
      R.string.cause_education_partner_blurb, R.string.cause_scope_global,
      CompassionIcons.BookFill, CompassionIcons.GraduationcapFill, ArtworkPalette.Ember,
    ),
    "nature" to CauseCopy(
      R.string.cause_nature_name, R.string.cause_nature_tagline, R.string.cause_nature_partner,
      R.string.cause_nature_partner_blurb, R.string.cause_scope_thailand,
      CompassionIcons.LeafFill, CompassionIcons.TreeFill, ArtworkPalette.Mist,
    ),
    "community" to CauseCopy(
      R.string.cause_community_name, R.string.cause_community_tagline, R.string.cause_community_partner,
      R.string.cause_community_partner_blurb, R.string.cause_scope_thailand,
      CompassionIcons.HouseFill, CompassionIcons.PersonThreeFill, ArtworkPalette.Tide,
    ),
  )

  private val projectCopy: Map<String, ProjectCopy> = mapOf(
    "peace-light" to ProjectCopy(
      R.string.project_peace_light_title, R.string.project_peace_light_blurb,
      CompassionIcons.FlameFill, ArtworkPalette.Aurora,
    ),
    "peace-meditation" to ProjectCopy(
      R.string.project_peace_meditation_title, R.string.project_peace_meditation_blurb,
      CompassionIcons.MoonStarsFill, ArtworkPalette.Mist,
    ),
    "peace-circle" to ProjectCopy(
      R.string.project_peace_circle_title, R.string.project_peace_circle_blurb,
      CompassionIcons.CircleHexagonGridFill, ArtworkPalette.Dusk,
    ),
    "health-clinic" to ProjectCopy(
      R.string.project_health_clinic_title, R.string.project_health_clinic_blurb,
      CompassionIcons.BusFill, ArtworkPalette.Bloom,
    ),
    "health-surgery" to ProjectCopy(
      R.string.project_health_surgery_title, R.string.project_health_surgery_blurb,
      CompassionIcons.HeartTextSquareFill, ArtworkPalette.Dusk,
    ),
    "health-mental" to ProjectCopy(
      R.string.project_health_mental_title, R.string.project_health_mental_blurb,
      CompassionIcons.BrainHeadProfile, ArtworkPalette.Mist,
    ),
    "edu-art" to ProjectCopy(
      R.string.project_edu_art_title, R.string.project_edu_art_blurb,
      CompassionIcons.PaintbrushFill, ArtworkPalette.Ember,
    ),
    "edu-learning" to ProjectCopy(
      R.string.project_edu_learning_title, R.string.project_edu_learning_blurb,
      CompassionIcons.BooksVerticalFill, ArtworkPalette.Bloom,
    ),
    "edu-scholarship" to ProjectCopy(
      R.string.project_edu_scholarship_title, R.string.project_edu_scholarship_blurb,
      CompassionIcons.Rosette, ArtworkPalette.Aurora,
    ),
    "nature-forest" to ProjectCopy(
      R.string.project_nature_forest_title, R.string.project_nature_forest_blurb,
      CompassionIcons.TreeFill, ArtworkPalette.Mist,
    ),
    "nature-water" to ProjectCopy(
      R.string.project_nature_water_title, R.string.project_nature_water_blurb,
      CompassionIcons.DropFill, ArtworkPalette.Tide,
    ),
    "nature-wildlife" to ProjectCopy(
      R.string.project_nature_wildlife_title, R.string.project_nature_wildlife_blurb,
      CompassionIcons.PawprintFill, ArtworkPalette.Aurora,
    ),
    "community-elderly" to ProjectCopy(
      R.string.project_community_elderly_title, R.string.project_community_elderly_blurb,
      CompassionIcons.FigureTwoArmsOpen, ArtworkPalette.Tide,
    ),
    "community-meals" to ProjectCopy(
      R.string.project_community_meals_title, R.string.project_community_meals_blurb,
      CompassionIcons.ForkKnife, ArtworkPalette.Ember,
    ),
    "community-shelter" to ProjectCopy(
      R.string.project_community_shelter_title, R.string.project_community_shelter_blurb,
      CompassionIcons.HouseLodgeFill, ArtworkPalette.Dusk,
    ),
  )

  private val reportCopy: Map<String, ReportCopy> = mapOf(
    "report-clinic" to ReportCopy(
      R.string.report_clinic_title, R.string.report_clinic_blurb, R.string.report_clinic_location,
      CompassionIcons.BusFill, ArtworkPalette.Bloom,
    ),
    "report-forest" to ReportCopy(
      R.string.report_forest_title, R.string.report_forest_blurb, R.string.report_forest_location,
      CompassionIcons.TreeFill, ArtworkPalette.Mist,
    ),
    "report-scholarship" to ReportCopy(
      R.string.report_scholarship_title, R.string.report_scholarship_blurb, R.string.report_scholarship_location,
      CompassionIcons.GraduationcapFill, ArtworkPalette.Ember,
    ),
    "report-meals" to ReportCopy(
      R.string.report_meals_title, R.string.report_meals_blurb, R.string.report_meals_location,
      CompassionIcons.ForkKnife, ArtworkPalette.Tide,
    ),
  )

  /** The catalogue in [resources]' language, in [CompassionCatalog]'s order. */
  fun content(resources: Resources): CompassionContent {
    val causes = CompassionCatalog.causes.mapNotNull { cause ->
      val copy = causeCopy[cause.id] ?: return@mapNotNull null
      CompassionCause(
        id = cause.id,
        name = resources.getString(copy.name),
        tagline = resources.getString(copy.tagline),
        symbol = copy.symbol,
        palette = copy.palette,
        peopleReached = cause.peopleReached,
        partner = CompassionPartner(
          name = resources.getString(copy.partner),
          blurb = resources.getString(copy.partnerBlurb),
          scope = resources.getString(copy.scope),
          since = cause.partnerSince,
          website = cause.partnerWebsite,
          symbol = copy.partnerSymbol,
        ),
        projects = cause.projects.mapNotNull { project ->
          val words = projectCopy[project.id] ?: return@mapNotNull null
          CompassionProject(
            id = project.id,
            title = resources.getString(words.title),
            blurb = resources.getString(words.blurb),
            palette = words.palette,
            symbol = words.symbol,
            peopleReached = project.peopleReached,
            progress = project.progress,
          )
        },
      )
    }
    val reports = CompassionCatalog.reports.mapNotNull { report ->
      val copy = reportCopy[report.id] ?: return@mapNotNull null
      val cause = causes.firstOrNull { it.id == report.causeId } ?: return@mapNotNull null
      FieldReport(
        id = report.id,
        causeName = cause.name,
        title = resources.getString(copy.title),
        blurb = resources.getString(copy.blurb),
        location = resources.getString(copy.location),
        daysAgo = report.daysAgo,
        symbol = copy.symbol,
        palette = copy.palette,
      )
    }
    return CompassionContent(causes, reports)
  }
}

/** The catalogue, re-read whenever the language (the configuration) changes. */
@Composable
fun rememberCompassionContent(): CompassionContent {
  val resources = LocalResources.current
  val configuration = LocalConfiguration.current
  return remember(resources, configuration) { CompassionLibrary.content(resources) }
}
