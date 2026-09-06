import AVFoundation
import Testing
@testable import Deep

/// Which hero footage is allowed to make a sound.
///
/// Exactly one clip in the app carries audio — Fuku's intro, which opens the
/// nightly broadcast — and it only reaches the speaker if its player claims
/// `.playback` first. Under the process default `.soloAmbient` the ring/silent
/// switch silences it, which is how the intro shipped mute on a real phone
/// while a simulator, having no such switch, sounded perfectly fine.
///
/// Serialized because the audio session is process-wide: these tests each put
/// it back where a fresh launch starts before making their claim, so they must
/// not run alongside one another.
@Suite(.serialized)
@MainActor
struct HeroVideoAudioTests {

  /// Puts the process back on the category a cold launch starts from, so an
  /// assertion can never pass on a session an earlier test already claimed.
  private func resetToLaunchDefault() {
    // Category only. Deactivating blocks on mediaserverd for long enough to
    // starve the real-clock timing suites this runs alongside.
    try? AVAudioSession.sharedInstance().setCategory(.soloAmbient)
  }

  private var category: AVAudioSession.Category {
    AVAudioSession.sharedInstance().category
  }

  private func introCoordinator() -> OneShotVideoView.Coordinator {
    OneShotVideoView.Coordinator(resource: FukuClip.intro.resource, fileExtension: "mp4")
  }

  @Test func theIntroClaimsThePlaybackSession() {
    resetToLaunchDefault()
    // Without this the assertion below could pass on a session that was already
    // `.playback` — i.e. prove nothing.
    #expect(category == .soloAmbient, "precondition: the reset took")

    let coordinator = introCoordinator()
    defer { coordinator.stop() }
    #expect(coordinator.player != nil, "fuku_intro.mp4 is missing from the bundle")

    coordinator.start(at: 0, muted: false, onEnded: {})

    #expect(category == .playback)
  }

  @Test func aMutedClipClaimsNothing() {
    // `.playback` takes the session outright. A clip nobody is going to hear
    // must not stop whatever the member is listening to in another app.
    resetToLaunchDefault()
    let coordinator = introCoordinator()
    defer { coordinator.stop() }

    coordinator.start(at: 0, muted: true, onEnded: {})

    #expect(category == .soloAmbient)
  }

  @Test func unmutingMidClipClaimsIt() {
    // Tapping ON AIR back on is the other moment there is something to hear.
    resetToLaunchDefault()
    let coordinator = introCoordinator()
    defer { coordinator.stop() }
    coordinator.start(at: 0, muted: true, onEnded: {})
    #expect(category == .soloAmbient, "precondition: it started silent")

    coordinator.setMuted(false)

    #expect(category == .playback)
  }

  @Test func theAmbientLoopsStaySilent() {
    // The other four Fuku clips are background, not broadcast. Their player is
    // muted where it is built and takes no parameter that could un-mute it —
    // the source files carry no audio track either, but the mute is what keeps
    // that true if the footage is ever recut.
    for clip in FukuClip.allCases where clip != .intro {
      let coordinator = LoopingVideoView.Coordinator(
        resource: clip.resource, fileExtension: "mp4"
      )
      defer { coordinator.stop() }
      #expect(coordinator.player?.isMuted == true, "\(clip.resource) must stay silent")
    }
  }
}
