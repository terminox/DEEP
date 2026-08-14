import Foundation
import SwiftUI
import simd

/// One frame's GPU upload: the packed sources plus the style-range counts the
/// shader needs to loop each range with its own math (see `GlowSourceGPU`).
struct EarthGlowSnapshot {
  var sources: [GlowSourceGPU] = []
  var classicCount: Int = 0
  var orbCount: Int = 0
}

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

  // MARK: - Tuning

  /// Every tunable constant in one struct: the DEBUG panel gets per-field
  /// sliders, reset is `tuning = Tuning()`, and defaults live once as the
  /// member initializers (the shipped look).
  struct Tuning: Codable, Equatable {
    /// Per-source lerp time constant (seconds).
    var lerpTau: Float = 0.8

    /// Region granularity — map located participants (and their join sparks)
    /// to whole-region blobs from CountryLookup's hand-tuned table instead of
    /// point cells, so a single join can light its country or continent. The
    /// shader's land mask clips the gaussian to coastlines, so the region
    /// reads as lit land rather than a round blob.
    enum Granularity: String, CaseIterable, Codable { case point, country, continent }
    var granularity: Granularity = .point
    /// Inflates region blob radii — country mode at ~2× reads as sub-region
    /// (SEA-ish) coverage.
    var regionRadiusScale: Float = 1.0

    // Point cells — a lone person must clearly read, so intensity starts high
    // and count only nudges it; the log-over-global-max scale used for country
    // totals would bury count=1 cells entirely.
    var pointSoftCap: Float = 6
    var pointBaseIntensity: Float = 0.65
    var pointIntensityGain: Float = 0.30
    /// Point radii sit well under country blobs (0.05–0.22 rad) so cities read
    /// as candle-points, not weather systems.
    var pointBaseRadius: Float = 0.034
    var pointRadiusGain: Float = 0.014

    // Home ("you are here").
    var homeIntensity: Float = 0.9
    var homeRadius: Float = 0.045
    /// Warm-cream cast that separates "you" from your neighbors.
    var homeWhiteness: Float = 0.15
    /// Gentle breath: ±13% at ~10s period, modulated per-frame in
    /// `currentGPUSnapshot` so the lerped base stays stable.
    var homeBreathAmplitude: Float = 0.13
    var homeBreathRate: Float = 0.63  // rad/s ≈ 10s period

    // MARK: 3D styles
    /// Steady glow rendering: classic surface gaussians, or volumetric light
    /// spheres (see accumulateLightVolumes in EarthSurface.metal) — `orb`
    /// floats just above the surface, `dome` seats the gaussian centre on the
    /// surface and clips the buried half away, `buried` seats it on the
    /// surface unclipped so the planet body hides the under-glow except near
    /// the limb. Switches the GPU packing range (and mode channel) per source.
    enum GlowPointStyle: String, CaseIterable, Codable { case classic, orb, dome, buried }
    var glowPointStyle: GlowPointStyle = .classic
    /// Join spark rendering: classic surface flare (+ the 2D ripple ring), a
    /// 3D flash + expanding light shell, or a twinkling star (scintillating
    /// point). The scene suppresses the 2D ring unless this is `.classic`.
    /// Region-mode sparks keep the global `shellMaxRadius` — no per-region
    /// shell sizing in v1.
    enum SparkStyle: String, CaseIterable, Codable { case classic, flashShell, twinkle }
    var sparkStyle: SparkStyle = .classic

    // Join sparks. Lifetime: flare in ~120ms, settle into lavender, gone by
    // 2s — by which time the next poll's steady cell has taken over.
    var sparkLife: Float = 2.0
    /// Insertion gate only (no storage preallocated to it) — keep well under
    /// `maxGlowSources` so sparks can't starve steady cells of GPU slots.
    /// A `.flashShell` spark packs up to 3 GPU sources (seat + flash + shell),
    /// so the cap stays low enough that a join storm can't eat the buffer.
    var sparkCap = 8
    var sparkRadius: Float = 0.030
    /// Peak 1.3 is safe by construction: the shader compresses accumulated
    /// glow with 1 − exp(−total·k), so even a full-intensity spark lands ~0.79
    /// — bright, but structurally incapable of blowing out to white under bloom.
    var sparkPeak: Float = 1.3

    // Volumetric column heights (radiusPacked.z, a multiplier on the shader's
    // scale height — see volumetricShell in EarthSurface.metal).
    /// Home glow column height (>1 = taller than ordinary cells).
    var homeColumnHeight: Float = 1.35
    /// Extra column height at spark birth, decaying on the whiteness
    /// envelope's ~0.45s time constant — a fresh join visibly throws light
    /// upward, then settles together with the cream flash.
    var sparkColumnBoost: Float = 1.5

    // MARK: Flash + shell burst (CPU envelopes; inert while sparkStyle is classic)
    /// Peak intensity of the ignition flash orb.
    var flashPeak: Float = 1.8
    /// Exponential decay of the flash — dead by ~3–4× this (seconds).
    var flashDecay: Float = 0.12
    /// Flash orb σ in world units (sphere radius = 1).
    var flashRadius: Float = 0.05
    /// Seconds for the shell to reach full expansion (easeOutCubic arrival).
    var shellLife: Float = 1.4
    /// Full-expansion shell radius in world units. 0.42 keeps the whole
    /// bubble inside the frame with bloom headroom at every seat position.
    var shellMaxRadius: Float = 0.42
    /// Shell gaussian thickness at birth (world units)…
    var shellThicknessBase: Float = 0.010
    /// …growing with radius, so the front visibly thins out relative to its
    /// size as it expands (thickness = base + grow · R).
    var shellThicknessGrow: Float = 0.045
    /// Peak shell intensity, reached just after the flash hands off.
    var shellPeak: Float = 1.15
    /// Brightness fade exponent over expansion: (1 − progress)^power.
    var shellFadePower: Float = 1.5
    /// Moon-cream whiteness decay shared by flash and shell (seconds).
    var whiteTau: Float = 0.35

    // MARK: Twinkle spark (CPU envelope; inert while the spark style isn't twinkle)
    /// Seconds until the twinkle lands at zero (hard tail over the last 0.3s).
    var twinkleLife: Float = 1.6
    /// Peak intensity — hot by design so the shimmering core drives bloom.
    var twinklePeak: Float = 2.2
    /// σ of the star point in world units — well under `flashRadius`, a pinpoint.
    var twinkleRadius: Float = 0.022
    /// Base scintillation frequency (Hz); two overtones ride at ×1.73/×2.71.
    var twinkleSpeed: Float = 10
    /// Shimmer excursion ±depth around the envelope (0.95 max keeps it positive).
    var twinkleDepth: Float = 0.6
    /// Share of the shimmer that also modulates σ — the star visibly breathes.
    var twinkleSizeJitter: Float = 0.25
    /// Exponential decay time constant after the attack (seconds).
    var twinkleDecay: Float = 0.45
  }

  /// Point/home values are baked into lerp *targets*, so any change must
  /// recompute them; existing currents survive and re-lerp over `lerpTau`.
  var tuning = Tuning() {
    didSet { recomputeTargets() }
  }

  // MARK: - GPU-facing state

  /// Up-to-date GPU sources, lerped toward target. Renderer queries each frame.
  private var sources: [SourceState] = []
  private var sparks: [SparkState] = []
  private var lastTickTime: TimeInterval?

  private static let homeKey = "home"

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
    let k = 1 - expf(-dt / tuning.lerpTau)
    for i in sources.indices {
      sources[i].currentIntensity += (sources[i].targetIntensity - sources[i].currentIntensity) * k
    }

    // Sparks age on the same clock and expire on their own. In flash-shell
    // style the shell outlives the classic envelope, so the spark stays alive
    // until the longer of the two.
    for i in sparks.indices {
      sparks[i].age += dt
    }
    let life = effectiveSparkLife
    sparks.removeAll { $0.age > life }
  }

  private var effectiveSparkLife: Float {
    switch tuning.sparkStyle {
    case .classic: return tuning.sparkLife
    case .flashShell: return max(tuning.sparkLife, tuning.shellLife)
    case .twinkle: return max(tuning.sparkLife, tuning.twinkleLife)
    }
  }

  /// Renderer-facing snapshot, sorted into the three style ranges the shader
  /// loops separately: classic surface gaussians, volumetric orbs, expanding
  /// shells (see `GlowSourceGPU`). Only sources above an intensity threshold
  /// are uploaded — saves the shader from doing N falloffs for zeros.
  /// Sparks always survive the 64-source budget; when steady cells overflow
  /// what's left, the dimmest are dropped first (invisible for the ~2s a
  /// spark is in flight).
  func currentGPUSnapshot() -> EarthGlowSnapshot {
    var classicRange: [GlowSourceGPU] = []
    var orbRange: [GlowSourceGPU] = []
    var shellRange: [GlowSourceGPU] = []

    for s in sparks {
      // The classic surface flare stays in every style — under a flash+shell
      // burst it's the seat that keeps the land kissed by light.
      if let seat = classicSparkGPU(s) { classicRange.append(seat) }
      if tuning.sparkStyle == .flashShell {
        if let flash = flashOrbGPU(s) { orbRange.append(flash) }
        if let shell = shellGPU(s) { shellRange.append(shell) }
      }
      if tuning.sparkStyle == .twinkle {
        if let star = twinkleOrbGPU(s) { orbRange.append(star) }
      }
    }

    let sparkSlots = classicRange.count + orbRange.count + shellRange.count
    let budget = max(0, EarthRendererConstants.maxGlowSources - sparkSlots)
    let homeBreath = 1 + tuning.homeBreathAmplitude * sinf(Float(lastTickTime ?? 0) * tuning.homeBreathRate)
    let orbStyle = tuning.glowPointStyle != .classic
    // Per-source style mode for the shader's orb loop (radiusPacked.z):
    // 0 = elevated full orb, 1 = surface dome, 2 = buried sphere.
    let orbMode: Float
    switch tuning.glowPointStyle {
    case .classic, .orb: orbMode = 0
    case .dome: orbMode = 1
    case .buried: orbMode = 2
    }
    let steady = sources
      .filter { $0.currentIntensity > 0.003 }
      .sorted { $0.currentIntensity > $1.currentIntensity }
      .prefix(budget)
      .map { s -> GlowSourceGPU in
        let isHome = s.key == Self.homeKey
        let position = SIMD4<Float>(
          s.position.x, s.position.y, s.position.z,
          isHome ? s.currentIntensity * homeBreath : s.currentIntensity
        )
        if orbStyle {
          // Angular σ ≈ world arc σ on the unit sphere; the clamp stops
          // region blobs (~0.3 rad) becoming 0.3-world-unit light balls.
          return GlowSourceGPU(
            positionAndIntensity: position,
            radiusPacked: SIMD4<Float>(
              min(max(s.angularRadius, 0.018), 0.055),
              isHome ? tuning.homeWhiteness : 0,
              orbMode,
              1
            )
          )
        }
        return GlowSourceGPU(
          positionAndIntensity: position,
          radiusPacked: SIMD4<Float>(
            s.angularRadius,
            isHome ? tuning.homeWhiteness : 0,
            isHome ? tuning.homeColumnHeight : 1,
            0
          )
        )
      }

    // Steadies join their style's range; ordering inside a range is free but
    // ranges must stay contiguous — the shader receives only the two counts.
    var classic = orbStyle ? [] : Array(steady)
    classic += classicRange
    var orbs = orbStyle ? Array(steady) : []
    orbs += orbRange
    return EarthGlowSnapshot(
      sources: classic + orbs + shellRange,
      classicCount: classic.count,
      orbCount: orbs.count
    )
  }

  var activeSourceCount: Int {
    sources.reduce(0) { $0 + ($1.currentIntensity > 0.003 ? 1 : 0) }
  }

  // MARK: - Join sparks

  /// A person just joined at these coordinates: flare a transient glow source
  /// there. The steady cell arrives with the next poll and takes over as the
  /// spark decays. In region mode the whole region blob flashes — a Thailand
  /// join lights Thailand, not a point in Bangkok.
  func spark(lat: Float, lon: Float) {
    if sparks.count >= tuning.sparkCap { sparks.removeFirst() }
    let region = regionFor(lat: lat, lon: lon)
    sparks.append(SparkState(
      position: region?.position ?? sphereUnitVector(latDeg: lat, lonDeg: lon),
      radius: region?.radius ?? tuning.sparkRadius,
      seed: Float.random(in: 0..<(2 * .pi)),
      age: 0
    ))
  }

  /// Attack over 120ms, exponential decay — peaks bright, settles fast.
  private func sparkIntensity(age: Float) -> Float {
    let attack = smoothstep(0, 0.12, age)
    let decay = expf(-max(0, age - 0.12) / 0.6)
    return attack * decay * tuning.sparkPeak
  }

  /// The moon-cream push dies faster than the intensity, so the spark visibly
  /// "settles into lavender" before it fades out.
  private func sparkWhiteness(age: Float) -> Float {
    smoothstep(0, 0.1, age) * expf(-age / 0.45)
  }

  // MARK: - Spark GPU packing (one entry per style range; see GlowSourceGPU)

  /// The classic surface flare — identical packing in every spark style.
  private func classicSparkGPU(_ s: SparkState) -> GlowSourceGPU? {
    let intensity = sparkIntensity(age: s.age)
    guard intensity > 0.003 else { return nil }
    return GlowSourceGPU(
      positionAndIntensity: SIMD4<Float>(s.position.x, s.position.y, s.position.z, intensity),
      radiusPacked: SIMD4<Float>(
        s.radius,
        sparkWhiteness(age: s.age),
        1 + tuning.sparkColumnBoost * expf(-s.age / 0.45),
        0
      )
    )
  }

  /// The ignition flash — a hot, short-lived volumetric orb at the join point.
  private func flashOrbGPU(_ s: SparkState) -> GlowSourceGPU? {
    let flash = smoothstep(0, 0.05, s.age) * expf(-s.age / max(tuning.flashDecay, 0.01)) * tuning.flashPeak
    guard flash > 0.003 else { return nil }
    return GlowSourceGPU(
      positionAndIntensity: SIMD4<Float>(s.position.x, s.position.y, s.position.z, flash),
      radiusPacked: SIMD4<Float>(tuning.flashRadius, expf(-s.age / tuning.whiteTau), 0, 1)
    )
  }

  /// A twinkling star at the join: a hot orb-range point whose brightness
  /// (and slightly size) shimmers irregularly on a per-spark random phase
  /// while the attack→decay envelope plays out. Entirely CPU-side — the
  /// shader sees a fresh intensity/σ each frame, exactly like the flash orb.
  /// Mode 0 (elevated full orb) so the star sits proud of the crust.
  private func twinkleOrbGPU(_ s: SparkState) -> GlowSourceGPU? {
    let attack = smoothstep(0, 0.06, s.age)
    let decay = expf(-max(0, s.age - 0.06) / max(tuning.twinkleDecay, 0.05))
    // Hard tail: the exponential alone still carries ~3% of peak at end of
    // life, which would pop on removal — land at exactly zero instead.
    let tail = 1 - smoothstep(max(tuning.twinkleLife - 0.3, 0.05), tuning.twinkleLife, s.age)
    let flicker = twinkleFlicker(age: s.age, seed: s.seed)
    let intensity = attack * decay * tail * flicker * tuning.twinklePeak
    guard intensity > 0.003 else { return nil }
    let sigma = tuning.twinkleRadius * (1 + tuning.twinkleSizeJitter * (flicker - 1))
    return GlowSourceGPU(
      positionAndIntensity: SIMD4<Float>(s.position.x, s.position.y, s.position.z, intensity),
      radiusPacked: SIMD4<Float>(sigma, expf(-s.age / tuning.whiteTau), 0, 1)
    )
  }

  /// Scintillation: three incommensurate sines (1 : 1.73 : 2.71) with
  /// seed-decorrelated phases — mean 1, excursion ±twinkleDepth, never
  /// periodic within a spark's life, deterministic per spark.
  private func twinkleFlicker(age: Float, seed: Float) -> Float {
    let w = age * tuning.twinkleSpeed * 2 * .pi
    let shimmer = 0.5 * sinf(w + seed)
                + 0.3 * sinf(w * 1.73 + seed * 2.39)
                + 0.2 * sinf(w * 2.71 + seed * 4.63)
    return 1 + tuning.twinkleDepth * shimmer
  }

  /// The expanding light shell: fast start, decelerating arrival at
  /// `shellMaxRadius`, thinning front, brightness handed off from the flash
  /// and landing at exactly zero as expansion completes.
  private func shellGPU(_ s: SparkState) -> GlowSourceGPU? {
    let u = min(s.age / max(tuning.shellLife, 0.05), 1)
    let radius = tuning.shellMaxRadius * easeOutCubic(u)
    let thickness = tuning.shellThicknessBase + tuning.shellThicknessGrow * radius
    // Below ~4 thicknesses of radius the "shell" is still a blob inside the
    // flash — skip it until it's grown proud.
    guard radius > 4 * thickness else { return nil }
    let intensity = smoothstep(0.02, 0.14, s.age) * powf(1 - u, tuning.shellFadePower) * tuning.shellPeak
    guard intensity > 0.01 else { return nil }
    return GlowSourceGPU(
      positionAndIntensity: SIMD4<Float>(s.position.x, s.position.y, s.position.z, intensity),
      radiusPacked: SIMD4<Float>(radius, expf(-s.age / tuning.whiteTau), thickness, 2)
    )
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
        angularRadius: tuning.homeRadius,
        targetIntensity: tuning.homeIntensity,
        currentIntensity: existingCurrent(for: Self.homeKey) ?? 0
      ))
    }

    if tuning.granularity == .point {
      appendPointSources(locations, into: &newSources)
    } else {
      appendRegionSources(into: &newSources)
    }

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
  private func appendPointSources(
    _ points: [PauseLiveSnapshot.GeoPoint],
    into newSources: inout [SourceState]
  ) {
    struct Cell {
      var lat: Float
      var lon: Float
      var count: Int
    }
    var cells: [String: Cell] = [:]
    for point in points where point.count > 0 {
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
      let normalized = min(1, log2(Float(cell.count) + 1) / log2(tuning.pointSoftCap + 1))
      newSources.append(SourceState(
        key: key,
        position: sphereUnitVector(latDeg: cell.lat, lonDeg: cell.lon),
        angularRadius: tuning.pointBaseRadius + tuning.pointRadiusGain * normalized,
        targetIntensity: tuning.pointBaseIntensity + tuning.pointIntensityGain * normalized,
        currentIntensity: existingCurrent(for: key) ?? 0
      ))
    }
  }

  private static func cellKey(lat: Float, lon: Float) -> String {
    "pt:\(Int((lat * 4).rounded()))|\(Int((lon * 4).rounded()))"
  }

  /// Region mode: located participants aggregate into whole-region blobs — a
  /// join lights its country or continent, not a city point. Stable keys per
  /// region mean granularity flips crossfade over `lerpTau` via the existing
  /// vanished-source fade path.
  private func appendRegionSources(into newSources: inout [SourceState]) {
    struct Region {
      var position: SIMD3<Float>
      var radius: Float
      var count: Int
    }
    var regions: [String: Region] = [:]
    var unmatched: [PauseLiveSnapshot.GeoPoint] = []

    for point in locations where point.count > 0 {
      guard let resolved = regionFor(lat: point.lat, lon: point.lon) else {
        unmatched.append(point)
        continue
      }
      if var region = regions[resolved.key] {
        region.count += point.count
        regions[resolved.key] = region
      } else {
        regions[resolved.key] = Region(
          position: resolved.position,
          radius: resolved.radius,
          count: point.count
        )
      }
    }

    for (key, region) in regions {
      let normalized = min(1, log2(Float(region.count) + 1) / log2(tuning.pointSoftCap + 1))
      newSources.append(SourceState(
        key: key,
        position: region.position,
        angularRadius: region.radius,
        targetIntensity: tuning.pointBaseIntensity + tuning.pointIntensityGain * normalized,
        currentIntensity: existingCurrent(for: key) ?? 0
      ))
    }

    // Points the country table can't place fall back to point cells so no
    // participant silently vanishes in region mode.
    appendPointSources(unmatched, into: &newSources)
  }

  /// Resolve a lat/lon to the active granularity's region blob. Positions and
  /// radii come from CountryLookup's hand-tuned table (nearest-centroid match,
  /// generous tolerance — this is a visual grouping, not a border test).
  private func regionFor(
    lat: Float, lon: Float
  ) -> (key: String, position: SIMD3<Float>, radius: Float)? {
    let lookup = CountryLookup.shared
    guard tuning.granularity != .point,
          let country = lookup.nearestCountry(lat: lat, lon: lon, withinDegrees: 20) else {
      return nil
    }
    switch tuning.granularity {
    case .point:
      return nil
    case .country:
      return (
        "rg:\(country.iso2)",
        country.unitVector,
        country.glowRadiusRadians * tuning.regionRadiusScale
      )
    case .continent:
      guard let center = lookup.continentCenter(country.continentISO) else { return nil }
      return (
        "rg:\(center.iso)",
        center.unitVector,
        center.angularRadius * tuning.regionRadiusScale
      )
    }
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
    /// Resolved at spark time (point radius, or region radius in region mode).
    let radius: Float
    /// Random scintillation phase, fixed at spawn — decorrelates twinkle
    /// sparks so simultaneous joins never shimmer in lockstep.
    let seed: Float
    var age: Float
  }
}

private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
  let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
  return t * t * (3 - 2 * t)
}

private func easeOutCubic(_ x: Float) -> Float {
  let inv = 1 - max(0, min(1, x))
  return 1 - inv * inv * inv
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
