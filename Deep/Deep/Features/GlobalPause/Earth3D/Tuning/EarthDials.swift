#if DEBUG
import SwiftUI
import UIKit
import DialKit

// Dev-only DialKit panel for the Earth orb — the successor to the old
// EarthTuningPanel slider list. One aggregate `EarthDialParams` snapshots
// every tuning struct the lab drives; `EarthDialsOverlay` mounts the DialKit
// FAB/drawer and mirrors edits into the live objects (`EarthTuning.shared`,
// the scene's stores, `NightSkyTuning.shared`) on every change.
//
// Same contract as before: nothing persists — reset is a fresh struct, and
// good values leave through "Copy Swift" (pasteboard) for transcription back
// into the defaults. Follows the OrbTuning.swift pattern from Deep Session.

/// Aggregate model DialKit edits. Defaults reproduce the shipped look
/// exactly, mirroring each tuning struct's own `init()`.
struct EarthDialParams: Codable, Equatable {
  var earth = EarthTuning.Values()
  var glow = EarthGlowStore.Tuning()
  var interaction = EarthInteraction.Tuning()
  var ripples = EarthHaloRipples.Tuning()
  var sky = NightSkyTuning.Values()
  /// Mirrors `NightSkyTuning.enabled` — the lab's night-sky/cream A/B flag.
  /// Deliberately spared by every reset, like the old panel's toggle.
  var nightSkyOn = true

  /// String bridge for the granularity enum — DialKit's `.select` binds a
  /// String keyPath. Computed, so Codable synthesis ignores it.
  var granularityRaw: String {
    get { glow.granularity.rawValue }
    set { glow.granularity = .init(rawValue: newValue) ?? .point }
  }

  /// String bridges for the 3D style enums — same `.select` pattern.
  var glowPointStyleRaw: String {
    get { glow.glowPointStyle.rawValue }
    set { glow.glowPointStyle = .init(rawValue: newValue) ?? .classic }
  }
  var sparkStyleRaw: String {
    get { glow.sparkStyle.rawValue }
    set { glow.sparkStyle = .init(rawValue: newValue) ?? .classic }
  }
}

extension EarthDialParams {
  /// The action path of the reset controls; DialKit prefixes an action inside
  /// a group with the group path, so the top-level control fires the bare
  /// path and each group's own fires "surface.reset", "home.reset", … — the
  /// prefix names the group to restore. (DialKit has no built-in defaults
  /// reset — `baseValues` silently tracks edits.)
  static let resetActionPath = "reset"

  /// Restores one control group's parameters to their defaults, leaving
  /// every other group's tuning untouched. Group names must match the
  /// `.group` paths in `controls`. Field sets mirror the old panel's
  /// per-section reset closures exactly.
  mutating func reset(group: String) {
    let d = EarthDialParams()
    switch group {
    case "surface":
      earth.continentLo = d.earth.continentLo
      earth.continentHi = d.earth.continentHi
      earth.inlandLo = d.earth.inlandLo
      earth.inlandHi = d.earth.inlandHi
      earth.coastLo = d.earth.coastLo
      earth.coastHi = d.earth.coastHi
      earth.paletteStart = d.earth.paletteStart
      earth.paletteSpan = d.earth.paletteSpan
      earth.iridescenceDriftSpeed = d.earth.iridescenceDriftSpeed
      earth.iridescenceDriftAmp = d.earth.iridescenceDriftAmp
      earth.glowHaloWeight = d.earth.glowHaloWeight
      earth.glowExposure = d.earth.glowExposure
      earth.glowLandMix = d.earth.glowLandMix
      earth.glowBrightness = d.earth.glowBrightness
      earth.sparkFlash = d.earth.sparkFlash
      earth.coastGlow = d.earth.coastGlow
      earth.alphaContinent = d.earth.alphaContinent
      earth.alphaCoast = d.earth.alphaCoast
      earth.alphaSea = d.earth.alphaSea
    case "volumetric":
      earth.volIntensity = d.earth.volIntensity
      earth.volHeight = d.earth.volHeight
      earth.volSoftness = d.earth.volSoftness
      earth.volAlphaLift = d.earth.volAlphaLift
      earth.volTintMix = d.earth.volTintMix
      earth.volBackGhost = d.earth.volBackGhost
    case "emissive":
      earth.emissiveContinent = d.earth.emissiveContinent
      earth.emissiveInland = d.earth.emissiveInland
      earth.emissiveSeaGlow = d.earth.emissiveSeaGlow
      earth.emissiveBackGlow = d.earth.emissiveBackGlow
      earth.emissiveRim = d.earth.emissiveRim
      earth.emissiveEdge = d.earth.emissiveEdge
      earth.emissiveBody = d.earth.emissiveBody
      earth.emissiveShimmer = d.earth.emissiveShimmer
      earth.shimmerAmp = d.earth.shimmerAmp
    case "rim":
      earth.rimTightness = d.earth.rimTightness
      earth.fresnelBodyExponent = d.earth.fresnelBodyExponent
      earth.refractiveIndex = d.earth.refractiveIndex
      earth.rimColorMix = d.earth.rimColorMix
      earth.backBleedBase = d.earth.backBleedBase
      earth.backBleedRimFade = d.earth.backBleedRimFade
      earth.backBleedTint = d.earth.backBleedTint
      earth.backLo = d.earth.backLo
      earth.backHi = d.earth.backHi
      earth.alphaRim = d.earth.alphaRim
      earth.backBleedAlpha = d.earth.backBleedAlpha
    case "atmosphere":
      earth.atmosphereStrength = d.earth.atmosphereStrength
      earth.hazeAlpha = d.earth.hazeAlpha
      earth.hazeExponent = d.earth.hazeExponent
    case "bloom":
      earth.bloomThresholdLo = d.earth.bloomThresholdLo
      earth.bloomThresholdHi = d.earth.bloomThresholdHi
      earth.blurStepScale = d.earth.blurStepScale
      earth.bloomStrength = d.earth.bloomStrength
      earth.tonemapK = d.earth.tonemapK
      earth.bloomAlphaLift = d.earth.bloomAlphaLift
    case "breathSun":
      earth.breathScaleAmp = d.earth.breathScaleAmp
      earth.breathInhaleSeconds = d.earth.breathInhaleSeconds
      earth.breathExhaleSeconds = d.earth.breathExhaleSeconds
      earth.sunX = d.earth.sunX
      earth.sunY = d.earth.sunY
      earth.sunZ = d.earth.sunZ
    case "glowRegion":
      glow.granularity = d.glow.granularity
      glow.regionRadiusScale = d.glow.regionRadiusScale
      earth.litEmissive = d.earth.litEmissive
      earth.litColorMix = d.earth.litColorMix
    case "glowPoints":
      glow.lerpTau = d.glow.lerpTau
      glow.pointSoftCap = d.glow.pointSoftCap
      glow.pointBaseIntensity = d.glow.pointBaseIntensity
      glow.pointIntensityGain = d.glow.pointIntensityGain
      glow.pointBaseRadius = d.glow.pointBaseRadius
      glow.pointRadiusGain = d.glow.pointRadiusGain
    case "home":
      glow.homeIntensity = d.glow.homeIntensity
      glow.homeRadius = d.glow.homeRadius
      glow.homeWhiteness = d.glow.homeWhiteness
      glow.homeBreathAmplitude = d.glow.homeBreathAmplitude
      glow.homeBreathRate = d.glow.homeBreathRate
      glow.homeColumnHeight = d.glow.homeColumnHeight
    case "sparks":
      glow.sparkLife = d.glow.sparkLife
      glow.sparkCap = d.glow.sparkCap
      glow.sparkRadius = d.glow.sparkRadius
      glow.sparkPeak = d.glow.sparkPeak
      glow.sparkColumnBoost = d.glow.sparkColumnBoost
    case "glowOrbs":
      glow.glowPointStyle = d.glow.glowPointStyle
      earth.orbSigmaScale = d.earth.orbSigmaScale
      earth.orbExposure = d.earth.orbExposure
      earth.orbGain = d.earth.orbGain
      earth.orbHotGain = d.earth.orbHotGain
      earth.orbCoreWhiteBoost = d.earth.orbCoreWhiteBoost
      earth.orbAlphaLift = d.earth.orbAlphaLift
      earth.orbHaloWeight = d.earth.orbHaloWeight
      earth.orbElevRatio = d.earth.orbElevRatio
      earth.orbSeatWeight = d.earth.orbSeatWeight
    case "sparkShell":
      glow.sparkStyle = d.glow.sparkStyle
      glow.flashPeak = d.glow.flashPeak
      glow.flashDecay = d.glow.flashDecay
      glow.flashRadius = d.glow.flashRadius
      glow.shellLife = d.glow.shellLife
      glow.shellMaxRadius = d.glow.shellMaxRadius
      glow.shellThicknessBase = d.glow.shellThicknessBase
      glow.shellThicknessGrow = d.glow.shellThicknessGrow
      glow.shellPeak = d.glow.shellPeak
      glow.shellFadePower = d.glow.shellFadePower
      glow.whiteTau = d.glow.whiteTau
      earth.burstExposure = d.earth.burstExposure
      earth.burstGain = d.earth.burstGain
      earth.burstHotGain = d.earth.burstHotGain
      earth.burstAlphaLift = d.earth.burstAlphaLift
    case "twinkle":
      glow.twinkleLife = d.glow.twinkleLife
      glow.twinklePeak = d.glow.twinklePeak
      glow.twinkleRadius = d.glow.twinkleRadius
      glow.twinkleSpeed = d.glow.twinkleSpeed
      glow.twinkleDepth = d.glow.twinkleDepth
      glow.twinkleSizeJitter = d.glow.twinkleSizeJitter
      glow.twinkleDecay = d.glow.twinkleDecay
    case "interaction":
      interaction = d.interaction
    case "ripples":
      ripples = d.ripples
    case "nightSky":
      // Whole sky struct; the A/B toggle survives on purpose.
      sky = d.sky
    default:
      break
    }
  }

  /// A/B glow looks, ported from the old panel. Every look assigns the same
  /// field set — starting from defaults, then overlaying — so flips are
  /// deterministic and unrelated sliders survive.
  enum GlowLook: String { case classic, boost, beacon }

  mutating func apply(look: GlowLook) {
    let d = EarthDialParams()
    earth.glowLandMix = d.earth.glowLandMix
    earth.glowBrightness = d.earth.glowBrightness
    earth.emissiveContinent = d.earth.emissiveContinent
    earth.emissiveInland = d.earth.emissiveInland
    earth.emissiveSeaGlow = d.earth.emissiveSeaGlow
    earth.coastGlow = d.earth.coastGlow
    earth.sparkFlash = d.earth.sparkFlash
    earth.litEmissive = d.earth.litEmissive
    earth.litColorMix = d.earth.litColorMix
    glow.granularity = d.glow.granularity
    glow.regionRadiusScale = d.glow.regionRadiusScale

    switch look {
    case .classic:
      break
    case .boost:
      earth.glowLandMix = 0
      earth.glowBrightness = 1.2
      earth.emissiveSeaGlow = 0
      earth.coastGlow = 0.8
      earth.sparkFlash = 1.0
    case .beacon:
      // Dark quiet world; whole lit regions burn bright and independent.
      earth.glowLandMix = 0
      earth.glowBrightness = 0
      earth.emissiveContinent = 0.25
      earth.emissiveInland = 0.1
      earth.emissiveSeaGlow = 0
      earth.coastGlow = 1.0
      earth.sparkFlash = 1.0
      earth.litEmissive = 2.5
      earth.litColorMix = 0.75
      glow.granularity = .continent
    }
  }

  /// The control tree. Group paths must match `reset(group:)`'s cases; slider
  /// steps are chosen so DialKit's step-grid normalization reproduces every
  /// shipped default exactly (e.g. breathScaleAmp 0.015 needs step 0.001).
  static let controls: [DialControl<EarthDialParams>] = [
    .group("actions", label: "Test actions", children: [
      .action("joinSpark", label: "Join spark"),
      .action("cities", label: "Cities"),
      .action("stress80", label: "Stress 80"),
      .action("decelerate", label: "Decelerate"),
      .action("resume", label: "Resume"),
      .action("clearGlow", label: "Clear glow"),
      .action("boostLook", label: "Boost look"),
      .action("beaconLook", label: "Beacon look"),
      .action("classicLook", label: "Classic look"),
    ]),
    .group("surface", collapsed: true, children: [
      .slider("continentLo", keyPath: \.earth.continentLo, range: 0...1, step: 0.01),
      .slider("continentHi", keyPath: \.earth.continentHi, range: 0...1, step: 0.01),
      .slider("inlandLo", keyPath: \.earth.inlandLo, range: 0...1, step: 0.01),
      .slider("inlandHi", keyPath: \.earth.inlandHi, range: 0...1, step: 0.01),
      .slider("coastLo", keyPath: \.earth.coastLo, range: 0...1, step: 0.01),
      .slider("coastHi", keyPath: \.earth.coastHi, range: 0...1, step: 0.01),
      .slider("paletteStart", keyPath: \.earth.paletteStart, range: 0...1, step: 0.01),
      .slider("paletteSpan", keyPath: \.earth.paletteSpan, range: 0...1, step: 0.01),
      .slider("iridDriftSpeed", keyPath: \.earth.iridescenceDriftSpeed, range: 0...1, step: 0.01),
      .slider("iridDriftAmp", keyPath: \.earth.iridescenceDriftAmp, range: 0...0.3, step: 0.01),
      .slider("glowHaloWeight", keyPath: \.earth.glowHaloWeight, range: 0...1, step: 0.01),
      .slider("glowExposure", keyPath: \.earth.glowExposure, range: 0.2...4, step: 0.01),
      .slider("glowLandMix", keyPath: \.earth.glowLandMix, range: 0...1, step: 0.01),
      .slider("glowBrightness", keyPath: \.earth.glowBrightness, range: 0...3, step: 0.01),
      .slider("sparkFlash", keyPath: \.earth.sparkFlash, range: 0...3, step: 0.01),
      .slider("coastGlow", keyPath: \.earth.coastGlow, range: 0...2, step: 0.01),
      .slider("alphaContinent", keyPath: \.earth.alphaContinent, range: 0...1, step: 0.01),
      .slider("alphaCoast", keyPath: \.earth.alphaCoast, range: 0...1, step: 0.01),
      .slider("alphaSea", keyPath: \.earth.alphaSea, range: 0...1, step: 0.01),
      .action(resetActionPath, label: "Reset surface"),
    ]),
    .group("volumetric", label: "Volumetric glow", collapsed: true, children: [
      .slider("intensity", keyPath: \.earth.volIntensity, range: 0...3, step: 0.01),
      .slider("height", keyPath: \.earth.volHeight, range: 0.05...1, step: 0.01),
      .slider("softness", keyPath: \.earth.volSoftness, range: 0...3, step: 0.01),
      .slider("alphaLift", keyPath: \.earth.volAlphaLift, range: 0...1.5, step: 0.01),
      .slider("tintMix", keyPath: \.earth.volTintMix, range: 0...1, step: 0.01),
      .slider("backGhost", keyPath: \.earth.volBackGhost, range: 0...1, step: 0.01),
      .action(resetActionPath, label: "Reset volumetric"),
    ]),
    .group("emissive", collapsed: true, children: [
      .slider("continent", keyPath: \.earth.emissiveContinent, range: 0...2, step: 0.01),
      .slider("inland", keyPath: \.earth.emissiveInland, range: 0...1.5, step: 0.01),
      .slider("seaGlow", keyPath: \.earth.emissiveSeaGlow, range: 0...1.5, step: 0.01),
      .slider("backGlow", keyPath: \.earth.emissiveBackGlow, range: 0...1.5, step: 0.01),
      .slider("rim", keyPath: \.earth.emissiveRim, range: 0...3, step: 0.01),
      .slider("edge", keyPath: \.earth.emissiveEdge, range: 0...2.5, step: 0.01),
      .slider("body", keyPath: \.earth.emissiveBody, range: 0...0.5, step: 0.01),
      .slider("shimmer", keyPath: \.earth.emissiveShimmer, range: 0...3, step: 0.01),
      .slider("shimmerAmp", keyPath: \.earth.shimmerAmp, range: 0...0.3, step: 0.01),
      .action(resetActionPath, label: "Reset emissive"),
    ]),
    .group("rim", label: "Rim & glass", collapsed: true, children: [
      .slider("rimTightness", keyPath: \.earth.rimTightness, range: 0.3...3, step: 0.01),
      .slider("fresnelBodyExp", keyPath: \.earth.fresnelBodyExponent, range: 0.5...8, step: 0.01),
      .slider("refractiveIndex", keyPath: \.earth.refractiveIndex, range: 1.05...2.5, step: 0.01),
      .slider("rimColorMix", keyPath: \.earth.rimColorMix, range: 0...1, step: 0.01),
      .slider("backBleedBase", keyPath: \.earth.backBleedBase, range: 0...1, step: 0.01),
      .slider("backBleedRimFade", keyPath: \.earth.backBleedRimFade, range: 0...1, step: 0.01),
      .slider("backBleedTint", keyPath: \.earth.backBleedTint, range: 0...1, step: 0.01),
      .slider("backLo", keyPath: \.earth.backLo, range: 0...1, step: 0.01),
      .slider("backHi", keyPath: \.earth.backHi, range: 0...1, step: 0.01),
      .slider("alphaRim", keyPath: \.earth.alphaRim, range: 0...2.5, step: 0.01),
      .slider("alphaBackBleed", keyPath: \.earth.backBleedAlpha, range: 0...1, step: 0.01),
      .action(resetActionPath, label: "Reset rim & glass"),
    ]),
    .group("atmosphere", collapsed: true, children: [
      .slider("strength", keyPath: \.earth.atmosphereStrength, range: 0...1.5, step: 0.01),
      .slider("hazeAlpha", keyPath: \.earth.hazeAlpha, range: 0...1.5, step: 0.01),
      .slider("hazeExponent", keyPath: \.earth.hazeExponent, range: 0.5...6, step: 0.01),
      .action(resetActionPath, label: "Reset atmosphere"),
    ]),
    .group("bloom", label: "Bloom & tonemap", collapsed: true, children: [
      .slider("thresholdLo", keyPath: \.earth.bloomThresholdLo, range: 0...1, step: 0.01),
      .slider("thresholdHi", keyPath: \.earth.bloomThresholdHi, range: 0...1.5, step: 0.01),
      .slider("blurStep", keyPath: \.earth.blurStepScale, range: 0.5...8, step: 0.05),
      .slider("strength", keyPath: \.earth.bloomStrength, range: 0...1.5, step: 0.01),
      .slider("tonemapK", keyPath: \.earth.tonemapK, range: 0.3...4, step: 0.01),
      .slider("alphaLift", keyPath: \.earth.bloomAlphaLift, range: 0...1.5, step: 0.01),
      .action(resetActionPath, label: "Reset bloom"),
    ]),
    .group("breathSun", label: "Breath & sun", collapsed: true, children: [
      .slider("breathScaleAmp", keyPath: \.earth.breathScaleAmp, range: 0...0.06, step: 0.001),
      .slider("inhaleSeconds", keyPath: \.earth.breathInhaleSeconds, range: 1...10, step: 0.1, unit: "s"),
      .slider("exhaleSeconds", keyPath: \.earth.breathExhaleSeconds, range: 1...12, step: 0.1, unit: "s"),
      .slider("sunX", keyPath: \.earth.sunX, range: -1...1, step: 0.01),
      .slider("sunY", keyPath: \.earth.sunY, range: -1...1, step: 0.01),
      .slider("sunZ", keyPath: \.earth.sunZ, range: -1...1, step: 0.01),
      .action(resetActionPath, label: "Reset breath & sun"),
    ]),
    .group("glowRegion", label: "Glow region", collapsed: true, children: [
      .select("granularity", keyPath: \.granularityRaw,
              options: EarthGlowStore.Tuning.Granularity.allCases.map(\.rawValue)),
      .slider("regionRadiusScale", keyPath: \.glow.regionRadiusScale, range: 0.5...3, step: 0.01),
      .slider("litEmissive", keyPath: \.earth.litEmissive, range: 0...4, step: 0.05),
      .slider("litColorMix", keyPath: \.earth.litColorMix, range: 0...1, step: 0.01),
      .action(resetActionPath, label: "Reset glow region"),
    ]),
    .group("glowPoints", label: "Glow points", collapsed: true, children: [
      .slider("lerpTau", keyPath: \.glow.lerpTau, range: 0.1...3, step: 0.01, unit: "s"),
      .slider("softCap", keyPath: \.glow.pointSoftCap, range: 1...20, step: 0.5),
      .slider("baseIntensity", keyPath: \.glow.pointBaseIntensity, range: 0...1, step: 0.01),
      .slider("intensityGain", keyPath: \.glow.pointIntensityGain, range: 0...1, step: 0.01),
      .slider("baseRadius", keyPath: \.glow.pointBaseRadius, range: 0.005...0.2, step: 0.001),
      .slider("radiusGain", keyPath: \.glow.pointRadiusGain, range: 0...0.1, step: 0.001),
      .action(resetActionPath, label: "Reset glow points"),
    ]),
    .group("home", collapsed: true, children: [
      .slider("intensity", keyPath: \.glow.homeIntensity, range: 0...1.5, step: 0.01),
      .slider("radius", keyPath: \.glow.homeRadius, range: 0.01...0.2, step: 0.001),
      .slider("whiteness", keyPath: \.glow.homeWhiteness, range: 0...1, step: 0.01),
      .slider("breathAmp", keyPath: \.glow.homeBreathAmplitude, range: 0...0.5, step: 0.01),
      .slider("breathRate", keyPath: \.glow.homeBreathRate, range: 0.05...3, step: 0.01),
      .slider("columnHeight", keyPath: \.glow.homeColumnHeight, range: 0.2...3, step: 0.01),
      .action(resetActionPath, label: "Reset home"),
    ]),
    .group("sparks", collapsed: true, children: [
      .slider("life", keyPath: \.glow.sparkLife, range: 0.2...6, step: 0.05, unit: "s"),
      .slider("cap", keyPath: \.glow.sparkCap, range: 1...32, step: 1),
      .slider("radius", keyPath: \.glow.sparkRadius, range: 0.005...0.15, step: 0.001),
      .slider("peak", keyPath: \.glow.sparkPeak, range: 0...3, step: 0.01),
      .slider("columnBoost", keyPath: \.glow.sparkColumnBoost, range: 0...4, step: 0.01),
      .action(resetActionPath, label: "Reset sparks"),
    ]),
    .group("glowOrbs", label: "Glow orbs (3D)", collapsed: true, children: [
      .select("style", keyPath: \.glowPointStyleRaw,
              options: EarthGlowStore.Tuning.GlowPointStyle.allCases.map(\.rawValue)),
      .slider("sigmaScale", keyPath: \.earth.orbSigmaScale, range: 0.2...3, step: 0.01),
      .slider("exposure", keyPath: \.earth.orbExposure, range: 0...6, step: 0.01),
      .slider("gain", keyPath: \.earth.orbGain, range: 0...3, step: 0.01),
      .slider("hotGain", keyPath: \.earth.orbHotGain, range: 0...4, step: 0.01),
      .slider("coreWhiteBoost", keyPath: \.earth.orbCoreWhiteBoost, range: 0...1, step: 0.01),
      .slider("alphaLift", keyPath: \.earth.orbAlphaLift, range: 0...1.5, step: 0.01),
      .slider("haloWeight", keyPath: \.earth.orbHaloWeight, range: 0...1, step: 0.01),
      // elevRatio only moves the `orb` style — dome/buried seat on the surface.
      .slider("elevRatio", keyPath: \.earth.orbElevRatio, range: 0...3, step: 0.05),
      .slider("seatWeight", keyPath: \.earth.orbSeatWeight, range: 0...1, step: 0.01),
      .action(resetActionPath, label: "Reset glow orbs"),
    ]),
    .group("sparkShell", label: "Spark flash + shell (3D)", collapsed: true, children: [
      .select("style", keyPath: \.sparkStyleRaw,
              options: EarthGlowStore.Tuning.SparkStyle.allCases.map(\.rawValue)),
      .slider("flashPeak", keyPath: \.glow.flashPeak, range: 0...4, step: 0.01),
      .slider("flashDecay", keyPath: \.glow.flashDecay, range: 0.03...0.5, step: 0.01, unit: "s"),
      .slider("flashRadius", keyPath: \.glow.flashRadius, range: 0.01...0.15, step: 0.001),
      .slider("shellLife", keyPath: \.glow.shellLife, range: 0.3...4, step: 0.05, unit: "s"),
      .slider("shellMaxRadius", keyPath: \.glow.shellMaxRadius, range: 0.1...0.9, step: 0.01),
      .slider("thicknessBase", keyPath: \.glow.shellThicknessBase, range: 0.002...0.04, step: 0.001),
      .slider("thicknessGrow", keyPath: \.glow.shellThicknessGrow, range: 0...0.15, step: 0.005),
      .slider("shellPeak", keyPath: \.glow.shellPeak, range: 0...3, step: 0.01),
      .slider("fadePower", keyPath: \.glow.shellFadePower, range: 0.5...5, step: 0.1),
      .slider("whiteTau", keyPath: \.glow.whiteTau, range: 0.1...1, step: 0.01, unit: "s"),
      .slider("burstExposure", keyPath: \.earth.burstExposure, range: 0...4, step: 0.01),
      .slider("burstGain", keyPath: \.earth.burstGain, range: 0...3, step: 0.01),
      .slider("burstHotGain", keyPath: \.earth.burstHotGain, range: 0...3, step: 0.01),
      .slider("burstAlphaLift", keyPath: \.earth.burstAlphaLift, range: 0...1.5, step: 0.01),
      .action(resetActionPath, label: "Reset spark shell"),
    ]),
    .group("twinkle", label: "Twinkle spark (3D)", collapsed: true, children: [
      .slider("life", keyPath: \.glow.twinkleLife, range: 0.3...4, step: 0.05, unit: "s"),
      .slider("peak", keyPath: \.glow.twinklePeak, range: 0...4, step: 0.01),
      .slider("radius", keyPath: \.glow.twinkleRadius, range: 0.008...0.06, step: 0.001),
      .slider("speed", keyPath: \.glow.twinkleSpeed, range: 2...20, step: 0.5, unit: "Hz"),
      .slider("depth", keyPath: \.glow.twinkleDepth, range: 0...0.95, step: 0.01),
      .slider("sizeJitter", keyPath: \.glow.twinkleSizeJitter, range: 0...1, step: 0.01),
      .slider("decay", keyPath: \.glow.twinkleDecay, range: 0.1...1.5, step: 0.01, unit: "s"),
      .action(resetActionPath, label: "Reset twinkle"),
    ]),
    .group("interaction", collapsed: true, children: [
      .slider("damping", keyPath: \.interaction.damping, range: 0.8...0.99, step: 0.005),
      .slider("dragGain", keyPath: \.interaction.dragGain, range: 0.2...3, step: 0.05),
      .slider("pitchLimit", keyPath: \.interaction.pitchLimitDegrees, range: 45...90, step: 1, unit: "°"),
      .slider("idleAfterSeconds", keyPath: \.interaction.idleAfterSeconds, range: 0...10, step: 0.1, unit: "s"),
      .slider("idleDriftSpeed", keyPath: \.interaction.idleDriftSpeed, range: 0...0.3, step: 0.005),
      .action(resetActionPath, label: "Reset interaction"),
    ]),
    .group("ripples", collapsed: true, children: [
      .slider("globalCap", keyPath: \.ripples.globalCap, range: 1...24, step: 1),
      .slider("spatialCooldown", keyPath: \.ripples.spatialCooldown, range: 0...2, step: 0.01, unit: "s"),
      .slider("lifetime", keyPath: \.ripples.lifetime, range: 0.2...4, step: 0.05, unit: "s"),
      .slider("cooldownAngle", keyPath: \.ripples.cooldownAngleDegrees, range: 0...15, step: 0.5, unit: "°"),
      .slider("ringStart", keyPath: \.ripples.ringStartRadius, range: 0...0.3, step: 0.005),
      .slider("ringEnd", keyPath: \.ripples.ringEndRadius, range: 0.05...1, step: 0.01),
      .slider("ringOpacity", keyPath: \.ripples.ringOpacity, range: 0...1, step: 0.01),
      .action(resetActionPath, label: "Reset ripples"),
    ]),
    .group("nightSky", label: "Night sky", collapsed: true, children: [
      .toggle("nightSkyOn", keyPath: \.nightSkyOn, label: "Night sky on"),
      .slider("skyTopDarkness", keyPath: \.sky.skyTopDarkness, range: 0...1, step: 0.01),
      .slider("skyBottomDarkness", keyPath: \.sky.skyBottomDarkness, range: 0...1, step: 0.01),
      .slider("horizonGlow", keyPath: \.sky.horizonGlow, range: 0...1, step: 0.01),
      .slider("starCount", keyPath: \.sky.starCount, range: 0...300, step: 1),
      .slider("sizeMin", keyPath: \.sky.starSizeMin, range: 0.2...2, step: 0.05, unit: "pt"),
      .slider("sizeMax", keyPath: \.sky.starSizeMax, range: 0.5...5, step: 0.05, unit: "pt"),
      .slider("brightnessMin", keyPath: \.sky.brightnessMin, range: 0...1, step: 0.01),
      .slider("brightnessMax", keyPath: \.sky.brightnessMax, range: 0.2...1.5, step: 0.01),
      .slider("twinkleSpeed", keyPath: \.sky.twinkleSpeed, range: 0.05...3, step: 0.01, unit: "Hz"),
      .slider("twinkleDepth", keyPath: \.sky.twinkleDepth, range: 0...1, step: 0.01),
      .slider("twinkleShare", keyPath: \.sky.twinkleShare, range: 0...1, step: 0.01),
      .slider("tintSpread", keyPath: \.sky.tintSpread, range: 0...1, step: 0.01),
      .slider("tintBalance", keyPath: \.sky.tintBalance, range: 0...1, step: 0.01),
      .slider("glowScale", keyPath: \.sky.glowScale, range: 1...6, step: 0.05),
      .slider("glowAlpha", keyPath: \.sky.glowAlpha, range: 0...1, step: 0.01),
      .slider("horizonFade", keyPath: \.sky.horizonFade, range: 0...1, step: 0.01),
      .slider("seed", keyPath: \.sky.seed, range: 0...99, step: 1),
      .slider("earthBackdropDim", keyPath: \.sky.earthBackdropDim, range: 0...1, step: 0.01),
      .action(resetActionPath, label: "Reset night sky"),
    ]),
    .action("copySwift", label: "Copy Swift"),
    .action(resetActionPath, label: "Reset everything"),
  ]
}

/// The one dial panel for the Earth lab. A singleton so tuned values survive
/// lab remounts (the panel registers with DialKit's global store on creation
/// and lives for the app's lifetime). The scene the test actions poke is
/// bound by the overlay on appear — weak, since the lab owns it.
@MainActor
enum EarthDials {
  static weak var scene: GlobalPauseEarthScene?

  static let panel: DialPanelState<EarthDialParams> = DialPanelState(
    name: "Earth",
    initial: EarthDialParams(),
    controls: EarthDialParams.controls,
    onAction: { path in
      // DialKit triggers actions from UI events, so main-actor is a fact;
      // the closure type just can't say so.
      MainActor.assumeIsolated { handle(actionPath: path) }
    }
  )

  private static func handle(actionPath path: String) {
    let suffix = "." + EarthDialParams.resetActionPath
    switch path {
    case EarthDialParams.resetActionPath:
      // Reset everything — the night-sky A/B toggle survives, as before.
      var fresh = EarthDialParams()
      fresh.nightSkyOn = panel.values.nightSkyOn
      panel.values = fresh
    case let p where p.hasSuffix(suffix):
      var values = panel.values
      values.reset(group: String(p.dropLast(suffix.count)))
      panel.values = values
    case "copySwift":
      UIPasteboard.general.string = exportSwift()
    case "actions.joinSpark":
      let joins = EarthGlowStore.sampleCities.shuffled().prefix(3).map {
        PauseJoinPoint(lat: $0.lat, lon: $0.lon)
      }
      scene?.enqueueJoins(Array(joins))
    case "actions.cities":
      scene?.glow.locations = EarthGlowStore.sampleCities
    case "actions.stress80":
      scene?.glow.locations = (0..<80).map { i in
        PauseLiveSnapshot.GeoPoint(
          lat: Float(-50 + (i * 17) % 110),
          lon: Float(-170 + (i * 47) % 345),
          count: 1 + i % 5
        )
      }
    case "actions.decelerate":
      scene?.interaction.decelerateToRest()
    case "actions.resume":
      scene?.interaction.resumeSpin()
    case "actions.clearGlow":
      scene?.glow.locations = []
      scene?.glow.participantsByCountry = [:]
      scene?.glow.unlocatedByCountry = [:]
    case "actions.boostLook":
      apply(look: .boost)
    case "actions.beaconLook":
      apply(look: .beacon)
    case "actions.classicLook":
      apply(look: .classic)
    default:
      break
    }
  }

  private static func apply(look: EarthDialParams.GlowLook) {
    var values = panel.values
    values.apply(look: look)
    panel.values = values
  }

  // MARK: - Export

  /// Mirror-based dump — one block per tuning struct, each line a paste-ready
  /// declaration, so transcribing good values back into the defaults is a
  /// straight replace. Never drifts when fields are added.
  private static func exportSwift() -> String {
    let p = panel.values
    var out = "// Earth tuning export\n"
    out += block("EarthTuning.Values", p.earth)
    out += block("NightSkyTuning.Values", p.sky)
    out += block("EarthGlowStore.Tuning", p.glow)
    out += block("EarthInteraction.Tuning", p.interaction)
    out += block("EarthHaloRipples.Tuning", p.ripples)
    return out
  }

  private static func block(_ title: String, _ subject: Any) -> String {
    var lines = ["\n// \(title)"]
    for child in Mirror(reflecting: subject).children {
      guard let label = child.label else { continue }
      switch child.value {
      case is Float, is Double, is Int:
        lines.append("var \(label): \(type(of: child.value)) = \(child.value)")
      default:
        // Enums (e.g. Granularity) print as their case name — emit the
        // dot-shorthand so the block stays paste-ready Swift.
        lines.append("var \(label): \(type(of: child.value)) = .\(child.value)")
      }
    }
    return lines.joined(separator: "\n") + "\n"
  }
}

/// Mounts the DialKit FAB/drawer and mirrors edits into the live objects —
/// `EarthTuning.shared`, the scene's stores, and `NightSkyTuning.shared` —
/// so every dial lands on the next rendered frame.
///
/// The drawer is NON-modal here: Deep vendors DialKit with its full-screen
/// dismiss scrim patched out (Deep/Vendor/dialkit-ios/DEEP-PATCHES.md), so
/// taps and drags on the globe pass through while the drawer stays open. It
/// closes only via its own drag handle; the FAB reopens it.
struct EarthDialsOverlay: View {
  let scene: GlobalPauseEarthScene
  @ObservedObject private var panel = EarthDials.panel

  var body: some View {
    DialRoot(position: .bottomRight, storageID: "earth-dials")
      .onAppear {
        EarthDials.scene = scene
        apply(panel.values)
      }
      .onReceive(panel.$values) { apply($0) }
  }

  private func apply(_ p: EarthDialParams) {
    EarthTuning.shared.values = p.earth
    scene.glow.tuning = p.glow
    scene.interaction.tuning = p.interaction
    scene.ripples.tuning = p.ripples
    NightSkyTuning.shared.values = p.sky
    NightSkyTuning.shared.enabled = p.nightSkyOn
  }
}

#Preview {
  // Hermetic scene; the dial panel is the app-lifetime singleton by design
  // (DialKit renders every registered panel, so a fresh one would duplicate).
  ZStack {
    NightSkyBackground(tuning: .shared)
      .ignoresSafeArea()
    EarthDialsOverlay(scene: .previewCities)
  }
}
#endif
