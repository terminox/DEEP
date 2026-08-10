#if DEBUG
import SwiftUI
import UIKit

/// Dev-only live tuning panel for the Earth orb. Presented as a non-dimming
/// detented sheet over the Global Pause surfaces (see
/// `GlobalPauseCoordinatorController.presentTuningPanel()`), so the globe
/// stays visible — and draggable — while sliders move.
///
/// Sliders bind straight to the live objects: `EarthTuning.shared` (shader +
/// renderer values), and the scene's `glow` / `interaction` / `ripples`
/// tuning structs. Nothing persists — reset is a fresh struct, and good
/// values leave through "Copy Swift" (pasteboard) for transcription back
/// into the defaults.
struct EarthTuningPanel: View {
  let scene: GlobalPauseEarthScene
  @Bindable private var tuning: EarthTuning
  @Bindable private var glow: EarthGlowStore
  @Bindable private var ripples: EarthHaloRipples
  @State private var lastAction: String?

  /// Pass `EarthTuning.shared` to drive the live renderers; previews inject a
  /// fresh instance so they never mutate the singleton.
  init(scene: GlobalPauseEarthScene, tuning: EarthTuning) {
    self.scene = scene
    self._tuning = Bindable(tuning)
    self._glow = Bindable(scene.glow)
    self._ripples = Bindable(scene.ripples)
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        header
        actionsCard
        surfaceSection
        emissiveSection
        rimSection
        atmosphereSection
        bloomSection
        breathSunSection
        glowRegionSection
        glowPointsSection
        homeSection
        sparksSection
        interactionSection
        ripplesSection
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 32)
    }
    .background(Color.moonCream)
  }

  // MARK: - Header

  private var header: some View {
    HStack {
      Text("EARTH TUNING")
        .font(DeepType.micro).tracking(2)
        .foregroundStyle(.deepPlum)
      if let lastAction {
        Text(lastAction)
          .font(DeepType.micro)
          .foregroundStyle(.driftGrey)
          .transition(.opacity)
      }
      Spacer()
      Button("Copy Swift") {
        UIPasteboard.general.string = exportSwift()
        note("copied")
      }
      .buttonStyle(.borderedProminent)
      .tint(.lavenderMist)
      .font(DeepType.micro)
      Button("Reset all") {
        tuning.reset()
        glow.tuning = EarthGlowStore.Tuning()
        scene.interaction.tuning = EarthInteraction.Tuning()
        ripples.tuning = EarthHaloRipples.Tuning()
        note("reset")
      }
      .buttonStyle(.borderedProminent)
      .tint(.blushPowder)
      .font(DeepType.micro)
    }
  }

  private func note(_ text: String) {
    withAnimation { lastAction = text }
    Task {
      try? await Task.sleep(for: .seconds(1.5))
      withAnimation { lastAction = nil }
    }
  }

  // MARK: - Test actions (ported from EarthSceneDebugHarness)

  private var actionsCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        Button("Join spark") {
          let joins = EarthGlowStore.sampleCities.shuffled().prefix(3).map {
            PauseJoinPoint(lat: $0.lat, lon: $0.lon)
          }
          scene.enqueueJoins(Array(joins))
          note("3 joins")
        }
        .tint(.lavenderMist)

        Button("Cities") {
          glow.locations = EarthGlowStore.sampleCities
          note("\(EarthGlowStore.sampleCities.count) cities")
        }
        .tint(.blushPowder)

        Button("Stress 80") {
          glow.locations = (0..<80).map { i in
            PauseLiveSnapshot.GeoPoint(
              lat: Float(-50 + (i * 17) % 110),
              lon: Float(-170 + (i * 47) % 345),
              count: 1 + i % 5
            )
          }
          note("80 cells")
        }
        .tint(.softLilac)
      }
      HStack(spacing: 12) {
        Button("Decelerate") { scene.interaction.decelerateToRest() }
          .tint(.blushPowder)
        Button("Resume") { scene.interaction.resumeSpin() }
          .tint(.softLilac)
        Button("Clear glow") {
          glow.locations = []
          glow.participantsByCountry = [:]
          glow.unlocatedByCountry = [:]
          note("cleared")
        }
        .tint(.lavenderMist)
      }
      // A/B between the glow models. Each look assigns the same fixed field
      // set (see applyLook), so switching is deterministic and any other
      // slider work survives the flip.
      HStack(spacing: 12) {
        Button("Boost look") { applyLook(.boost) }
          .tint(.lavenderMist)
        Button("Beacon look") { applyLook(.beacon) }
          .tint(.softLilac)
        Button("Classic look") { applyLook(.classic) }
          .tint(.blushPowder)
      }
    }
    .font(DeepType.micro)
    .buttonStyle(.borderedProminent)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  // MARK: - Shader sections

  private var surfaceSection: some View {
    section("Surface") {
      TuningSliderRow(label: "continent lo", value: $tuning.values.continentLo, range: 0...1)
      TuningSliderRow(label: "continent hi", value: $tuning.values.continentHi, range: 0...1)
      TuningSliderRow(label: "inland lo", value: $tuning.values.inlandLo, range: 0...1)
      TuningSliderRow(label: "inland hi", value: $tuning.values.inlandHi, range: 0...1)
      TuningSliderRow(label: "coast lo", value: $tuning.values.coastLo, range: 0...1)
      TuningSliderRow(label: "coast hi", value: $tuning.values.coastHi, range: 0...1)
      TuningSliderRow(label: "palette start", value: $tuning.values.paletteStart, range: 0...1)
      TuningSliderRow(label: "palette span", value: $tuning.values.paletteSpan, range: 0...1)
      TuningSliderRow(label: "irid drift speed", value: $tuning.values.iridescenceDriftSpeed, range: 0...1)
      TuningSliderRow(label: "irid drift amp", value: $tuning.values.iridescenceDriftAmp, range: 0...0.3)
      TuningSliderRow(label: "glow halo weight", value: $tuning.values.glowHaloWeight, range: 0...1)
      TuningSliderRow(label: "glow exposure", value: $tuning.values.glowExposure, range: 0.2...4)
      TuningSliderRow(label: "glow land mix", value: $tuning.values.glowLandMix, range: 0...1)
      TuningSliderRow(label: "glow brightness", value: $tuning.values.glowBrightness, range: 0...3)
      TuningSliderRow(label: "spark flash", value: $tuning.values.sparkFlash, range: 0...3)
      TuningSliderRow(label: "coast glow", value: $tuning.values.coastGlow, range: 0...2)
    } reset: {
      let d = EarthTuning.Values()
      tuning.values.continentLo = d.continentLo
      tuning.values.continentHi = d.continentHi
      tuning.values.inlandLo = d.inlandLo
      tuning.values.inlandHi = d.inlandHi
      tuning.values.coastLo = d.coastLo
      tuning.values.coastHi = d.coastHi
      tuning.values.paletteStart = d.paletteStart
      tuning.values.paletteSpan = d.paletteSpan
      tuning.values.iridescenceDriftSpeed = d.iridescenceDriftSpeed
      tuning.values.iridescenceDriftAmp = d.iridescenceDriftAmp
      tuning.values.glowHaloWeight = d.glowHaloWeight
      tuning.values.glowExposure = d.glowExposure
      tuning.values.glowLandMix = d.glowLandMix
      tuning.values.glowBrightness = d.glowBrightness
      tuning.values.sparkFlash = d.sparkFlash
      tuning.values.coastGlow = d.coastGlow
    }
  }

  private var emissiveSection: some View {
    section("Emissive") {
      TuningSliderRow(label: "continent", value: $tuning.values.emissiveContinent, range: 0...2)
      TuningSliderRow(label: "inland", value: $tuning.values.emissiveInland, range: 0...1.5)
      TuningSliderRow(label: "sea glow", value: $tuning.values.emissiveSeaGlow, range: 0...1.5)
      TuningSliderRow(label: "back glow", value: $tuning.values.emissiveBackGlow, range: 0...1.5)
      TuningSliderRow(label: "rim", value: $tuning.values.emissiveRim, range: 0...3)
      TuningSliderRow(label: "edge", value: $tuning.values.emissiveEdge, range: 0...2.5)
      TuningSliderRow(label: "body", value: $tuning.values.emissiveBody, range: 0...0.5)
      TuningSliderRow(label: "shimmer", value: $tuning.values.emissiveShimmer, range: 0...3)
      TuningSliderRow(label: "shimmer amp", value: $tuning.values.shimmerAmp, range: 0...0.3)
    } reset: {
      let d = EarthTuning.Values()
      tuning.values.emissiveContinent = d.emissiveContinent
      tuning.values.emissiveInland = d.emissiveInland
      tuning.values.emissiveSeaGlow = d.emissiveSeaGlow
      tuning.values.emissiveBackGlow = d.emissiveBackGlow
      tuning.values.emissiveRim = d.emissiveRim
      tuning.values.emissiveEdge = d.emissiveEdge
      tuning.values.emissiveBody = d.emissiveBody
      tuning.values.emissiveShimmer = d.emissiveShimmer
      tuning.values.shimmerAmp = d.shimmerAmp
    }
  }

  private var rimSection: some View {
    section("Rim & glass") {
      TuningSliderRow(label: "rim tightness", value: $tuning.values.rimTightness, range: 0.3...3)
      TuningSliderRow(label: "fresnel body exp", value: $tuning.values.fresnelBodyExponent, range: 0.5...8)
      TuningSliderRow(label: "refractive index", value: $tuning.values.refractiveIndex, range: 1.05...2.5)
      TuningSliderRow(label: "rim color mix", value: $tuning.values.rimColorMix, range: 0...1)
      TuningSliderRow(label: "back bleed base", value: $tuning.values.backBleedBase, range: 0...1)
      TuningSliderRow(label: "back bleed rim fade", value: $tuning.values.backBleedRimFade, range: 0...1)
      TuningSliderRow(label: "back bleed tint", value: $tuning.values.backBleedTint, range: 0...1)
      TuningSliderRow(label: "back lo", value: $tuning.values.backLo, range: 0...1)
      TuningSliderRow(label: "back hi", value: $tuning.values.backHi, range: 0...1)
      TuningSliderRow(label: "alpha continent", value: $tuning.values.alphaContinent, range: 0...1)
      TuningSliderRow(label: "alpha coast", value: $tuning.values.alphaCoast, range: 0...1)
      TuningSliderRow(label: "alpha rim", value: $tuning.values.alphaRim, range: 0...2.5)
      TuningSliderRow(label: "alpha sea", value: $tuning.values.alphaSea, range: 0...1)
      TuningSliderRow(label: "alpha back bleed", value: $tuning.values.backBleedAlpha, range: 0...1)
    } reset: {
      let d = EarthTuning.Values()
      tuning.values.rimTightness = d.rimTightness
      tuning.values.fresnelBodyExponent = d.fresnelBodyExponent
      tuning.values.refractiveIndex = d.refractiveIndex
      tuning.values.rimColorMix = d.rimColorMix
      tuning.values.backBleedBase = d.backBleedBase
      tuning.values.backBleedRimFade = d.backBleedRimFade
      tuning.values.backBleedTint = d.backBleedTint
      tuning.values.backLo = d.backLo
      tuning.values.backHi = d.backHi
      tuning.values.alphaContinent = d.alphaContinent
      tuning.values.alphaCoast = d.alphaCoast
      tuning.values.alphaRim = d.alphaRim
      tuning.values.alphaSea = d.alphaSea
      tuning.values.backBleedAlpha = d.backBleedAlpha
    }
  }

  private var atmosphereSection: some View {
    section("Atmosphere") {
      TuningSliderRow(label: "strength", value: $tuning.values.atmosphereStrength, range: 0...1.5)
      TuningSliderRow(label: "haze alpha", value: $tuning.values.hazeAlpha, range: 0...1.5)
      TuningSliderRow(label: "haze exponent", value: $tuning.values.hazeExponent, range: 0.5...6)
    } reset: {
      let d = EarthTuning.Values()
      tuning.values.atmosphereStrength = d.atmosphereStrength
      tuning.values.hazeAlpha = d.hazeAlpha
      tuning.values.hazeExponent = d.hazeExponent
    }
  }

  private var bloomSection: some View {
    section("Bloom & tonemap") {
      TuningSliderRow(label: "threshold lo", value: $tuning.values.bloomThresholdLo, range: 0...1)
      TuningSliderRow(label: "threshold hi", value: $tuning.values.bloomThresholdHi, range: 0...1.5)
      TuningSliderRow(label: "blur step", value: $tuning.values.blurStepScale, range: 0.5...8)
      TuningSliderRow(label: "strength", value: $tuning.values.bloomStrength, range: 0...1.5)
      TuningSliderRow(label: "tonemap k", value: $tuning.values.tonemapK, range: 0.3...4)
      TuningSliderRow(label: "alpha lift", value: $tuning.values.bloomAlphaLift, range: 0...1.5)
    } reset: {
      let d = EarthTuning.Values()
      tuning.values.bloomThresholdLo = d.bloomThresholdLo
      tuning.values.bloomThresholdHi = d.bloomThresholdHi
      tuning.values.blurStepScale = d.blurStepScale
      tuning.values.bloomStrength = d.bloomStrength
      tuning.values.tonemapK = d.tonemapK
      tuning.values.bloomAlphaLift = d.bloomAlphaLift
    }
  }

  private var breathSunSection: some View {
    section("Breath & sun") {
      TuningSliderRow(label: "breath scale amp", value: $tuning.values.breathScaleAmp, range: 0...0.06)
      TuningSliderRow(label: "inhale seconds", value: $tuning.values.breathInhaleSeconds, range: 1...10)
      TuningSliderRow(label: "exhale seconds", value: $tuning.values.breathExhaleSeconds, range: 1...12)
      TuningSliderRow(label: "sun x", value: $tuning.values.sunX, range: -1...1)
      TuningSliderRow(label: "sun y", value: $tuning.values.sunY, range: -1...1)
      TuningSliderRow(label: "sun z", value: $tuning.values.sunZ, range: -1...1)
    } reset: {
      let d = EarthTuning.Values()
      tuning.values.breathScaleAmp = d.breathScaleAmp
      tuning.values.breathInhaleSeconds = d.breathInhaleSeconds
      tuning.values.breathExhaleSeconds = d.breathExhaleSeconds
      tuning.values.sunX = d.sunX
      tuning.values.sunY = d.sunY
      tuning.values.sunZ = d.sunZ
    }
  }

  // MARK: - Looks

  private enum GlowLook { case classic, boost, beacon }

  /// Every look assigns the same field set — starting from defaults, then
  /// overlaying — so flips are deterministic and unrelated sliders survive.
  private func applyLook(_ look: GlowLook) {
    let d = EarthTuning.Values()
    let g = EarthGlowStore.Tuning()
    tuning.values.glowLandMix = d.glowLandMix
    tuning.values.glowBrightness = d.glowBrightness
    tuning.values.emissiveContinent = d.emissiveContinent
    tuning.values.emissiveInland = d.emissiveInland
    tuning.values.emissiveSeaGlow = d.emissiveSeaGlow
    tuning.values.coastGlow = d.coastGlow
    tuning.values.sparkFlash = d.sparkFlash
    tuning.values.litEmissive = d.litEmissive
    tuning.values.litColorMix = d.litColorMix
    glow.tuning.granularity = g.granularity
    glow.tuning.regionRadiusScale = g.regionRadiusScale

    switch look {
    case .classic:
      note("classic glow")
    case .boost:
      tuning.values.glowLandMix = 0
      tuning.values.glowBrightness = 1.2
      tuning.values.emissiveSeaGlow = 0
      tuning.values.coastGlow = 0.8
      tuning.values.sparkFlash = 1.0
      note("emissive boost")
    case .beacon:
      // Dark quiet world; whole lit regions burn bright and independent.
      tuning.values.glowLandMix = 0
      tuning.values.glowBrightness = 0
      tuning.values.emissiveContinent = 0.25
      tuning.values.emissiveInland = 0.1
      tuning.values.emissiveSeaGlow = 0
      tuning.values.coastGlow = 1.0
      tuning.values.sparkFlash = 1.0
      tuning.values.litEmissive = 2.5
      tuning.values.litColorMix = 0.75
      glow.tuning.granularity = .continent
      note("beacon")
    }
  }

  // MARK: - Store sections

  private var glowRegionSection: some View {
    section("Glow region") {
      VStack(alignment: .leading, spacing: 2) {
        Text("granularity")
          .font(DeepType.micro).tracking(1.2)
          .foregroundStyle(.driftGrey)
        Picker("granularity", selection: $glow.tuning.granularity) {
          ForEach(EarthGlowStore.Tuning.Granularity.allCases, id: \.self) { granularity in
            Text(granularity.rawValue.capitalized).tag(granularity)
          }
        }
        .pickerStyle(.segmented)
      }
      TuningSliderRow(label: "region radius ×", value: $glow.tuning.regionRadiusScale, range: 0.5...3)
      TuningSliderRow(label: "lit emissive", value: $tuning.values.litEmissive, range: 0...4)
      TuningSliderRow(label: "lit color mix", value: $tuning.values.litColorMix, range: 0...1)
    } reset: {
      let d = EarthTuning.Values()
      let g = EarthGlowStore.Tuning()
      glow.tuning.granularity = g.granularity
      glow.tuning.regionRadiusScale = g.regionRadiusScale
      tuning.values.litEmissive = d.litEmissive
      tuning.values.litColorMix = d.litColorMix
    }
  }

  private var glowPointsSection: some View {
    section("Glow points") {
      TuningSliderRow(label: "lerp tau", value: $glow.tuning.lerpTau, range: 0.1...3)
      TuningSliderRow(label: "soft cap", value: $glow.tuning.pointSoftCap, range: 1...20)
      TuningSliderRow(label: "base intensity", value: $glow.tuning.pointBaseIntensity, range: 0...1)
      TuningSliderRow(label: "intensity gain", value: $glow.tuning.pointIntensityGain, range: 0...1)
      TuningSliderRow(label: "base radius", value: $glow.tuning.pointBaseRadius, range: 0.005...0.2, logScale: true)
      TuningSliderRow(label: "radius gain", value: $glow.tuning.pointRadiusGain, range: 0...0.1)
    } reset: {
      let d = EarthGlowStore.Tuning()
      glow.tuning.lerpTau = d.lerpTau
      glow.tuning.pointSoftCap = d.pointSoftCap
      glow.tuning.pointBaseIntensity = d.pointBaseIntensity
      glow.tuning.pointIntensityGain = d.pointIntensityGain
      glow.tuning.pointBaseRadius = d.pointBaseRadius
      glow.tuning.pointRadiusGain = d.pointRadiusGain
    }
  }

  private var homeSection: some View {
    section("Home") {
      TuningSliderRow(label: "intensity", value: $glow.tuning.homeIntensity, range: 0...1.5)
      TuningSliderRow(label: "radius", value: $glow.tuning.homeRadius, range: 0.01...0.2, logScale: true)
      TuningSliderRow(label: "whiteness", value: $glow.tuning.homeWhiteness, range: 0...1)
      TuningSliderRow(label: "breath amp", value: $glow.tuning.homeBreathAmplitude, range: 0...0.5)
      TuningSliderRow(label: "breath rate", value: $glow.tuning.homeBreathRate, range: 0.05...3)
    } reset: {
      let d = EarthGlowStore.Tuning()
      glow.tuning.homeIntensity = d.homeIntensity
      glow.tuning.homeRadius = d.homeRadius
      glow.tuning.homeWhiteness = d.homeWhiteness
      glow.tuning.homeBreathAmplitude = d.homeBreathAmplitude
      glow.tuning.homeBreathRate = d.homeBreathRate
    }
  }

  private var sparksSection: some View {
    section("Sparks") {
      TuningSliderRow(label: "life", value: $glow.tuning.sparkLife, range: 0.2...6)
      TuningIntSliderRow(label: "cap", value: $glow.tuning.sparkCap, range: 1...32)
      TuningSliderRow(label: "radius", value: $glow.tuning.sparkRadius, range: 0.005...0.15, logScale: true)
      TuningSliderRow(label: "peak", value: $glow.tuning.sparkPeak, range: 0...3)
    } reset: {
      let d = EarthGlowStore.Tuning()
      glow.tuning.sparkLife = d.sparkLife
      glow.tuning.sparkCap = d.sparkCap
      glow.tuning.sparkRadius = d.sparkRadius
      glow.tuning.sparkPeak = d.sparkPeak
    }
  }

  private var interactionSection: some View {
    // EarthInteraction is not @Observable — manual bindings; the sliders are
    // the only writers, so no observation is needed.
    section("Interaction") {
      TuningSliderRow(
        label: "damping",
        value: Binding { scene.interaction.tuning.damping } set: { scene.interaction.tuning.damping = $0 },
        range: 0.8...0.99
      )
      TuningSliderRow(
        label: "drag sensitivity",
        value: Binding { scene.interaction.tuning.dragSensitivity } set: { scene.interaction.tuning.dragSensitivity = $0 },
        range: 0.001...0.02
      )
      TuningSliderRow(
        label: "idle after s",
        value: Binding { Float(scene.interaction.tuning.idleAfterSeconds) } set: { scene.interaction.tuning.idleAfterSeconds = TimeInterval($0) },
        range: 0...10
      )
      TuningSliderRow(
        label: "idle drift speed",
        value: Binding { scene.interaction.tuning.idleDriftSpeed } set: { scene.interaction.tuning.idleDriftSpeed = $0 },
        range: 0...0.3
      )
    } reset: {
      scene.interaction.tuning = EarthInteraction.Tuning()
    }
  }

  private var ripplesSection: some View {
    section("Ripples") {
      TuningIntSliderRow(label: "global cap", value: $ripples.tuning.globalCap, range: 1...24)
      TuningSliderRow(label: "spatial cooldown", value: tuningFloatBinding($ripples.tuning.spatialCooldown), range: 0...2)
      TuningSliderRow(label: "lifetime", value: tuningFloatBinding($ripples.tuning.lifetime), range: 0.2...4)
      TuningSliderRow(label: "cooldown angle °", value: $ripples.tuning.cooldownAngleDegrees, range: 0...15)
      TuningSliderRow(label: "ring start", value: $ripples.tuning.ringStartRadius, range: 0...0.3)
      TuningSliderRow(label: "ring end", value: $ripples.tuning.ringEndRadius, range: 0.05...1)
      TuningSliderRow(label: "ring opacity", value: $ripples.tuning.ringOpacity, range: 0...1)
    } reset: {
      ripples.tuning = EarthHaloRipples.Tuning()
    }
  }

  // MARK: - Section scaffold

  private func section(
    _ title: String,
    @ViewBuilder content: () -> some View,
    reset: @escaping () -> Void
  ) -> some View {
    let rows = content()
    return DisclosureGroup {
      VStack(spacing: 10) { rows }
        .padding(.top, 10)
    } label: {
      HStack {
        Text(title.uppercased())
          .font(DeepType.micro).tracking(1.2)
          .foregroundStyle(.deepPlum)
        Spacer()
        Button("Reset") { reset() }
          .buttonStyle(.borderless)
          .font(DeepType.micro)
          .foregroundStyle(.driftGrey)
      }
    }
    .tint(.lavenderMist)
    .padding(16)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  // MARK: - Export

  /// Mirror-based dump — one block per tuning struct, each line a paste-ready
  /// declaration, so transcribing good values back into the defaults is a
  /// straight replace. Never drifts when fields are added.
  private func exportSwift() -> String {
    var out = "// Earth tuning export\n"
    out += block("EarthTuning.Values", tuning.values)
    out += block("EarthGlowStore.Tuning", glow.tuning)
    out += block("EarthInteraction.Tuning", scene.interaction.tuning)
    out += block("EarthHaloRipples.Tuning", ripples.tuning)
    return out
  }

  private func block(_ title: String, _ subject: Any) -> String {
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

#Preview {
  // Hermetic: fresh scene + fresh tuning — never the live singleton.
  EarthTuningPanel(scene: .previewCities, tuning: EarthTuning())
}
#endif
