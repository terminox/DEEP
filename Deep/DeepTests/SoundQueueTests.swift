import Testing
import Foundation
@testable import Deep

/// The queue rules every DEEP Sound engine shares: a playlist plays through in
/// order and stops, Repeat All runs it again, Repeat One holds a track, the
/// skip buttons move the way Apple Music's do, Shuffle deals every track once,
/// and a track with no audio is never what plays.
@MainActor
struct SoundQueueTests {
  /// Deterministic shuffles, so a failure replays exactly.
  private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
      state &+= 0x9E37_79B9_7F4A_7C15
      var z = state
      z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
      z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
      return z ^ (z >> 31)
    }
  }

  private static let collection = SoundCollection(
    title: "Queue fixture",
    subtitle: "",
    palette: .mist,
    imageURL: nil,
    tracks: []
  )

  /// `count` tracks named "0", "1", …; those in `silent` have no audio.
  private static func entries(_ count: Int, silent: Set<Int> = []) -> [SoundQueueEntry] {
    (0..<count).map { index in
      SoundQueueEntry(
        track: SoundTrack(
          id: "\(index)",
          title: "\(index)",
          duration: 60,
          audioURL: silent.contains(index) ? nil : URL(string: "https://deep.test/\(index).mp3")
        ),
        collection: collection
      )
    }
  }

  private static func queue(
    _ entries: [SoundQueueEntry],
    at index: Int? = 0,
    shuffled: Bool = false,
    repeatMode: RepeatMode = .off,
    seed: UInt64 = 7
  ) -> SoundQueue {
    var generator = SeededGenerator(state: seed)
    return SoundQueue(
      entries,
      startingAt: index,
      shuffled: shuffled,
      repeatMode: repeatMode,
      using: &generator
    )
  }

  // MARK: - Natural end

  @Test("Repeat off plays the playlist through in order, then stops on the first track")
  func repeatOffStopsAtTheEnd() {
    var queue = Self.queue(Self.entries(3))
    #expect(queue.current?.track.id == "0")
    let continued = queue.advanceAfterEnd()
    #expect(continued)
    #expect(queue.current?.track.id == "1")
    let continuedAgain = queue.advanceAfterEnd()
    #expect(continuedAgain)
    #expect(queue.current?.track.id == "2")
    #expect(queue.upcoming == nil)
    let continuedPastTheEnd = queue.advanceAfterEnd()
    #expect(!continuedPastTheEnd)
    #expect(queue.current?.track.id == "0")
  }

  @Test("Repeat All runs the playlist again after the last track")
  func repeatAllWraps() {
    var queue = Self.queue(Self.entries(3), at: 2, repeatMode: .all)
    #expect(queue.upcoming?.track.id == "0")
    let continued = queue.advanceAfterEnd()
    #expect(continued)
    #expect(queue.current?.track.id == "0")
  }

  @Test("Repeat One holds the current track")
  func repeatOneHolds() {
    var queue = Self.queue(Self.entries(3), at: 1, repeatMode: .one)
    #expect(queue.upcoming?.track.id == "1")
    let continued = queue.advanceAfterEnd()
    #expect(continued)
    #expect(queue.current?.track.id == "1")
  }

  @Test("A single track repeats only when asked to")
  func singleTrack() {
    var off = Self.queue(Self.entries(1))
    #expect(off.upcoming == nil)
    let offContinued = off.advanceAfterEnd()
    #expect(!offContinued)

    var all = Self.queue(Self.entries(1), repeatMode: .all)
    #expect(all.upcoming?.track.id == "0")
    let allContinued = all.advanceAfterEnd()
    #expect(allContinued)
  }

  @Test("Changing the mode mid-track changes what comes next")
  func modeChangeRetargetsUpcoming() {
    var queue = Self.queue(Self.entries(3), at: 2)
    #expect(queue.upcoming == nil)
    queue.repeatMode = .all
    #expect(queue.upcoming?.track.id == "0")
    queue.repeatMode = .one
    #expect(queue.upcoming?.track.id == "2")
  }

  @Test("The Repeat control steps off, all, one, and round again")
  func repeatCycle() {
    #expect(RepeatMode.off.next == .all)
    #expect(RepeatMode.all.next == .one)
    #expect(RepeatMode.one.next == .off)
  }

  // MARK: - Skipping

  @Test("Next moves on even in Repeat One")
  func nextLeavesRepeatOne() {
    var queue = Self.queue(Self.entries(3), repeatMode: .one)
    let carriesOn = queue.skipForward()
    #expect(carriesOn)
    #expect(queue.current?.track.id == "1")
  }

  @Test("Next from the last track wraps, carrying on only under Repeat All")
  func nextWrapsAtTheEnd() {
    var off = Self.queue(Self.entries(3), at: 2)
    let offCarriesOn = off.skipForward()
    #expect(!offCarriesOn)
    #expect(off.current?.track.id == "0")

    var all = Self.queue(Self.entries(3), at: 2, repeatMode: .all)
    let allCarriesOn = all.skipForward()
    #expect(allCarriesOn)
    #expect(all.current?.track.id == "0")
  }

  @Test("Previous steps back, and wraps from the first track only under Repeat All")
  func previousAtTheStart() {
    var middle = Self.queue(Self.entries(3), at: 1)
    let middleMoved = middle.skipBack()
    #expect(middleMoved)
    #expect(middle.current?.track.id == "0")

    var off = Self.queue(Self.entries(3))
    let offMoved = off.skipBack()
    #expect(!offMoved)
    #expect(off.current?.track.id == "0")

    var all = Self.queue(Self.entries(3), repeatMode: .all)
    let allMoved = all.skipBack()
    #expect(allMoved)
    #expect(all.current?.track.id == "2")
  }

  // MARK: - Shuffle

  @Test("Shuffle plays every track exactly once, starting from the chosen one")
  func shuffleIsAPermutation() {
    var queue = Self.queue(Self.entries(8), at: 5, shuffled: true)
    #expect(queue.isShuffled)
    var played = [queue.current!.track.id]
    while queue.advanceAfterEnd() {
      played.append(queue.current!.track.id)
    }
    #expect(played.first == "5")
    #expect(played.count == 8)
    #expect(Set(played) == Set((0..<8).map(String.init)))
    #expect(played != (0..<8).map(String.init), "seed 7 deals a real shuffle")
  }

  @Test("Shuffle with no start begins on a random track")
  func shuffleRandomStart() {
    let starts = Set((0..<20).map { seed in
      Self.queue(Self.entries(8), at: nil, shuffled: true, seed: UInt64(seed)).current!.track.id
    })
    #expect(starts.count > 1)
  }

  @Test("Turning shuffle on keeps the current track; turning it off resumes the original order")
  func toggleShuffleKeepsTheCurrentTrack() {
    var queue = Self.queue(Self.entries(6), at: 3)
    var generator = SeededGenerator(state: 11)
    queue.setShuffled(true, using: &generator)
    #expect(queue.current?.track.id == "3")

    queue.setShuffled(false, using: &generator)
    #expect(!queue.isShuffled)
    #expect(queue.current?.track.id == "3")
    #expect(queue.upcoming?.track.id == "4")
  }

  // MARK: - Tracks with no audio

  @Test("A track with no audio is skipped, never played")
  func silentTracksAreSkipped() {
    var queue = Self.queue(Self.entries(3, silent: [1]))
    #expect(queue.upcoming?.track.id == "2")
    let continued = queue.advanceAfterEnd()
    #expect(continued)
    #expect(queue.current?.track.id == "2")
    let moved = queue.skipBack()
    #expect(moved)
    #expect(queue.current?.track.id == "0")
  }

  @Test("Starting on a track with no audio moves on to one that has it")
  func silentStartMovesOn() {
    let queue = Self.queue(Self.entries(3, silent: [0, 1]))
    #expect(queue.current?.track.id == "2")
  }

  @Test("A queue where nothing can play stops instead of spinning")
  func allSilentStops() {
    var queue = Self.queue(Self.entries(3, silent: [0, 1, 2]), repeatMode: .all)
    #expect(queue.upcoming == nil)
    let continued = queue.advanceAfterEnd()
    #expect(!continued)
    let carriesOn = queue.skipForward()
    #expect(!carriesOn)
    let movedOn = queue.skipUnplayable()
    #expect(!movedOn)
  }

  @Test("A track that fails to load moves on, past Repeat One")
  func failedTrackMovesOn() {
    var queue = Self.queue(Self.entries(3), repeatMode: .one)
    let movedOn = queue.skipUnplayable()
    #expect(movedOn)
    #expect(queue.current?.track.id == "1")

    var last = Self.queue(Self.entries(3), at: 2)
    let lastMovedOn = last.skipUnplayable()
    #expect(!lastMovedOn)
    #expect(last.current?.track.id == "0")
  }
}
