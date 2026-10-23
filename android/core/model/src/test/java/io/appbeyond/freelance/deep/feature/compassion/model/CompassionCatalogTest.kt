package io.appbeyond.freelance.deep.feature.compassion.model

import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** The causes' figures and the one place their share of giving is worked out. */
class CompassionCatalogTest {

  @Test
  @DisplayName("Every cause's share of giving sums to the whole")
  fun sharesSumToOne() {
    val pool = CompassionCatalog.launchPool
    val total = CompassionCatalog.causes.sumOf { pool.shareOfGiving(it.id).toDouble() }
    assertEquals(1.0, total, 1e-5)
  }

  @Test
  @DisplayName("The launch pool is the catalog's own totals")
  fun launchPoolMatchesCatalog() {
    assertEquals(73_370, CompassionCatalog.launchPool.heartsPooled)
    assertEquals(5_240, CompassionCatalog.launchPool.projectHearts("peace-light"))
  }

  @Test
  @DisplayName("An empty pool never divides by zero")
  fun emptyPoolShareIsZero() {
    assertEquals(0f, CompassionPool.empty.shareOfGiving("peace"))
  }

  @Test
  @DisplayName("Ids are unique, and every report names a real cause")
  fun idsAreConsistent() {
    val causeIds = CompassionCatalog.causes.map { it.id }
    assertEquals(causeIds.size, causeIds.toSet().size)
    val projectIds = CompassionCatalog.causes.flatMap { c -> c.projects.map { it.id } }
    assertEquals(projectIds.size, projectIds.toSet().size)
    assertTrue(CompassionCatalog.reports.all { CompassionCatalog.cause(it.causeId) != null })
  }

  @Test
  @DisplayName("An unknown cause leaves the pool unchanged")
  fun unknownCauseIsIgnored() {
    val pool = CompassionCatalog.launchPool
    assertEquals(pool, pool.adding("nope", null, 3))
  }
}
