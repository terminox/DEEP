import Foundation
import SwiftUI
import simd

/// Live participant counts → smoothed gaussian glow sources on the orb's surface.
///
/// Why gaussians instead of a country-ID texture: simpler v1 (no GIS pipeline),
/// scales to the data we'll actually have, and the smooth angular falloff
/// already reads as "ink-in-water bloom" — which is exactly the design intent.
@MainActor
@Observable
final class EarthGlowStore {

  // MARK: - Public input

  /// Live participant counts keyed by ISO-alpha2 code (e.g. "TH", "JP", "US").
  /// Mutating this triggers a smooth 800ms lerp toward new target glow values.
  var participantsByCountry: [String: Int] = [:] {
    didSet { recomputeTargets() }
  }

  /// Optional ceiling for log scaling. If nil, derived from the largest value seen.
  var globalMaxOverride: Int?

  // MARK: - GPU-facing state

  /// Up-to-date GPU sources, lerped toward target. Renderer queries each frame.
  private var sources: [SourceState] = []
  private var lastTickTime: TimeInterval?

  /// Per-country lerp time constant (seconds).
  private let lerpTau: Float = 0.8

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
  }

  /// Renderer-facing snapshot. Only sources above an intensity threshold are
  /// uploaded — saves the shader from doing N gaussian falloffs for zeros.
  func currentGPUSources() -> [GlowSourceGPU] {
    sources.compactMap { s in
      guard s.currentIntensity > 0.003 else { return nil }
      return GlowSourceGPU(
        positionAndIntensity: SIMD4<Float>(s.position.x, s.position.y, s.position.z, s.currentIntensity),
        radiusPacked: SIMD4<Float>(s.angularRadius, 0, 0, 0)
      )
    }
  }

  var activeSourceCount: Int {
    sources.reduce(0) { $0 + ($1.currentIntensity > 0.003 ? 1 : 0) }
  }

  // MARK: - Target recomputation

  private func recomputeTargets() {
    let lookup = CountryLookup.shared
    let counts = participantsByCountry
    let globalMax = max(1, globalMaxOverride ?? counts.values.max() ?? 1)
    let logMax = log(Float(globalMax) + 1)

    // Build a fresh target map keyed by country index (stable order).
    var newSources: [SourceState] = []
    newSources.reserveCapacity(counts.count + 8)

    // Continent splash buckets (small-country fallback).
    var continentSplash: [String: Float] = [:]

    for (iso, count) in counts where count > 0 {
      guard let country = lookup.country(forISO: iso) else { continue }
      let normalized = log(Float(count) + 1) / logMax  // 0...1
      let intensity = smoothstep(0, 1, normalized)

      // Direct country source.
      newSources.append(SourceState(
        countryISO: iso,
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
        countryISO: "__CONT__\(cont)",
        position: center.unitVector,
        angularRadius: center.angularRadius,
        targetIntensity: intensity,
        currentIntensity: existingCurrent(for: "__CONT__\(cont)") ?? 0
      ))
    }

    // Preserve sources whose count just dropped to 0 so they can fade out smoothly.
    let activeISOs = Set(newSources.map(\.countryISO))
    for old in sources where !activeISOs.contains(old.countryISO) && old.currentIntensity > 0.003 {
      var fading = old
      fading.targetIntensity = 0
      newSources.append(fading)
    }

    sources = newSources
  }

  private func existingCurrent(for iso: String) -> Float? {
    sources.first(where: { $0.countryISO == iso })?.currentIntensity
  }

  // MARK: - State node

  private struct SourceState {
    var countryISO: String
    var position: SIMD3<Float>
    var angularRadius: Float
    var targetIntensity: Float
    var currentIntensity: Float
  }
}

private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
  let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
  return t * t * (3 - 2 * t)
}

// MARK: - Preview helpers

extension EarthGlowStore {
  static var previewCalm: EarthGlowStore { EarthGlowStore() }

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
    // Seed the current intensities at target so the preview shows full bloom
    // immediately instead of fading in over 800ms.
    for i in 0..<store.sources.count {
      store.sources[i].currentIntensity = store.sources[i].targetIntensity
    }
    return store
  }
}
