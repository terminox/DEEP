import Foundation

/// How a queue carries on once a track plays to its end.
enum RepeatMode: String, CaseIterable {
  /// Play through to the last track, then stop.
  case off
  /// Run the whole queue again after the last track.
  case all
  /// Play the current track again and again.
  case one

  /// The mode the Repeat control steps to — off, all, one, and round again.
  var next: RepeatMode {
    switch self {
    case .off: .all
    case .all: .one
    case .one: .off
    }
  }
}

/// What plays, in which order, and what comes next — the rules every
/// `SoundPlaying` engine shares, with no audio attached.
///
/// `entries` keep the order they arrived in; `order` is the play order over
/// them (the identity, or a shuffle), and `position` walks `order`. A track the
/// engine can't play (for the streaming engine, one with no audio) is skipped
/// at every step.
struct SoundQueue {
  private(set) var entries: [SoundQueueEntry] = []
  /// Play order, as indices into `entries`.
  private(set) var order: [Int] = []
  /// Where in `order` the current track sits.
  private(set) var position: Int = 0
  var repeatMode: RepeatMode = .off
  private(set) var isShuffled = false
  private let canPlay: (SoundQueueEntry) -> Bool

  /// `canPlay` defaults to `hasAudio`, the streaming engine's rule.
  init(repeatMode: RepeatMode = .off, canPlay: ((SoundQueueEntry) -> Bool)? = nil) {
    self.repeatMode = repeatMode
    self.canPlay = canPlay ?? Self.hasAudio
  }

  /// A queue over `entries`, starting from `index` — or, shuffled with no
  /// index, from a random track. Shuffled, the start plays first and the rest
  /// follow in random order. A start without audio moves on to the next track
  /// that has some.
  init(
    _ entries: [SoundQueueEntry],
    startingAt index: Int?,
    shuffled: Bool,
    repeatMode: RepeatMode,
    canPlay: ((SoundQueueEntry) -> Bool)? = nil,
    using generator: inout some RandomNumberGenerator
  ) {
    let canPlay = canPlay ?? Self.hasAudio
    self.entries = entries
    self.repeatMode = repeatMode
    self.canPlay = canPlay
    self.isShuffled = shuffled
    guard !entries.isEmpty else { return }

    let start: Int
    if let index {
      start = min(max(0, index), entries.count - 1)
    } else if shuffled {
      let playable = entries.indices.filter { canPlay(entries[$0]) }
      start = playable.randomElement(using: &generator) ?? 0
    } else {
      start = 0
    }

    if shuffled {
      order = [start] + entries.indices.filter { $0 != start }.shuffled(using: &generator)
      position = 0
    } else {
      order = Array(entries.indices)
      position = start
    }

    if !canPlay(entries[order[position]]),
       let found = nextPlayable(after: position, wrapping: true) {
      position = found.position
    }
  }

  // MARK: - Reading

  var isEmpty: Bool { entries.isEmpty }

  var current: SoundQueueEntry? {
    order.indices.contains(position) ? entries[order[position]] : nil
  }

  /// What starts when the current track ends on its own; `nil` when the queue
  /// stops there.
  var upcoming: SoundQueueEntry? {
    upcomingPosition.map { entries[order[$0]] }
  }

  private var upcomingPosition: Int? {
    guard !order.isEmpty else { return nil }
    switch repeatMode {
    case .one:
      if isPlayable(at: position) { return position }
      return nextPlayable(after: position, wrapping: false)?.position
    case .all:
      return nextPlayable(after: position, wrapping: true)?.position
    case .off:
      return nextPlayable(after: position, wrapping: false)?.position
    }
  }

  // MARK: - Moving

  /// The current track ended on its own. Moves to `upcoming` and returns
  /// `true`; at the end of an unrepeated queue it returns to the first track
  /// and returns `false` — the queue has finished.
  @discardableResult
  mutating func advanceAfterEnd() -> Bool {
    if let next = upcomingPosition {
      position = next
      return true
    }
    rewind()
    return false
  }

  /// The listener skipped forward. Always moves on, Repeat One included, and
  /// wraps from the last track to the first. Returns whether playback should
  /// carry on: not after wrapping an unrepeated queue, and not when nothing
  /// in it can play.
  @discardableResult
  mutating func skipForward() -> Bool {
    guard let next = nextPlayable(after: position, wrapping: true) else { return false }
    position = next.position
    return !next.wrapped || repeatMode == .all
  }

  /// The listener skipped back. Moves to the previous track and returns
  /// `true`; at the first track of an unrepeated queue there is nowhere to go
  /// and it returns `false`, so the caller restarts the current one instead.
  @discardableResult
  mutating func skipBack() -> Bool {
    guard order.count > 1 else { return false }
    for step in 1..<order.count {
      let raw = position - step
      if raw < 0 && repeatMode != .all { return false }
      let candidate = (raw + order.count) % order.count
      if isPlayable(at: candidate) {
        position = candidate
        return true
      }
    }
    return false
  }

  /// The current track could not play. Moves to the next track that might —
  /// past Repeat One, which would only fail again — and returns `true`; at the
  /// end of an unrepeated queue it returns to the first track and `false`.
  @discardableResult
  mutating func skipUnplayable() -> Bool {
    if let next = nextPlayable(after: position, wrapping: repeatMode == .all) {
      position = next.position
      return true
    }
    rewind()
    return false
  }

  /// Shuffling keeps the current track where it is and deals the rest in a
  /// random order after it; un-shuffling restores the original order, still
  /// on the current track.
  mutating func setShuffled(_ shuffled: Bool, using generator: inout some RandomNumberGenerator) {
    guard shuffled != isShuffled else { return }
    isShuffled = shuffled
    guard order.indices.contains(position) else { return }
    let currentIndex = order[position]
    if shuffled {
      order = [currentIndex]
        + entries.indices.filter { $0 != currentIndex }.shuffled(using: &generator)
      position = 0
    } else {
      order = Array(entries.indices)
      position = currentIndex
    }
  }

  // MARK: - Helpers

  /// The streaming engine's rule: a track plays when it has audio to stream.
  nonisolated static func hasAudio(_ entry: SoundQueueEntry) -> Bool {
    entry.track.audioURL != nil
  }

  /// A new queue over different entries, keeping this one's repeat mode and
  /// playability rule.
  func replacing(
    with entries: [SoundQueueEntry],
    startingAt index: Int?,
    shuffled: Bool,
    using generator: inout some RandomNumberGenerator
  ) -> SoundQueue {
    SoundQueue(
      entries,
      startingAt: index,
      shuffled: shuffled,
      repeatMode: repeatMode,
      canPlay: canPlay,
      using: &generator
    )
  }

  private func isPlayable(at position: Int) -> Bool {
    canPlay(entries[order[position]])
  }

  /// Back to the first track that can play — where a finished queue rests.
  private mutating func rewind() {
    position = order.indices.first { isPlayable(at: $0) } ?? 0
  }

  /// The next playable position after `position`, and whether reaching it
  /// meant wrapping past the end. With wrapping, a lone playable track finds
  /// itself.
  private func nextPlayable(after position: Int, wrapping: Bool) -> (position: Int, wrapped: Bool)? {
    guard !order.isEmpty else { return nil }
    for step in 1...order.count {
      let raw = position + step
      let wrapped = raw >= order.count
      if wrapped && !wrapping { return nil }
      let candidate = raw % order.count
      if isPlayable(at: candidate) { return (candidate, wrapped) }
    }
    return nil
  }
}
