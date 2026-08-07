import Foundation
import simd

/// Inline table of countries we currently care about for Global Pause.
///
/// Why inline instead of bundled JSON: synced-folder resource handling is one
/// less Xcode gotcha to debug, and the table is small enough to type. Adding
/// a country is a one-line append below; no asset re-export needed.
///
/// `glowRadius` is intentionally hand-tuned per country — large nations
/// (Russia, USA, Canada) get wider blobs; small island nations get a narrow
/// blob plus the `isTiny` continent-splash treatment.
@MainActor
final class CountryLookup {
  static let shared = CountryLookup()

  struct Country: Sendable {
    let iso2: String
    let name: String
    let latitude: Float       // degrees
    let longitude: Float      // degrees
    let continentISO: String  // "AS", "EU", "AF", "NA", "SA", "OC", "AN"
    let glowRadiusRadians: Float
    let isTiny: Bool

    var unitVector: SIMD3<Float> {
      sphereUnitVector(latDeg: latitude, lonDeg: longitude)
    }
  }

  struct ContinentCenter {
    let iso: String
    let unitVector: SIMD3<Float>
    let angularRadius: Float
  }

  // MARK: - Country data

  private let countries: [Country] = [
    // Asia
    .init(iso2: "TH", name: "Thailand",    latitude: 15.87,  longitude: 100.99, continentISO: "AS", glowRadiusRadians: 0.055, isTiny: false),
    .init(iso2: "JP", name: "Japan",       latitude: 36.20,  longitude: 138.25, continentISO: "AS", glowRadiusRadians: 0.060, isTiny: false),
    .init(iso2: "CN", name: "China",       latitude: 35.86,  longitude: 104.20, continentISO: "AS", glowRadiusRadians: 0.140, isTiny: false),
    .init(iso2: "IN", name: "India",       latitude: 20.59,  longitude: 78.96,  continentISO: "AS", glowRadiusRadians: 0.130, isTiny: false),
    .init(iso2: "ID", name: "Indonesia",   latitude: -0.79,  longitude: 113.92, continentISO: "AS", glowRadiusRadians: 0.110, isTiny: false),
    .init(iso2: "VN", name: "Vietnam",     latitude: 14.06,  longitude: 108.28, continentISO: "AS", glowRadiusRadians: 0.060, isTiny: false),
    .init(iso2: "PH", name: "Philippines", latitude: 12.88,  longitude: 121.77, continentISO: "AS", glowRadiusRadians: 0.065, isTiny: false),
    .init(iso2: "MY", name: "Malaysia",    latitude: 4.21,   longitude: 101.98, continentISO: "AS", glowRadiusRadians: 0.060, isTiny: false),
    .init(iso2: "SG", name: "Singapore",   latitude: 1.35,   longitude: 103.82, continentISO: "AS", glowRadiusRadians: 0.022, isTiny: true),
    .init(iso2: "KR", name: "South Korea", latitude: 35.91,  longitude: 127.77, continentISO: "AS", glowRadiusRadians: 0.045, isTiny: false),
    .init(iso2: "TW", name: "Taiwan",      latitude: 23.70,  longitude: 120.96, continentISO: "AS", glowRadiusRadians: 0.030, isTiny: true),
    .init(iso2: "HK", name: "Hong Kong",   latitude: 22.32,  longitude: 114.17, continentISO: "AS", glowRadiusRadians: 0.020, isTiny: true),
    .init(iso2: "AE", name: "UAE",         latitude: 23.42,  longitude: 53.85,  continentISO: "AS", glowRadiusRadians: 0.045, isTiny: false),
    .init(iso2: "SA", name: "Saudi Arabia",latitude: 23.89,  longitude: 45.08,  continentISO: "AS", glowRadiusRadians: 0.100, isTiny: false),
    .init(iso2: "IL", name: "Israel",      latitude: 31.05,  longitude: 34.85,  continentISO: "AS", glowRadiusRadians: 0.030, isTiny: true),
    .init(iso2: "TR", name: "Turkey",      latitude: 38.96,  longitude: 35.24,  continentISO: "AS", glowRadiusRadians: 0.085, isTiny: false),
    .init(iso2: "PK", name: "Pakistan",    latitude: 30.38,  longitude: 69.35,  continentISO: "AS", glowRadiusRadians: 0.085, isTiny: false),
    .init(iso2: "BD", name: "Bangladesh",  latitude: 23.68,  longitude: 90.36,  continentISO: "AS", glowRadiusRadians: 0.050, isTiny: false),
    .init(iso2: "RU", name: "Russia",      latitude: 61.52,  longitude: 105.32, continentISO: "AS", glowRadiusRadians: 0.220, isTiny: false),

    // Europe
    .init(iso2: "GB", name: "United Kingdom", latitude: 55.38, longitude: -3.44, continentISO: "EU", glowRadiusRadians: 0.050, isTiny: false),
    .init(iso2: "FR", name: "France",         latitude: 46.23, longitude: 2.21,  continentISO: "EU", glowRadiusRadians: 0.060, isTiny: false),
    .init(iso2: "DE", name: "Germany",        latitude: 51.17, longitude: 10.45, continentISO: "EU", glowRadiusRadians: 0.055, isTiny: false),
    .init(iso2: "ES", name: "Spain",          latitude: 40.46, longitude: -3.75, continentISO: "EU", glowRadiusRadians: 0.060, isTiny: false),
    .init(iso2: "IT", name: "Italy",          latitude: 41.87, longitude: 12.57, continentISO: "EU", glowRadiusRadians: 0.055, isTiny: false),
    .init(iso2: "NL", name: "Netherlands",    latitude: 52.13, longitude: 5.29,  continentISO: "EU", glowRadiusRadians: 0.035, isTiny: true),
    .init(iso2: "CH", name: "Switzerland",    latitude: 46.82, longitude: 8.23,  continentISO: "EU", glowRadiusRadians: 0.030, isTiny: true),
    .init(iso2: "SE", name: "Sweden",         latitude: 60.13, longitude: 18.64, continentISO: "EU", glowRadiusRadians: 0.075, isTiny: false),
    .init(iso2: "NO", name: "Norway",         latitude: 60.47, longitude: 8.47,  continentISO: "EU", glowRadiusRadians: 0.080, isTiny: false),
    .init(iso2: "DK", name: "Denmark",        latitude: 56.26, longitude: 9.50,  continentISO: "EU", glowRadiusRadians: 0.035, isTiny: true),
    .init(iso2: "FI", name: "Finland",        latitude: 61.92, longitude: 25.75, continentISO: "EU", glowRadiusRadians: 0.075, isTiny: false),
    .init(iso2: "PL", name: "Poland",         latitude: 51.92, longitude: 19.15, continentISO: "EU", glowRadiusRadians: 0.060, isTiny: false),
    .init(iso2: "IE", name: "Ireland",        latitude: 53.14, longitude: -7.69, continentISO: "EU", glowRadiusRadians: 0.035, isTiny: true),
    .init(iso2: "PT", name: "Portugal",       latitude: 39.40, longitude: -8.22, continentISO: "EU", glowRadiusRadians: 0.040, isTiny: true),
    .init(iso2: "GR", name: "Greece",         latitude: 39.07, longitude: 21.82, continentISO: "EU", glowRadiusRadians: 0.045, isTiny: false),
    .init(iso2: "AT", name: "Austria",        latitude: 47.52, longitude: 14.55, continentISO: "EU", glowRadiusRadians: 0.030, isTiny: true),
    .init(iso2: "BE", name: "Belgium",        latitude: 50.50, longitude: 4.47,  continentISO: "EU", glowRadiusRadians: 0.025, isTiny: true),
    .init(iso2: "CZ", name: "Czechia",        latitude: 49.82, longitude: 15.47, continentISO: "EU", glowRadiusRadians: 0.030, isTiny: true),
    .init(iso2: "RO", name: "Romania",        latitude: 45.94, longitude: 24.97, continentISO: "EU", glowRadiusRadians: 0.045, isTiny: false),
    .init(iso2: "UA", name: "Ukraine",        latitude: 48.38, longitude: 31.17, continentISO: "EU", glowRadiusRadians: 0.075, isTiny: false),

    // Africa
    .init(iso2: "ZA", name: "South Africa", latitude: -30.56, longitude: 22.94, continentISO: "AF", glowRadiusRadians: 0.085, isTiny: false),
    .init(iso2: "NG", name: "Nigeria",      latitude: 9.08,   longitude: 8.68,  continentISO: "AF", glowRadiusRadians: 0.075, isTiny: false),
    .init(iso2: "EG", name: "Egypt",        latitude: 26.82,  longitude: 30.80, continentISO: "AF", glowRadiusRadians: 0.075, isTiny: false),
    .init(iso2: "KE", name: "Kenya",        latitude: -0.02,  longitude: 37.91, continentISO: "AF", glowRadiusRadians: 0.060, isTiny: false),
    .init(iso2: "MA", name: "Morocco",      latitude: 31.79,  longitude: -7.09, continentISO: "AF", glowRadiusRadians: 0.060, isTiny: false),
    .init(iso2: "ET", name: "Ethiopia",     latitude: 9.15,   longitude: 40.49, continentISO: "AF", glowRadiusRadians: 0.080, isTiny: false),
    .init(iso2: "GH", name: "Ghana",        latitude: 7.95,   longitude: -1.02, continentISO: "AF", glowRadiusRadians: 0.045, isTiny: false),
    .init(iso2: "TZ", name: "Tanzania",     latitude: -6.37,  longitude: 34.89, continentISO: "AF", glowRadiusRadians: 0.075, isTiny: false),

    // North America
    .init(iso2: "US", name: "United States", latitude: 39.83, longitude: -98.58, continentISO: "NA", glowRadiusRadians: 0.180, isTiny: false),
    .init(iso2: "CA", name: "Canada",        latitude: 56.13, longitude: -106.35,continentISO: "NA", glowRadiusRadians: 0.210, isTiny: false),
    .init(iso2: "MX", name: "Mexico",        latitude: 23.63, longitude: -102.55,continentISO: "NA", glowRadiusRadians: 0.090, isTiny: false),
    .init(iso2: "GT", name: "Guatemala",     latitude: 15.78, longitude: -90.23, continentISO: "NA", glowRadiusRadians: 0.030, isTiny: true),
    .init(iso2: "CR", name: "Costa Rica",    latitude: 9.75,  longitude: -83.75, continentISO: "NA", glowRadiusRadians: 0.025, isTiny: true),
    .init(iso2: "PA", name: "Panama",        latitude: 8.54,  longitude: -80.78, continentISO: "NA", glowRadiusRadians: 0.025, isTiny: true),
    .init(iso2: "CU", name: "Cuba",          latitude: 21.52, longitude: -77.78, continentISO: "NA", glowRadiusRadians: 0.030, isTiny: true),

    // South America
    .init(iso2: "BR", name: "Brazil",     latitude: -14.24, longitude: -51.93, continentISO: "SA", glowRadiusRadians: 0.180, isTiny: false),
    .init(iso2: "AR", name: "Argentina",  latitude: -38.42, longitude: -63.62, continentISO: "SA", glowRadiusRadians: 0.130, isTiny: false),
    .init(iso2: "CL", name: "Chile",      latitude: -35.68, longitude: -71.54, continentISO: "SA", glowRadiusRadians: 0.090, isTiny: false),
    .init(iso2: "CO", name: "Colombia",   latitude: 4.57,   longitude: -74.30, continentISO: "SA", glowRadiusRadians: 0.080, isTiny: false),
    .init(iso2: "PE", name: "Peru",       latitude: -9.19,  longitude: -75.02, continentISO: "SA", glowRadiusRadians: 0.090, isTiny: false),
    .init(iso2: "VE", name: "Venezuela",  latitude: 6.42,   longitude: -66.59, continentISO: "SA", glowRadiusRadians: 0.080, isTiny: false),
    .init(iso2: "EC", name: "Ecuador",    latitude: -1.83,  longitude: -78.18, continentISO: "SA", glowRadiusRadians: 0.045, isTiny: false),
    .init(iso2: "UY", name: "Uruguay",    latitude: -32.52, longitude: -55.77, continentISO: "SA", glowRadiusRadians: 0.035, isTiny: true),

    // Oceania
    .init(iso2: "AU", name: "Australia",   latitude: -25.27, longitude: 133.78, continentISO: "OC", glowRadiusRadians: 0.160, isTiny: false),
    .init(iso2: "NZ", name: "New Zealand", latitude: -40.90, longitude: 174.89, continentISO: "OC", glowRadiusRadians: 0.060, isTiny: false),
    .init(iso2: "FJ", name: "Fiji",        latitude: -17.71, longitude: 178.07, continentISO: "OC", glowRadiusRadians: 0.022, isTiny: true),
    .init(iso2: "PG", name: "Papua New Guinea", latitude: -6.31, longitude: 143.96, continentISO: "OC", glowRadiusRadians: 0.060, isTiny: false),
  ]

  private let continentCenters: [String: ContinentCenter]

  // MARK: - Init

  private init() {
    let centers: [String: (Float, Float, Float)] = [
      "AS": (45,  90,  0.30),
      "EU": (52,  15,  0.18),
      "AF": (5,   20,  0.27),
      "NA": (45, -100, 0.27),
      "SA": (-15,-60,  0.22),
      "OC": (-25,140,  0.18),
      "AN": (-80, 0,   0.10),
    ]
    var map: [String: ContinentCenter] = [:]
    for (k, v) in centers {
      let unit = sphereUnitVector(latDeg: v.0, lonDeg: v.1)
      map[k] = ContinentCenter(iso: k, unitVector: unit, angularRadius: v.2)
    }
    self.continentCenters = map
  }

  // MARK: - Lookup

  func country(forISO iso: String) -> Country? {
    countries.first { $0.iso2.caseInsensitiveCompare(iso) == .orderedSame }
  }

  func continentCenter(_ iso: String) -> ContinentCenter? {
    continentCenters[iso.uppercased()]
  }

  /// Nearest country (great-circle distance) to a lat/lon, within `degrees`.
  func nearestCountry(lat: Float, lon: Float, withinDegrees: Float) -> Country? {
    let target = sphereUnitVector(latDeg: lat, lonDeg: lon)
    var best: (Country, Float)?
    for c in countries {
      let cos = simd_dot(c.unitVector, target)
      let angle = acosf(max(-1, min(1, cos)))
      let deg = angle * 180 / .pi
      if let (_, bestDeg) = best {
        if deg < bestDeg { best = (c, deg) }
      } else {
        best = (c, deg)
      }
    }
    guard let (c, deg) = best, deg <= withinDegrees else { return nil }
    return c
  }

  /// All countries (for the debug harness's slider list).
  var allCountries: [Country] { countries }
}
