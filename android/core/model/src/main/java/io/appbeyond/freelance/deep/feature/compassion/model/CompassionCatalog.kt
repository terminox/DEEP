package io.appbeyond.freelance.deep.feature.compassion.model

/**
 * The figures behind the Compassion portfolio's five causes: who each cause
 * reaches, what the community has pooled into it, and the same for its
 * projects. Hand-authored, kept local exactly as iOS keeps
 * `CompassionLibrary` — there is no backend for causes yet.
 *
 * Ported from the numbers in
 * Deep/Deep/Features/CompassionPortfolio/Models/CompassionLibrary.swift. The
 * words (names, taglines, blurbs, partner copy) live in `:app` as string
 * resources keyed by these ids, because they are translated; the figures live
 * here, once, so the heart ledger's pooled totals and the screens that draw
 * them can never disagree.
 *
 * Order is load-bearing: the community pool's ring lays its arcs out in this
 * order, its legend repeats it, and so does the causes shelf.
 */
object CompassionCatalog {

  /** One initiative within a cause — the thing hearts visibly move. */
  data class Project(
    val id: String,
    val peopleReached: Int,
    /** Progress toward this project's current goal, `0..1`. */
    val progress: Float,
    /** Community hearts pooled into this project at launch. */
    val heartsShared: Int,
  )

  /** A cause the app supports. */
  data class Cause(
    val id: String,
    val peopleReached: Int,
    /** Community hearts pooled into this cause at launch. */
    val heartsShared: Int,
    /** The year the partner organisation was founded. */
    val partnerSince: Int,
    /** The partner's site, without a scheme. */
    val partnerWebsite: String,
    val projects: List<Project>,
  )

  /** A real-world outcome reported back — the "from the field" feed. */
  data class FieldReport(
    val id: String,
    val causeId: String,
    /** How long ago it was reported, in days. Relative, as on iOS, so the
     * feed never goes stale. */
    val daysAgo: Int,
  )

  val causes: List<Cause> = listOf(
    Cause(
      id = "peace",
      peopleReached = 124_580,
      heartsShared = 18_520,
      partnerSince = 2008,
      partnerWebsite = "v-peace.org",
      projects = listOf(
        Project(id = "peace-light", peopleReached = 7_820, progress = 0.62f, heartsShared = 5_240),
        Project(id = "peace-meditation", peopleReached = 12_140, progress = 0.78f, heartsShared = 8_960),
        Project(id = "peace-circle", peopleReached = 3_410, progress = 0.41f, heartsShared = 2_180),
      ),
    ),
    Cause(
      id = "healthcare",
      peopleReached = 96_240,
      heartsShared = 16_240,
      partnerSince = 1969,
      partnerWebsite = "ramafoundation.or.th",
      projects = listOf(
        Project(id = "health-clinic", peopleReached = 9_370, progress = 0.71f, heartsShared = 6_410),
        Project(id = "health-surgery", peopleReached = 1_240, progress = 0.55f, heartsShared = 4_980),
        Project(id = "health-mental", peopleReached = 5_120, progress = 0.48f, heartsShared = 3_220),
      ),
    ),
    Cause(
      id = "education",
      peopleReached = 124_580,
      heartsShared = 14_180,
      partnerSince = 2014,
      partnerWebsite = "onebuddhist.org",
      projects = listOf(
        Project(id = "edu-art", peopleReached = 6_240, progress = 0.66f, heartsShared = 4_510),
        Project(id = "edu-learning", peopleReached = 8_900, progress = 0.73f, heartsShared = 5_870),
        Project(id = "edu-scholarship", peopleReached = 1_210, progress = 0.52f, heartsShared = 3_040),
      ),
    ),
    Cause(
      id = "nature",
      peopleReached = 124_580,
      heartsShared = 12_450,
      partnerSince = 1990,
      partnerWebsite = "seub.or.th",
      projects = listOf(
        Project(id = "nature-forest", peopleReached = 7_890, progress = 0.78f, heartsShared = 6_120),
        Project(id = "nature-water", peopleReached = 6_230, progress = 0.75f, heartsShared = 5_010),
        Project(id = "nature-wildlife", peopleReached = 5_500, progress = 0.72f, heartsShared = 4_320),
      ),
    ),
    Cause(
      id = "community",
      peopleReached = 124_580,
      heartsShared = 11_980,
      partnerSince = 2011,
      partnerWebsite = "together.or.th",
      projects = listOf(
        Project(id = "community-elderly", peopleReached = 7_350, progress = 0.78f, heartsShared = 5_640),
        Project(id = "community-meals", peopleReached = 6_280, progress = 0.71f, heartsShared = 4_710),
        Project(id = "community-shelter", peopleReached = 1_640, progress = 0.58f, heartsShared = 3_180),
      ),
    ),
  )

  /** Newest first, as iOS lists them. */
  val reports: List<FieldReport> = listOf(
    FieldReport(id = "report-clinic", causeId = "healthcare", daysAgo = 2),
    FieldReport(id = "report-forest", causeId = "nature", daysAgo = 6),
    FieldReport(id = "report-scholarship", causeId = "education", daysAgo = 11),
    FieldReport(id = "report-meals", causeId = "community", daysAgo = 15),
  )

  /** A cause by id, or null. */
  fun cause(id: String): Cause? = causes.firstOrNull { it.id == id }

  /**
   * People reached across every cause. A *community* figure — the reach of
   * every cause the app supports, not anything attributable to one member.
   */
  val peopleReached: Int = causes.sumOf { it.peopleReached }

  /** The pooled totals as the app launches, before anyone gives. */
  val launchPool: CompassionPool = CompassionPool(
    byCause = causes.associate { it.id to it.heartsShared },
    byProject = causes.flatMap { it.projects }.associate { it.id to it.heartsShared },
  )
}

/**
 * Hearts the community has pooled, per cause and per project. On iOS these
 * totals ride `CompassionCategory.heartsShared`, are seeded from the static
 * library and climb only with this device's own sends; this is the same
 * figure without the copy attached.
 *
 * @property byCause cause id → hearts pooled.
 * @property byProject project id → hearts pooled.
 */
data class CompassionPool(
  val byCause: Map<String, Int>,
  val byProject: Map<String, Int>,
) {

  /** Hearts pooled across every cause — the total the allocation ring divides. */
  val heartsPooled: Int get() = byCause.values.sum()

  /** Hearts pooled into one cause. */
  fun hearts(causeId: String): Int = byCause[causeId] ?: 0

  /** Hearts pooled into one project. */
  fun projectHearts(projectId: String): Int = byProject[projectId] ?: 0

  /**
   * One cause's share of the pool — and therefore its share of DEEP's real
   * giving, which follows the pool. This is the *only* place that ratio is
   * worked out: a cause card, the pool legend and the cause detail all read it
   * from here, so the figure can never say two different things in two places.
   * The `max(_, 1)` guard mirrors the ring's protection for an empty pool.
   */
  fun shareOfGiving(causeId: String): Float = hearts(causeId).toFloat() / maxOf(heartsPooled, 1)

  /** The pool with [amount] hearts moved into (or, negative, out of) a cause
   * and, when given, one of its projects. A project id the pool doesn't know
   * moves only the cause, as iOS's index lookup does. */
  fun adding(causeId: String, projectId: String?, amount: Int): CompassionPool {
    if (causeId !in byCause) return this
    val causes = byCause + (causeId to hearts(causeId) + amount)
    val projects = if (projectId != null && projectId in byProject) {
      byProject + (projectId to projectHearts(projectId) + amount)
    } else {
      byProject
    }
    return CompassionPool(causes, projects)
  }

  companion object {
    /** An empty pool, for a ledger that knows no causes. */
    val empty = CompassionPool(emptyMap(), emptyMap())
  }
}
