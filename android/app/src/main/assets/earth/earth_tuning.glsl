// The live look parameters — iOS `Shaders/EarthTuningShared.h`, slot for
// slot. 18 vec4 = 288 bytes, std140, byte-identical to what
// `EarthTuning.pack` (core) writes; EarthRenderer checks the size.
//
// Bound at uniform-buffer binding 2 for the surface pass and every post pass.
//
// Android riders, in slots iOS reserves:
//   glass.y   rim tightness, already multiplied by the render scale
//   orbSeat.y the furthest any light volume reaches from the centre this
//             frame (the light-volume ray cull, EARTH3D_SPIKE.md Fix A);
//             0 = no cull

layout(std140) uniform EarthTuning {
  vec4 glowShape;      // x=haloWeight y=glowExposure z=glowLandMix w=glowBrightness
  vec4 haze;           // x=hazeAlpha y=hazeExponent z=breathScaleAmp w=shimmerAmp
  vec4 continentBand;  // x=continentLo y=continentHi z=inlandLo w=inlandHi
  vec4 coastBand;      // x=coastLo y=coastHi z=backLo w=backHi
  vec4 iridescence;    // x=driftSpeed y=driftAmp z=paletteStart w=paletteSpan
  vec4 glass;          // x=fresnelBodyExp y=rimTightness z=refractiveIndex w=rimColorMix
  vec4 backBleed;      // x=base y=rimFade z=tintT w=alphaWeight
  vec4 emissiveA;      // x=continent y=inland z=seaGlow w=backGlow
  vec4 emissiveB;      // x=rim y=edge z=body w=shimmer
  vec4 alphaA;         // x=continent y=coastHalo z=rim w=seaGlow
  vec4 bloomA;         // x=thresholdLo y=thresholdHi z=blurStepScale w=strength
  vec4 bloomB;         // x=tonemapK y=alphaLift z=sparkFlash w=coastGlow
  vec4 lit;            // x=litEmissive y=litColorMix z=volIntensity w=volHeight
  vec4 volumetric;     // x=volSoftness y=volAlphaLift z=volTintMix w=volBackGhost
  vec4 orbShape;       // x=sigmaScale y=exposure z=baseGain w=hotGain
  vec4 orbTint;        // x=coreWhiteBoost y=alphaLift z=haloWeight w=elevRatio
  vec4 burstShape;     // x=exposure y=baseGain z=hotGain w=alphaLift
  vec4 orbSeat;        // x=seatWeight y=lightVolumeReach zw=reserved
} T;
