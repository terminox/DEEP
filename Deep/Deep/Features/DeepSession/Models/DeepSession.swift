import Foundation

/// A guided breathing practice — the pattern the orb and cue text follow, and
/// how many rounds make one session.
struct DeepSession: Identifiable, Hashable {
  let id: UUID
  /// Serif card / screen title, e.g. "Balancing breath".
  let title: String
  /// One gentle line under the title, in the app's second-person voice.
  let tagline: String
  /// Seconds spent breathing in.
  let inhale: TimeInterval
  /// Seconds spent breathing out. Longer than the inhale — the physiological
  /// "sigh" ratio that settles the nervous system (see DESIGN.md).
  let exhale: TimeInterval
  /// How many inhale–exhale rounds complete the session.
  let cycles: Int

  init(
    id: UUID = UUID(),
    title: String,
    tagline: String,
    inhale: TimeInterval = 4,
    exhale: TimeInterval = 6,
    cycles: Int
  ) {
    self.id = id
    self.title = title
    self.tagline = tagline
    self.inhale = inhale
    self.exhale = exhale
    self.cycles = cycles
  }

  /// One full inhale–exhale round.
  var cycleDuration: TimeInterval { inhale + exhale }

  /// Whole-session length.
  var duration: TimeInterval { cycleDuration * TimeInterval(cycles) }

  /// Rounded-up whole minutes, for card captions ("1 min").
  var durationMinutes: Int { max(1, Int((duration / 60).rounded(.up))) }
}

/// The built-in sessions the app can offer. Static content for now; a remote
/// catalog can replace this without touching call sites.
enum DeepSessionLibrary {
  /// The daily practice: six slow rounds of 4s in / 6s out — about a minute.
  static let balancingBreath = DeepSession(
    title: "Balancing breath",
    tagline: "A minute of slow breathing to settle back into now",
    cycles: 6
  )
}
