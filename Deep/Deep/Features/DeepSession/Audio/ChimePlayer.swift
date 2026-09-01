import AVFoundation
import os

/// The real bell: one short bundled `session_chime.m4a`, struck through
/// `AVAudioPlayer`.
///
/// A one-shot, unlike the app's two streaming engines — there is nothing to
/// queue, scrub or observe, so it holds no published state. The underlying
/// player is built lazily on the first `prepare()` (or `ring()`), which keeps
/// `ChimePlayer()` free enough to sit in a SwiftUI `@State` initial value and
/// be thrown away on every re-init SwiftUI makes of the owning struct.
@MainActor
final class ChimePlayer: ChimePlaying {
  /// How loud the bell sits. The asset is normalised to −1 dBFS, so this — not
  /// a re-encode — is the level knob.
  private static let level: Float = 0.6

  private let resource: String
  private let fileExtension: String

  private var player: AVAudioPlayer?
  private var didLoad = false
  private var sessionConfigured = false

  private let log = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "Deep", category: "Chime"
  )

  init(resource: String = "session_chime", fileExtension: String = "m4a") {
    self.resource = resource
    self.fileExtension = fileExtension
  }

  func prepare() {
    loadIfNeeded()?.prepareToPlay()
  }

  func ring() {
    configureSessionIfNeeded()
    guard let player = loadIfNeeded() else { return }
    player.currentTime = 0
    if !player.play() {
      log.error("chime did not start — the audio session refused the strike")
    }
  }

  /// Builds the player once. A missing or unreadable asset is logged and then
  /// stays silent for good — a bell that can't load must never take the ending
  /// of a practice down with it.
  private func loadIfNeeded() -> AVAudioPlayer? {
    guard !didLoad else { return player }
    didLoad = true

    let name = "\(resource).\(fileExtension)"
    guard let url = Bundle.main.url(forResource: resource, withExtension: fileExtension) else {
      log.error("chime asset \(name, privacy: .public) is missing from the bundle")
      return nil
    }
    guard let loaded = try? AVAudioPlayer(contentsOf: url) else {
      log.error("chime asset \(name, privacy: .public) could not be read")
      return nil
    }

    loaded.volume = Self.level
    player = loaded
    return loaded
  }

  /// The same category the two streaming engines set, behind the same latch. A
  /// member can reach the end of a practice having never played a track, which
  /// leaves the session on the default `.soloAmbient` — where the ring/silent
  /// switch would mute the bell, while the rest of the app's audio deliberately
  /// plays straight through it. Never deactivated: the session is process-wide
  /// and shared with both streamers.
  private func configureSessionIfNeeded() {
    guard !sessionConfigured else { return }
    sessionConfigured = true
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default)
    try? session.setActive(true)
  }
}
