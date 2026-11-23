#if EXPERIMENTS
import Foundation
import Testing
@testable import Deep

/// The Lantern Exhibition releases one lantern for every four seconds of the sit.
@MainActor
struct LanternSkyTests {
  @Test("A 3, 5 or 10-minute sit fills the sky with 45, 75 or 150 lanterns", arguments: [
    (SitLength.three, 45), (.five, 75), (.ten, 150)
  ])
  func lanternCount(length: SitLength, expected: Int) {
    let sit = LiveSit.replaying(.regular, length: length.seconds)
    let sky = LanternSky(length: length.seconds)
    #expect(sky.catchUp(with: sit).count == expected)
    #expect(sky.capacity == expected)
  }

  @Test("Lanterns released as the sit goes are the ones released all at once")
  func incrementalMatchesWhole() {
    let recording = EEGSessionRecording.regular
    let whole = LanternSky(length: 300)
    whole.catchUp(with: .replaying(recording, length: 300))

    let live = LiveSit(length: 300)
    let growing = LanternSky(length: 300)
    for index in 0..<3000 {
      let frame = recording.frames[index]
      var artifacts: [EEGArtifactKind] = []
      if frame.blink { artifacts.append(.blink) }
      if frame.jawClench { artifacts.append(.jawClench) }
      live.absorb(HeadbandTick(frame: frame, artifacts: artifacts, fit: SensorFit(channels: frame.fit, headbandOn: true)))
      if index % 37 == 0 { growing.catchUp(with: live) }
    }
    growing.catchUp(with: live)
    #expect(growing.lanterns == whole.lanterns)
  }

  @Test("No lantern before its four seconds are up")
  func waitsForWindow() {
    let sky = LanternSky(length: 180)
    #expect(sky.catchUp(with: .replaying(.regular, length: 180, upTo: 3.9)).isEmpty)
    #expect(sky.catchUp(with: .replaying(.regular, length: 180, upTo: 4)).count == 1)
  }

  @Test("Every lantern carries a flower of 6 to 10 petals")
  func flowerPetals() {
    let lanterns = LanternSky(length: 600).catchUp(with: .replaying(.regular, length: 600))
    #expect(lanterns.allSatisfy { (6...10).contains($0.petals.count) })
    #expect(lanterns.allSatisfy { (0...1).contains($0.ruffle) })
    // A whole sit is not one flower over and over.
    #expect(Set(lanterns.map(\.petals.count)).count > 1)
  }

  @Test("A busier mind grows more petals")
  func busyGrowsPetals() {
    let quiet = BandPowers(delta: 0.3, theta: 0.25, alpha: 0.35, beta: 0.05, gamma: 0.05)
    let busy = BandPowers(delta: 0.2, theta: 0.1, alpha: 0.1, beta: 0.45, gamma: 0.15)
    #expect(SkyLantern.petalCount(for: quiet) == 6)
    #expect(SkyLantern.petalCount(for: busy) == 10)
  }

  @Test("Alpha, theta and a busy mind print different petal colours")
  func petalColours() {
    let alpha = LanternPetalInk.tint(BandPowers(delta: 0.2, theta: 0.1, alpha: 0.6, beta: 0.05, gamma: 0.05))
    let theta = LanternPetalInk.tint(BandPowers(delta: 0.2, theta: 0.6, alpha: 0.1, beta: 0.05, gamma: 0.05))
    let busy = LanternPetalInk.tint(BandPowers(delta: 0.1, theta: 0.1, alpha: 0.1, beta: 0.6, gamma: 0.1))
    #expect(alpha.green > alpha.red)
    #expect(theta.blue > theta.green)
    #expect(busy.red > busy.green)
  }
}
#endif
