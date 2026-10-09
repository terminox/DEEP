import Testing
import AVFoundation
@testable import Deep

/// The streaming player's answers to the audio session. The regression this
/// guards: a call or Siri silenced playback while the UI still said playing,
/// and a finished interruption never brought the track back.
struct SoundSessionEventTests {
  private func interruption(
    _ type: AVAudioSession.InterruptionType,
    options: AVAudioSession.InterruptionOptions? = nil
  ) -> [AnyHashable: Any] {
    var info: [AnyHashable: Any] = [AVAudioSessionInterruptionTypeKey: type.rawValue]
    if let options {
      info[AVAudioSessionInterruptionOptionKey] = options.rawValue
    }
    return info
  }

  @Test("Interruption payloads parse, with the system's resume suggestion")
  func parsesInterruptions() {
    #expect(SoundSessionEvent(interruption: interruption(.began)) == .interruptionBegan)
    #expect(
      SoundSessionEvent(interruption: interruption(.ended, options: .shouldResume))
        == .interruptionEnded(shouldResume: true)
    )
    #expect(
      SoundSessionEvent(interruption: interruption(.ended))
        == .interruptionEnded(shouldResume: false)
    )
    #expect(SoundSessionEvent(interruption: nil) == nil)
  }

  @Test("Only a lost output device counts as a route change worth pausing for")
  func parsesRouteChanges() {
    let lost: [AnyHashable: Any] = [
      AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue,
    ]
    let added: [AnyHashable: Any] = [
      AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue,
    ]
    #expect(SoundSessionEvent(routeChange: lost) == .routeLost)
    #expect(SoundSessionEvent(routeChange: added) == nil)
  }

  @Test("An interruption pauses running playback and remembers to resume it")
  func interruptionPausesAndResumes() {
    #expect(
      SoundSessionEvent.interruptionBegan.response(isPlaying: true, resumesAfterInterruption: false)
        == .pause(remember: true)
    )
    #expect(
      SoundSessionEvent.interruptionEnded(shouldResume: true)
        .response(isPlaying: false, resumesAfterInterruption: true) == .resume
    )
  }

  @Test("Nothing resumes that the listener had paused, or the system says not to")
  func noUnaskedResume() {
    #expect(
      SoundSessionEvent.interruptionBegan.response(isPlaying: false, resumesAfterInterruption: true)
        == .forget
    )
    #expect(
      SoundSessionEvent.interruptionEnded(shouldResume: true)
        .response(isPlaying: false, resumesAfterInterruption: false) == .forget
    )
    #expect(
      SoundSessionEvent.interruptionEnded(shouldResume: false)
        .response(isPlaying: false, resumesAfterInterruption: true) == .forget
    )
  }

  @Test("Headphones coming out pause playback for good")
  func routeLostPauses() {
    #expect(
      SoundSessionEvent.routeLost.response(isPlaying: true, resumesAfterInterruption: false)
        == .pause(remember: false)
    )
    #expect(
      SoundSessionEvent.routeLost.response(isPlaying: false, resumesAfterInterruption: false)
        == .ignore
    )
  }
}
