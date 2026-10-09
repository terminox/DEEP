import AVFoundation
import Testing
@testable import Deep

/// The streaming engine moving on by itself: a queue of real (silent, short)
/// audio files plays through, repeats, or stops exactly as `SoundQueue` says,
/// and every track that plays to its end is reported once.
///
/// Serialized because the audio session is process-wide, and real-clock:
/// each clip is a fraction of a second, so a run takes a few seconds.
@Suite(.serialized)
@MainActor
struct StreamingSoundPlayerTests {
  private static let collection = SoundCollection(
    title: "Engine fixture",
    subtitle: "",
    palette: .mist,
    imageURL: nil,
    tracks: []
  )

  /// Writes `count` silent clips to a temporary folder and returns them as
  /// queue entries, so playback never touches the network.
  private static func silentEntries(_ count: Int) throws -> [SoundQueueEntry] {
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("StreamingSoundPlayerTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    return try (0..<count).map { index in
      let url = folder.appendingPathComponent("\(index).caf")
      let file = try AVAudioFile(forWriting: url, settings: format.settings)
      let frames = AVAudioFrameCount(44_100 * 0.4)
      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
      buffer.frameLength = frames
      try file.write(from: buffer)
      return SoundQueueEntry(
        track: SoundTrack(id: "\(index)", title: "\(index)", duration: 0.4, audioURL: url),
        collection: collection
      )
    }
  }

  /// A player on a throwaway defaults suite, recording every finished track.
  private static func makePlayer(repeatMode: RepeatMode) -> (StreamingSoundPlayer, Recorder) {
    let defaults = UserDefaults(suiteName: "DeepTests-\(UUID().uuidString)")!
    let recorder = Recorder()
    // No session claim: it blocks the main thread long enough to starve the
    // real-clock suites running alongside, and playback doesn't need it here.
    let player = StreamingSoundPlayer(defaults: defaults, activateSession: {}) { track, _ in
      recorder.finished.append(track.id)
    }
    player.repeatMode = repeatMode
    return (player, recorder)
  }

  private final class Recorder {
    var finished: [String] = []
  }

  /// Polls until `condition` holds, or fails the test after `timeout`.
  private func waitUntil(
    timeout: Duration = .seconds(10),
    _ condition: () -> Bool
  ) async {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
      if ContinuousClock.now > deadline {
        Issue.record("timed out")
        return
      }
      try? await Task.sleep(for: .milliseconds(50))
    }
  }

  @Test("With Repeat off, a queue plays through by itself and stops on the first track")
  func playsThroughAndStops() async throws {
    let (player, recorder) = Self.makePlayer(repeatMode: .off)
    player.play(try Self.silentEntries(3), at: 0, shuffled: false)
    await waitUntil { !player.isPlaying }
    #expect(recorder.finished == ["0", "1", "2"])
    #expect(player.currentTrack?.id == "0")
    #expect(!player.isPlaying)
  }

  @Test("Repeat One plays the same track again")
  func repeatOneReplays() async throws {
    let (player, recorder) = Self.makePlayer(repeatMode: .one)
    player.play(try Self.silentEntries(2), at: 1, shuffled: false)
    await waitUntil { recorder.finished.count >= 3 }
    player.togglePlayPause()
    #expect(recorder.finished.prefix(3) == ["1", "1", "1"])
    #expect(player.currentTrack?.id == "1")
  }

  @Test("Repeat All runs the queue again from the top")
  func repeatAllWraps() async throws {
    let (player, recorder) = Self.makePlayer(repeatMode: .all)
    player.play(try Self.silentEntries(2), at: 0, shuffled: false)
    await waitUntil { recorder.finished.count >= 3 }
    player.togglePlayPause()
    #expect(recorder.finished.prefix(3) == ["0", "1", "0"])
  }

  @Test("Repeat is remembered for the next launch")
  func repeatModePersists() {
    let defaults = UserDefaults(suiteName: "DeepTests-\(UUID().uuidString)")!
    StreamingSoundPlayer(defaults: defaults).repeatMode = .one
    #expect(StreamingSoundPlayer(defaults: defaults).repeatMode == .one)
  }
}
