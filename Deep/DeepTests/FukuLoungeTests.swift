import Foundation
import Testing
@testable import Deep

/// The arithmetic behind Fuku's Lounge. What it guards: the hero has to match
/// the member's own hour with no gap or overlap between the four bands, and the
/// nightly set has to be a *broadcast* — one clock, so two people who walk in a
/// minute apart are hearing the same bar, and nobody restarts it.
struct FukuLoungeTests {

  // MARK: - Time of day

  private func clip(atHour hour: Int) -> FukuClip {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: hour))!
    return .ambient(at: date, calendar: calendar)
  }

  @Test func coversEveryHourOfTheDay() {
    // No hour may fall through: a gap is a hero with no footage to play.
    for hour in 0..<24 {
      #expect(FukuClip.allCases.contains(clip(atHour: hour)))
    }
  }

  @Test func bandsMeetExactlyAtTheirBoundaries() {
    #expect(clip(atHour: 4) == .midnight)
    #expect(clip(atHour: 5) == .morning)
    #expect(clip(atHour: 11) == .morning)
    #expect(clip(atHour: 12) == .afternoon)
    #expect(clip(atHour: 16) == .afternoon)
    #expect(clip(atHour: 17) == .night)
    #expect(clip(atHour: 23) == .night)
    #expect(clip(atHour: 0) == .midnight)
  }

  @Test func introIsNeverAnAmbientClip() {
    // The intro carries sound and plays once; picking it as a background loop
    // would blare Fuku's voice at whoever opened the lounge at lunchtime.
    for hour in 0..<24 {
      #expect(clip(atHour: hour) != .intro)
    }
  }

  @Test func resourcesAreDistinct() {
    let names = Set(FukuClip.allCases.map(\.resource))
    #expect(names.count == FukuClip.allCases.count)
  }

  // MARK: - The broadcast

  private let start = Date(timeIntervalSince1970: 1_800_000_000)
  private let intro: TimeInterval = 10
  private let track: TimeInterval = 262

  /// A set with room to finish: the lobby phase runs well past its end.
  private func broadcast(hardStopAfter slack: TimeInterval = 600) -> LoungeBroadcast {
    LoungeBroadcast(
      startsAt: start,
      introDuration: intro,
      trackDuration: track,
      hardStop: start.addingTimeInterval(slack)
    )
  }

  private func stage(_ offset: TimeInterval, _ set: LoungeBroadcast? = nil) -> LoungeBroadcast.Stage {
    (set ?? broadcast()).stage(at: start.addingTimeInterval(offset))
  }

  /// `Date` arithmetic round-trips through a Double, so a sub-second offset
  /// comes back a hair off. Which stage it is, and roughly where, is the whole
  /// claim — the last bit of the mantissa is not.
  private func isIntro(_ stage: LoungeBroadcast.Stage, near elapsed: TimeInterval) -> Bool {
    guard case .intro(let actual) = stage else { return false }
    return abs(actual - elapsed) < 0.001
  }

  private func isMusic(_ stage: LoungeBroadcast.Stage, near offset: TimeInterval) -> Bool {
    guard case .music(let actual) = stage else { return false }
    return abs(actual - offset) < 0.001
  }

  @Test func isSilentBeforeItStarts() {
    #expect(stage(-1) == .off)
    #expect(broadcast().isOnAir(at: start.addingTimeInterval(-0.001)) == false)
  }

  @Test func opensOnTheIntroAtTheStroke() {
    #expect(stage(0) == .intro(elapsed: 0))
    #expect(isIntro(stage(9.9), near: 9.9))
  }

  @Test func handsOffToTheTrackWhenTheIntroEnds() {
    #expect(stage(intro) == .music(offset: 0))
    #expect(stage(intro + 30) == .music(offset: 30))
  }

  @Test func joinsLateInTheMiddleRatherThanStartingOver() {
    // The whole point of a broadcast: two minutes late is two minutes in.
    #expect(stage(intro + 120) == .music(offset: 120))
  }

  @Test func signsOffWhenTheTrackRunsOut() {
    #expect(isMusic(stage(intro + track - 0.001), near: track - 0.001))
    #expect(stage(intro + track) == .off)
    #expect(stage(intro + track + 3600) == .off)
  }

  @Test func isCutOffAtTheHardStop() {
    // A longer track uploaded into an untouched window may shorten the set, but
    // it must never still be playing when the pause takes over.
    let squeezed = broadcast(hardStopAfter: 60)
    #expect(squeezed.endsAt == start.addingTimeInterval(60))
    #expect(stage(59, squeezed) == .music(offset: 49))
    #expect(stage(60, squeezed) == .off)
  }

  @Test func handoffSurvivesTheClipEndingBeforeTheClockAgrees() {
    // AVFoundation reports the intro's end a hair early; `stage(at:)` would
    // still say "intro" and the set would freeze on a clip that has stopped and
    // will never report an end again.
    let set = broadcast()
    let justShy = start.addingTimeInterval(intro - 0.02)
    #expect(isIntro(set.stage(at: justShy), near: intro - 0.02))
    #expect(set.stageAfterIntro(at: justShy) == .music(offset: 0))
  }

  @Test func handoffAfterTheHardStopIsSilence() {
    let squeezed = broadcast(hardStopAfter: 5)
    #expect(squeezed.stageAfterIntro(at: start.addingTimeInterval(6)) == .off)
  }

  // MARK: - Building it from a schedule

  private func schedule(lobbyAudioURL: URL?, lobbyDuration: TimeInterval) -> PauseSchedule {
    PauseSchedule(
      pauseDate: "2026-09-01",
      timezone: "Asia/Bangkok",
      phases: [
        PausePhaseWindow(key: .lobby, startsAt: start, endsAt: start.addingTimeInterval(590))
      ],
      lobbyAudioURL: lobbyAudioURL,
      lobbyDuration: lobbyDuration,
      meditationAudioURL: nil,
      meditationDuration: 132,
      welcomeMessages: [],
      intentions: []
    )
  }

  @Test func buildsTheSetFromTheLobbyPhase() {
    let set = schedule(lobbyAudioURL: URL(string: "https://x/t.mp3"), lobbyDuration: track)
      .loungeBroadcast(introDuration: intro)
    #expect(set?.startsAt == start)
    #expect(set?.hardStop == start.addingTimeInterval(590))
    #expect(set?.endsAt == start.addingTimeInterval(intro + track))
  }

  @Test func thereIsNoSetWithoutATrack() {
    #expect(schedule(lobbyAudioURL: nil, lobbyDuration: track)
      .loungeBroadcast(introDuration: intro) == nil)
  }

  @Test func thereIsNoSetWithoutALength() {
    // An older server sends no length; a broadcast of unknown duration would
    // leave the badge lit until the welcome.
    #expect(schedule(lobbyAudioURL: URL(string: "https://x/t.mp3"), lobbyDuration: 0)
      .loungeBroadcast(introDuration: intro) == nil)
  }
}
