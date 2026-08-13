#ifndef EARTH_TUNING_SHARED_H
#define EARTH_TUNING_SHARED_H

// Mirrored byte-for-byte from `EarthTuningUniforms` in EarthRendererTypes.swift.
// Keep struct layouts in sync. This header is the ONLY Metal-side definition —
// both EarthSurface.metal and EarthBloom.metal include it, so the mirror can't
// fork between passes. All slots are float4 (16-byte aligned, 224 bytes total;
// the Swift side asserts the stride in EarthRenderer.buildBuffers).
//
// Defaults live once, in EarthTuning.Values (Swift) — they reproduce the
// literals these fields replaced, so an untouched EarthTuning renders the
// shipped look exactly.
struct EarthTuningUniforms {
  float4 glowShape;      // x=haloWeight y=glowExposure z=glowLandMix w=glowBrightness
  float4 haze;           // x=hazeAlpha y=hazeExponent z=breathScaleAmp w=shimmerAmp
  float4 continentBand;  // x=continentLo y=continentHi z=inlandLo w=inlandHi
  float4 coastBand;      // x=coastLo y=coastHi z=backLo w=backHi
  float4 iridescence;    // x=driftSpeed y=driftAmp z=paletteStart w=paletteSpan
  float4 glass;          // x=fresnelBodyExp y=rimTightness z=refractiveIndex w=rimColorMix
  float4 backBleed;      // x=base y=rimFade z=tintT w=alphaWeight
  float4 emissiveA;      // x=continent y=inland z=seaGlow w=backGlow
  float4 emissiveB;      // x=rim y=edge z=body w=shimmer
  float4 alphaA;         // x=continent y=coastHalo z=rim w=seaGlow
  float4 bloomA;         // x=thresholdLo y=thresholdHi z=blurStepScale w=strength
  float4 bloomB;         // x=tonemapK y=alphaLift z=sparkFlash w=coastGlow
  float4 lit;            // x=litEmissive y=litColorMix z=volIntensity w=volHeight
  float4 volumetric;     // x=volSoftness y=volAlphaLift z=volTintMix w=volBackGhost
};

#endif
