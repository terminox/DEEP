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

  /// Rounded-up whole minutes — the unit a session's length is chosen and
  /// credited in. Exact for any session built by `lasting(minutes:)`.
  var durationMinutes: Int { max(1, Int((duration / 60).rounded(.up))) }
}

/// The lengths a Deep Session can be set to, in whole minutes.
enum DeepSessionLength {
  static let range = 1...10
  /// What a first visit opens on — the one-minute practice the app shipped
  /// with. Every visit after that opens on whatever was last chosen.
  static let opening = range.lowerBound
}

extension DeepSession {
  /// A copy of this practice stretched to `minutes`, in however many rounds its
  /// own pattern needs to fill that length. The id rides along: it is the same
  /// practice, only longer — and a fresh id on every render would churn the
  /// presenter that carries it into the run.
  func lasting(minutes: Int) -> DeepSession {
    DeepSession(
      id: id,
      title: title,
      tagline: tagline,
      inhale: inhale,
      exhale: exhale,
      cycles: max(1, Int((TimeInterval(minutes) * 60 / cycleDuration).rounded()))
    )
  }
}

/// The built-in sessions the app can offer. Static content for now; a remote
/// catalog can replace this without touching call sites.
enum DeepSessionLibrary {
  /// The daily practice: slow rounds of 4s in / 6s out, run for as long as the
  /// threshold's slider is set to. The stored `cycles` is the shortest offer.
  ///
  /// Computed rather than stored: a `static let` resolves its copy once per
  /// process, so picking a language would leave this session named in whichever
  /// one the app happened to launch in.
  static var balancingBreath: DeepSession {
    DeepSession(
      title: String(localized: "Balancing breath", bundle: .app, locale: .app),
      tagline: String(
        localized: "Slow breathing to settle back into now",
        bundle: .app,
        locale: .app
      ),
      cycles: 6
    )
  }
}
