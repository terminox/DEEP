package io.appbeyond.freelance.deep.feature.globalpause.earth

import io.appbeyond.freelance.deep.feature.globalpause.model.PauseJoinPoint
import kotlin.math.acos

/**
 * The countries Global Pause draws: where each sits, how wide its glow
 * spreads, and the continent a small one splashes into.
 *
 * Inline rather than a bundled file — the table is small enough to read, and
 * a country is a one-line append. `glowRadiusRadians` is hand-tuned per
 * country (Russia and Canada get wide blobs; island states a narrow one plus
 * the `isTiny` continent splash). Ported value for value from iOS's
 * `Earth3D/Geo/CountryLookup.swift`.
 */
object CountryLookup {

  data class Country(
    val iso2: String,
    val name: String,
    val latitude: Float,
    val longitude: Float,
    /** "AS", "EU", "AF", "NA", "SA", "OC", "AN". */
    val continentIso: String,
    val glowRadiusRadians: Float,
    val isTiny: Boolean,
  ) {
    val unitVector: Vec3 = sphereUnitVector(latitude, longitude)
    val centroid: PauseJoinPoint get() = PauseJoinPoint(latitude, longitude)
  }

  data class ContinentCenter(val iso: String, val unitVector: Vec3, val angularRadius: Float)

  val countries: List<Country> = listOf(
    // Asia
    Country("TH", "Thailand", 15.87f, 100.99f, "AS", 0.055f, false),
    Country("JP", "Japan", 36.20f, 138.25f, "AS", 0.060f, false),
    Country("CN", "China", 35.86f, 104.20f, "AS", 0.140f, false),
    Country("IN", "India", 20.59f, 78.96f, "AS", 0.130f, false),
    Country("ID", "Indonesia", -0.79f, 113.92f, "AS", 0.110f, false),
    Country("VN", "Vietnam", 14.06f, 108.28f, "AS", 0.060f, false),
    Country("PH", "Philippines", 12.88f, 121.77f, "AS", 0.065f, false),
    Country("MY", "Malaysia", 4.21f, 101.98f, "AS", 0.060f, false),
    Country("SG", "Singapore", 1.35f, 103.82f, "AS", 0.022f, true),
    Country("KR", "South Korea", 35.91f, 127.77f, "AS", 0.045f, false),
    Country("TW", "Taiwan", 23.70f, 120.96f, "AS", 0.030f, true),
    Country("HK", "Hong Kong", 22.32f, 114.17f, "AS", 0.020f, true),
    Country("AE", "UAE", 23.42f, 53.85f, "AS", 0.045f, false),
    Country("SA", "Saudi Arabia", 23.89f, 45.08f, "AS", 0.100f, false),
    Country("IL", "Israel", 31.05f, 34.85f, "AS", 0.030f, true),
    Country("TR", "Turkey", 38.96f, 35.24f, "AS", 0.085f, false),
    Country("PK", "Pakistan", 30.38f, 69.35f, "AS", 0.085f, false),
    Country("BD", "Bangladesh", 23.68f, 90.36f, "AS", 0.050f, false),
    Country("RU", "Russia", 61.52f, 105.32f, "AS", 0.220f, false),

    // Europe
    Country("GB", "United Kingdom", 55.38f, -3.44f, "EU", 0.050f, false),
    Country("FR", "France", 46.23f, 2.21f, "EU", 0.060f, false),
    Country("DE", "Germany", 51.17f, 10.45f, "EU", 0.055f, false),
    Country("ES", "Spain", 40.46f, -3.75f, "EU", 0.060f, false),
    Country("IT", "Italy", 41.87f, 12.57f, "EU", 0.055f, false),
    Country("NL", "Netherlands", 52.13f, 5.29f, "EU", 0.035f, true),
    Country("CH", "Switzerland", 46.82f, 8.23f, "EU", 0.030f, true),
    Country("SE", "Sweden", 60.13f, 18.64f, "EU", 0.075f, false),
    Country("NO", "Norway", 60.47f, 8.47f, "EU", 0.080f, false),
    Country("DK", "Denmark", 56.26f, 9.50f, "EU", 0.035f, true),
    Country("FI", "Finland", 61.92f, 25.75f, "EU", 0.075f, false),
    Country("PL", "Poland", 51.92f, 19.15f, "EU", 0.060f, false),
    Country("IE", "Ireland", 53.14f, -7.69f, "EU", 0.035f, true),
    Country("PT", "Portugal", 39.40f, -8.22f, "EU", 0.040f, true),
    Country("GR", "Greece", 39.07f, 21.82f, "EU", 0.045f, false),
    Country("AT", "Austria", 47.52f, 14.55f, "EU", 0.030f, true),
    Country("BE", "Belgium", 50.50f, 4.47f, "EU", 0.025f, true),
    Country("CZ", "Czechia", 49.82f, 15.47f, "EU", 0.030f, true),
    Country("RO", "Romania", 45.94f, 24.97f, "EU", 0.045f, false),
    Country("UA", "Ukraine", 48.38f, 31.17f, "EU", 0.075f, false),

    // Africa
    Country("ZA", "South Africa", -30.56f, 22.94f, "AF", 0.085f, false),
    Country("NG", "Nigeria", 9.08f, 8.68f, "AF", 0.075f, false),
    Country("EG", "Egypt", 26.82f, 30.80f, "AF", 0.075f, false),
    Country("KE", "Kenya", -0.02f, 37.91f, "AF", 0.060f, false),
    Country("MA", "Morocco", 31.79f, -7.09f, "AF", 0.060f, false),
    Country("ET", "Ethiopia", 9.15f, 40.49f, "AF", 0.080f, false),
    Country("GH", "Ghana", 7.95f, -1.02f, "AF", 0.045f, false),
    Country("TZ", "Tanzania", -6.37f, 34.89f, "AF", 0.075f, false),

    // North America
    Country("US", "United States", 39.83f, -98.58f, "NA", 0.180f, false),
    Country("CA", "Canada", 56.13f, -106.35f, "NA", 0.210f, false),
    Country("MX", "Mexico", 23.63f, -102.55f, "NA", 0.090f, false),
    Country("GT", "Guatemala", 15.78f, -90.23f, "NA", 0.030f, true),
    Country("CR", "Costa Rica", 9.75f, -83.75f, "NA", 0.025f, true),
    Country("PA", "Panama", 8.54f, -80.78f, "NA", 0.025f, true),
    Country("CU", "Cuba", 21.52f, -77.78f, "NA", 0.030f, true),

    // South America
    Country("BR", "Brazil", -14.24f, -51.93f, "SA", 0.180f, false),
    Country("AR", "Argentina", -38.42f, -63.62f, "SA", 0.130f, false),
    Country("CL", "Chile", -35.68f, -71.54f, "SA", 0.090f, false),
    Country("CO", "Colombia", 4.57f, -74.30f, "SA", 0.080f, false),
    Country("PE", "Peru", -9.19f, -75.02f, "SA", 0.090f, false),
    Country("VE", "Venezuela", 6.42f, -66.59f, "SA", 0.080f, false),
    Country("EC", "Ecuador", -1.83f, -78.18f, "SA", 0.045f, false),
    Country("UY", "Uruguay", -32.52f, -55.77f, "SA", 0.035f, true),

    // Oceania
    Country("AU", "Australia", -25.27f, 133.78f, "OC", 0.160f, false),
    Country("NZ", "New Zealand", -40.90f, 174.89f, "OC", 0.060f, false),
    Country("FJ", "Fiji", -17.71f, 178.07f, "OC", 0.022f, true),
    Country("PG", "Papua New Guinea", -6.31f, 143.96f, "OC", 0.060f, false),
  )

  private val continentCenters: Map<String, ContinentCenter> = listOf(
    Triple("AS", 45f to 90f, 0.30f),
    Triple("EU", 52f to 15f, 0.18f),
    Triple("AF", 5f to 20f, 0.27f),
    Triple("NA", 45f to -100f, 0.27f),
    Triple("SA", -15f to -60f, 0.22f),
    Triple("OC", -25f to 140f, 0.18f),
    Triple("AN", -80f to 0f, 0.10f),
  ).associate { (iso, latLon, radius) ->
    iso to ContinentCenter(iso, sphereUnitVector(latLon.first, latLon.second), radius)
  }

  private val byIso: Map<String, Country> = countries.associateBy { it.iso2 }

  fun country(iso: String): Country? = byIso[iso.uppercase()]

  fun continentCenter(iso: String): ContinentCenter? = continentCenters[iso.uppercase()]

  /** Where a country sits, as `GlobalPauseSession` wants it for joins and
   * the member's first-guess location. */
  fun centroid(iso: String): PauseJoinPoint? = country(iso)?.centroid

  /** The nearest country (great-circle) to a point, within [withinDegrees]. */
  fun nearestCountry(lat: Float, lon: Float, withinDegrees: Float): Country? {
    val target = sphereUnitVector(lat, lon)
    var best: Country? = null
    var bestDeg = Float.MAX_VALUE
    for (c in countries) {
      val deg = acos((c.unitVector dot target).coerceIn(-1f, 1f)) / DEG
      if (deg < bestDeg) {
        best = c
        bestDeg = deg
      }
    }
    return best?.takeIf { bestDeg <= withinDegrees }
  }
}
