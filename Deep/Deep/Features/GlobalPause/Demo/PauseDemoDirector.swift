#if DEBUG
import Foundation
import Observation

/// The participant-scale demo's one piece of shared state: whether it is armed,
/// and how many people are in the room.
///
/// A singleton, deliberately. Threading a new dependency from `AppRootView`
/// through `RootTabView`, `MainTabController` and the pause coordinator down to
/// the session controller is five files of production churn for an affordance
/// that only exists in Dev builds. This whole type is compiled out of Staging,
/// Pilot and Prod, and touches none of that plumbing.
@MainActor
@Observable
final class PauseDemoDirector {
  static let shared = PauseDemoDirector()

  /// The three sizes the client asked to see. Shortcuts, not a limit — any
  /// figure up to `maxParticipants` can be typed in Settings.
  static let tiers = [1_000, 10_000, 300_000]

  /// A sane ceiling for a typed figure. Far past anything plausible, and low
  /// enough that the arithmetic behind the crowd stays comfortable.
  static let maxParticipants = 10_000_000

  /// How long a tier change takes to land. Long enough that the count line's
  /// `.numericText()` transition reads as a climb and the globe's 0.8 s glow
  /// lerp has something to follow; short enough to scrub in front of someone.
  static let rampDuration: TimeInterval = 1.6

  /// How long the demo's meditation runs, matching the real one.
  static let meditationDuration: TimeInterval = 600

  private(set) var isEnabled = false

  /// The size being shown. `participantCount` eases toward this.
  private(set) var target = PauseDemoDirector.tiers[1]

  private var rampFrom = PauseDemoDirector.tiers[1]
  private var rampStartedAt = Date.distantPast

  /// The instant the current demo meditation began. Pinned when the demo is
  /// armed rather than recomputed per call — `GlobalPauseSession.meditationElapsed`
  /// measures from it, so a start that kept moving with `now` would freeze the
  /// progress line at zero forever.
  private var meditationStartedAt = Date()

  private init() {}

  /// The count right now — eased from the previous tier so a scrub climbs
  /// rather than jumps.
  ///
  /// Computed rather than stored on purpose: the repository reads it on every
  /// live poll, so the ramp needs no timer of its own. Being computed also means
  /// `@Observable` cannot see it change, which is why the session controller
  /// pumps a few extra polls through a scrub instead of waiting on observation.
  var participantCount: Int {
    let elapsed = Date().timeIntervalSince(rampStartedAt)
    guard elapsed < Self.rampDuration else { return target }
    let progress = max(0, elapsed / Self.rampDuration)
    // Ease out: the room fills quickly and settles, the way a real arrival wave
    // would rather than a linear counter.
    let eased = 1 - pow(1 - progress, 3)
    return rampFrom + Int((Double(target - rampFrom) * eased).rounded())
  }

  /// Arms or disarms the demo.
  ///
  /// Zeroing the clock is not optional. A dev server left in time travel can
  /// leave `SyncedClock.serverOffset` hours from the wall clock, and the demo's
  /// schedule is built against real time — without this the session would be
  /// "live" at an instant the app thinks is the middle of yesterday.
  func setEnabled(_ on: Bool, clock: SyncedClock) {
    isEnabled = on
    guard on else { return }
    clock.sync(serverNow: Date())
    meditationStartedAt = Date()
    rampFrom = target
    rampStartedAt = .distantPast
  }

  /// Moves to a new size over `rampDuration` — what the tier chips use, so the
  /// room visibly fills rather than cutting.
  func scrub(to count: Int) {
    guard count != target else { return }
    rampFrom = participantCount
    target = Self.clamped(count)
    rampStartedAt = Date()
  }

  /// Moves to a new size at once — what the slider uses. A drag is already a
  /// continuous gesture; easing on top of it would only make the number lag the
  /// thumb.
  func jump(to count: Int) {
    target = Self.clamped(count)
    rampFrom = target
    rampStartedAt = .distantPast
  }

  /// Keeps a typed figure inside something the demo can actually stand behind.
  private static func clamped(_ count: Int) -> Int {
    min(maxParticipants, max(0, count))
  }

  /// When the current demo meditation began, rolled forward a whole window at a
  /// time once one has run out — so the demo stays re-enterable all evening
  /// without relaunching the app.
  func meditationStart(at now: Date) -> Date {
    while now >= meditationStartedAt.addingTimeInterval(Self.meditationDuration) {
      meditationStartedAt.addTimeInterval(Self.meditationDuration)
    }
    return meditationStartedAt
  }

  /// A director of its own, for previews. Opening a preview must never reach
  /// the shared one — that would arm the demo for the running app.
  static func previewInstance(showing count: Int = PauseDemoDirector.tiers[1]) -> PauseDemoDirector {
    let director = PauseDemoDirector()
    director.jump(to: count)
    return director
  }
}
#endif
