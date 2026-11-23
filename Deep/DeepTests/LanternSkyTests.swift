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
}
#endif
