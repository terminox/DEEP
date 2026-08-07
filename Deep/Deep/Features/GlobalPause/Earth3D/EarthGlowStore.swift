import Foundation
import SwiftUI
import simd

/// Live participant presence → smoothed gaussian glow sources on the orb's surface.
///
/// Two families of light share one GPU pipeline:
/// - **Steady cells** — server-clustered lat/lon points (or country blobs when
///   a participant couldn't be located), lerped over 800ms so polls crossfade.
/// - **Sparks** — transient flares at the exact spot someone just joined,
///   living ~2s in the same glow buffer so they bloom, occlude on the back
///   hemisphere, and ride the sphere's rotation like every other light.
///
/// Why gaussians instead of a country-ID texture: simpler v1 (no GIS pipeline),
/// scales to the data we'll actually have, and the smooth angular falloff
/// already reads as "ink-in-water bloom" — which is exactly the design intent.
@MainActor
@Observable
final class EarthGlowStore {

  // MARK: - Public input

  /// Located participants as clustered lat/lon points. Non-empty input wins
  /// over `participantsByCountry` (which then only serves `unlocatedByCountry`
  /// via the country branch).
  var locations: [PauseLiveSnapshot.GeoPoint] = [] {
    didSet { recomputeTargets() }
  }

  /// Participants the server couldn't geolocate, keyed by ISO-alpha2 code —
  /// rendered as the classic country-centroid blobs alongside the points.
  var unlocatedByCountry: [String: Int] = [:] {
    didSet { recomputeTargets() }
  }

  /// Legacy input: live participant counts keyed by ISO-alpha2 code. Still the
  /// whole picture when the server predates `locations`.
  /// TODO: delete once /pause/live locations is universal.
  var participantsByCountry: [String: Int] = [:] {
    didSet { recomputeTargets() }
  }

  /// *This* user's location. Rendered as a persistently brighter glow that
  /// breathes gently, so you can always find yourself on the world.
  var homeLocation: PauseJoinPoint? {
    didSet { recomputeTargets() }
  }

  /// Optional ceiling for log scaling. If nil, derived from the largest value seen.
  var globalMaxOverride: Int?

  // MARK: - GPU-facing state

  /// Up-to-date GPU sources, lerped toward target. Renderer queries each frame.
  private var sources: [SourceState] = []
  private var sparks: [SparkState] = []
  private var lastTickTime: TimeInterval?

  /// Per-source lerp time constant (seconds).
  private let lerpTau: Float = 0.8

  // MARK: - Point tuning

  /// A lone person must clearly read, so intensity starts high and count only
  /// nudges it — the log-over-global-max scale used for country totals would
  /// bury count=1 cells entirely.
  private let pointSoftCap: Float = 6
  private let pointBaseIntensity: Float = 0.65
  private let pointIntensityGain: Float = 0.30
  /// Point radii sit well under country blobs (0.05–0.22 rad) so cities read
  /// as candle-points, not weather systems.
  private let pointBaseRadius: Float = 0.034
  private let pointRadiusGain: Float = 0.014

  // MARK: - Home ("you are here") tuning

  private static let homeKey = "home"
  private let homeIntensity: Float = 0.9
  private let homeRadius: Float = 0.045
  /// Warm-cream cast that separates "you" from your neighbors.
  private let homeWhiteness: Float = 0.15
  /// Gentle breath: ±13% at ~10s period, modulated per-frame in
  /// `currentGPUSources` so the lerped base stays stable.
  private let homeBreathAmplitude: Float = 0.13
  private let homeBreathRate: Float = 0.63  // rad/s ≈ 10s period

  // MARK: - Spark tuning

  /// Spark lifetime: flare in ~120ms, settle into lavender, gone by 2s —
  /// by which time the next poll's steady cell has taken over.
  private let sparkLife: Float = 2.0
  private let sparkCap = 12
  private let sparkRadius: Float = 0.030
  /// Peak 1.3 is safe by construction: the shader compresses accumulated glow
  /// with 1 − exp(−total·1.2), so even a full-intensity spark lands ~0.79 —
  /// bright, but structurally incapable of blowing out to white under bloom.
  private let sparkPeak: Float = 1.3

  // MARK: - Init

  init() {}

  // MARK: - Per-frame integration (called by host's onFrame callback)

  func tick(time: TimeInterval) {
    let dt: Float
    if let prev = lastTickTime {
      dt = Float(min(time - prev, 0.05))  // clamp to avoid huge steps on resume
    } else {
      dt = 0
    }
    lastTickTime = time
    guard dt > 0 else { return }

    // Exponential approach: current += (target - current) * (1 - exp(-dt/tau))
    let k = 1 - expf(-dt / lerpTau)
    for i in sources.indices {
      sources[i].currentIntensity += (sources[i].targetIntensity - sources[i].currentIntensity) * k
    }

    // Sparks age on the same clock and expire on their own.
    for i in sparks.indices {
      sparks[i].age += dt
    }
    sparks.removeAll { $0.age > sparkLife }
  }

  /// Renderer-facing snapshot. Only sources above an intensity threshold are
  /// uploaded — saves the shader from doing N gaussian falloffs for zeros.
  /// Sparks always survive the 64-source budget; when steady cells overflow
  /// what's left, the dimmest are dropped first (invisible for the ~2s a
  /// spark is in flight).
  func currentGPUSources() -> [GlowSourceGPU] {
    let sparkGPU: [GlowSourceGPU] = sparks.compactMap { s in
      let intensity = sparkIntensity(age: s.age)
      guard intensity > 0.003 else { return nil }
      return GlowSourceGPU(
        positionAndIntensity: SIMD4<Float>(s.position.x, s.position.y, s.position.z, intensity),
        radiusPacked: SIMD4<Float>(sparkRadius, sparkWhiteness(age: s.age), 0, 0)
      )
    }

    let budget = max(0, EarthRendererConstants.maxGlowSources - sparkGPU.count)
    let homeBreath = 1 + homeBreathAmplitude * sinf(Float(lastTickTime ?? 0) * homeBreathRate)
    let steady = sources
      .filter { $0.currentIntensity > 0.003 }
      .sorted { $0.currentIntensity > $1.currentIntensity }
      .prefix(budget)
      .map { s in
        let isHome = s.key == Self.homeKey
        return GlowSourceGPU(
          positionAndIntensity: SIMD4<Float>(
            s.position.x, s.position.y, s.position.z,
            isHome ? s.currentIntensity * homeBreath : s.currentIntensity
          ),
          radiusPacked: SIMD4<Float>(s.angularRadius, isHome ? homeWhiteness : 0, 0, 0)
        )
      }
    return steady + sparkGPU
  }

  var activeSourceCount: Int {
    sources.reduce(0) { $0 + ($1.currentIntensity > 0.003 ? 1 : 0) }
  }

  // MARK: - Join sparks

  /// A person just joined at these coordinates: flare a transient glow source
  /// there. The steady cell arrives with the next poll and takes over as the
  /// spark decays.
  func spark(lat: Float, lon: Float) {
    if sparks.count >= sparkCap { sparks.removeFirst() }
    sparks.append(SparkState(position: sphereUnitVector(latDeg: lat, lonDeg: lon), age: 0))
  }

  /// Attack over 120ms, exponential decay — peaks bright, settles fast.
  private func sparkIntensity(age: Float) -> Float {
    let attack = smoothstep(0, 0.12, age)
    let decay = expf(-max(0, age - 0.12) / 0.6)
    return attack * decay * sparkPeak
  }

  /// The moon-cream push dies faster than the intensity, so the spark visibly
  /// "settles into lavender" before it fades out.
  private func sparkWhiteness(age: Float) -> Float {
    smoothstep(0, 0.1, age) * expf(-age / 0.45)
  }

  // MARK: - Target recomputation

  private func recomputeTargets() {
    var newSources: [SourceState] = []
    newSources.reserveCapacity(locations.count + unlocatedByCountry.count + 8)

    // "You are here" — present in every branch, brighter than any neighbor.
    if let home = homeLocation {
      newSources.append(SourceState(
        key: Self.homeKey,
        position: sphereUnitVector(latDeg: home.lat, lonDeg: home.lon),
        angularRadius: homeRadius,
        targetIntensity: homeIntensity,
        currentIntensity: existingCurrent(for: Self.homeKey) ?? 0
      ))
    }

    appendPointSources(into: &newSources)

    // Country blobs: the whole world on an old server, or just the participants
    // IP geolocation couldn't place on a new one.
    let countryCounts = (locations.isEmpty && unlocatedByCountry.isEmpty)
      ? participantsByCountry
      : unlocatedByCountry
    appendCountrySources(countryCounts, into: &newSources)

    // Preserve sources whose input just vanished so they can fade out smoothly.
    let activeKeys = Set(newSources.map(\.key))
    for old in sources where !activeKeys.contains(old.key) && old.currentIntensity > 0.003 {
      var fading = old
      fading.targetIntensity = 0
      newSources.append(fading)
    }

    sources = newSources
  }

  /// Server points → steady cells. Keyed by a 0.25° quantized cell — half the
  /// server's 1° cluster grid — so the same city lands on the same key across
  /// polls and its glow lerps instead of popping. A cell that shifts across a
  /// key boundary crossfades (old fades out, new fades in) over the lerp tau.
  private func appendPointSources(into newSources: inout [SourceState]) {
    struct Cell {
      var lat: Float
      var lon: Float
      var count: Int
    }
    var cells: [String: Cell] = [:]
    for point in locations where point.count > 0 {
      let key = Self.cellKey(lat: point.lat, lon: point.lon)
      if var cell = cells[key] {
        // Two server clusters in one client cell: merge at the count-weighted mean.
        let oldWeight = Float(cell.count)
        let newWeight = Float(point.count)
        let total = oldWeight + newWeight
        cell.lat = (cell.lat * oldWeight + point.lat * newWeight) / total
        cell.lon = (cell.lon * oldWeight + point.lon * newWeight) / total
        cell.count += point.count
        cells[key] = cell
      } else {
        cells[key] = Cell(lat: point.lat, lon: point.lon, count: point.count)
      }
    }

    for (key, cell) in cells {
      let normalized = min(1, log2(Float(cell.count) + 1) / log2(pointSoftCap + 1))
      newSources.append(SourceState(
        key: key,
        position: sphereUnitVector(latDeg: cell.lat, lonDeg: cell.lon),
        angularRadius: pointBaseRadius + pointRadiusGain * normalized,
        targetIntensity: pointBaseIntensity + pointIntensityGain * normalized,
        currentIntensity: existingCurrent(for: key) ?? 0
      ))
    }
  }

  private static func cellKey(lat: Float, lon: Float) -> String {
    "pt:\(Int((lat * 4).rounded()))|\(Int((lon * 4).rounded()))"
  }

  /// The classic country-centroid path: log-scaled against the global max,
  /// tiny countries splashing into their continent so they register at orb scale.
  private func appendCountrySources(_ counts: [String: Int], into newSources: inout [SourceState]) {
    let lookup = CountryLookup.shared
    let globalMax = max(1, globalMaxOverride ?? counts.values.max() ?? 1)
    let logMax = log(Float(globalMax) + 1)

    // Continent splash buckets (small-country fallback).
    var continentSplash: [String: Float] = [:]

    for (iso, count) in counts where count > 0 {
      guard let country = lookup.country(forISO: iso) else { continue }
      let normalized = log(Float(count) + 1) / logMax  // 0...1
      let intensity = smoothstep(0, 1, normalized)

      // Direct country source.
      newSources.append(SourceState(
        key: iso,
        position: country.unitVector,
        angularRadius: country.glowRadiusRadians,
        targetIntensity: intensity,
        currentIntensity: existingCurrent(for: iso) ?? 0
      ))

      // Tiny countries also splash into their continent so they register at orb scale.
      if country.isTiny {
        continentSplash[country.continentISO, default: 0] += intensity * 0.35
      }
    }

    // Add continent-level sources (clamped to 1.0).
    for (cont, totalSplash) in continentSplash {
      guard let center = lookup.continentCenter(cont) else { continue }
      let intensity = min(1.0, totalSplash)
      newSources.append(SourceState(
        key: "__CONT__\(cont)",
        position: center.unitVector,
        angularRadius: center.angularRadius,
        targetIntensity: intensity,
        currentIntensity: existingCurrent(for: "__CONT__\(cont)") ?? 0
      ))
    }
  }

  private func existingCurrent(for key: String) -> Float? {
    sources.first(where: { $0.key == key })?.currentIntensity
  }

  // MARK: - State nodes

  private struct SourceState {
    var key: String
    var position: SIMD3<Float>
    var angularRadius: Float
    var targetIntensity: Float
    var currentIntensity: Float
  }

  private struct SparkState {
    let position: SIMD3<Float>
    var age: Float
  }
}

private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
  let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
  return t * t * (3 - 2 * t)
}

// MARK: - Preview helpers

extension EarthGlowStore {
  static var previewCalm: EarthGlowStore { EarthGlowStore() }

  /// Country-blob world — exercises the legacy/unlocated branch.
  static var previewActive: EarthGlowStore {
    let store = EarthGlowStore()
    store.participantsByCountry = [
      "TH":  1_240,
      "JP":    980,
      "US":  3_410,
      "FR":    870,
      "BR":  1_120,
      "IN":  2_300,
      "ID":    640,
      "GB":    520,
      "DE":    410,
      "AU":    180,
      "ZA":    120,
      "MX":    280,
      "KR":    560,
      "SG":     90,
    ]
    store.seedCurrentsAtTargets()
    return store
  }

  /// Point-glow world — ~20 cities at small counts, the shape live data
  /// actually takes with IP-located participants.
  static var previewCities: EarthGlowStore {
    let store = EarthGlowStore()
    store.homeLocation = PauseJoinPoint(lat: 13.8, lon: 100.5)  // Bangkok
    store.locations = Self.sampleCities
    store.seedCurrentsAtTargets()
    return store
  }

  static let sampleCities: [PauseLiveSnapshot.GeoPoint] = [
    .init(lat: 13.8, lon: 100.5, count: 3),    // Bangkok
    .init(lat: 35.7, lon: 139.7, count: 2),    // Tokyo
    .init(lat: 35.0, lon: 135.8, count: 1),    // Kyoto
    .init(lat: 37.6, lon: 127.0, count: 1),    // Seoul
    .init(lat: 1.4, lon: 103.8, count: 1),     // Singapore
    .init(lat: 19.1, lon: 72.9, count: 2),     // Mumbai
    .init(lat: 25.2, lon: 55.3, count: 1),     // Dubai
    .init(lat: 41.0, lon: 29.0, count: 1),     // Istanbul
    .init(lat: 48.9, lon: 2.4, count: 2),      // Paris
    .init(lat: 51.5, lon: -0.1, count: 3),     // London
    .init(lat: 52.5, lon: 13.4, count: 1),     // Berlin
    .init(lat: 59.3, lon: 18.1, count: 1),     // Stockholm
    .init(lat: 6.5, lon: 3.4, count: 1),       // Lagos
    .init(lat: -1.3, lon: 36.8, count: 1),     // Nairobi
    .init(lat: 30.0, lon: 31.2, count: 1),     // Cairo
    .init(lat: 40.7, lon: -74.0, count: 3),    // New York
    .init(lat: 34.1, lon: -118.2, count: 2),   // Los Angeles
    .init(lat: 19.4, lon: -99.1, count: 1),    // Mexico City
    .init(lat: -23.6, lon: -46.6, count: 2),   // São Paulo
    .init(lat: -34.6, lon: -58.4, count: 1),   // Buenos Aires
    .init(lat: -33.9, lon: 151.2, count: 2),   // Sydney
    .init(lat: -41.3, lon: 174.8, count: 1),   // Wellington
  ]

  /// Seed the current intensities at target so previews show full bloom
  /// immediately instead of fading in over 800ms.
  private func seedCurrentsAtTargets() {
    for i in sources.indices {
      sources[i].currentIntensity = sources[i].targetIntensity
    }
  }
}
