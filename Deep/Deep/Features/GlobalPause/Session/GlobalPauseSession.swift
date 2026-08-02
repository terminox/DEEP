import SwiftUI
import Observation

/// The Global Pause engine: holds tonight's schedule, tracks whether the
/// nightly meditation is live against the synced clock (flipping
/// `isMeditationLive` at exact window boundaries), and scopes the live
/// presence/polling loops to the time the session screen is open.
///
/// Lives app-long (built in `AppDependencies`) because the feed needs the
/// schedule line even when the session has never been opened.
@MainActor
@Observable
final class GlobalPauseSession {
  let clock: SyncedClock

  /// Tonight's resolved schedule; nil until the first fetch lands.
  private(set) var schedule: PauseSchedule?
  /// True exactly while the nightly meditation window is open — the one state
  /// the live session has. The boundary timer flips it at the window edges.
  private(set) var isMeditationLive = false
  private(set) var participantCount = 0
  private(set) var participantsByCountry: [String: Int] = [:]

  /// When the next meditation begins — the countdown target for the card's
  /// caption. Nil until the schedule lands.
  var nextMeditationStart: Date? {
    schedule?.nextMeditationStart(after: clock.now)
  }

  /// Seconds into the meditation stream at the synced clock's now.
  var meditationElapsed: TimeInterval {
    guard let start = schedule?.window(for: .meditation)?.startsAt else { return 0 }
    return max(0, clock.now.timeIntervalSince(start))
  }

  var meditationDuration: TimeInterval { schedule?.meditationDuration ?? 0 }

  private let repository: any PauseEventRepository
  @ObservationIgnored private var boundaryTask: Task<Void, Never>?
  @ObservationIgnored private var heartbeatTask: Task<Void, Never>?
  @ObservationIgnored private var pollTask: Task<Void, Never>?
  @ObservationIgnored private var foregroundObserver: NSObjectProtocol?
  /// Joins already turned into ripples, so a poll never replays old ones.
  @ObservationIgnored private var seenJoins: Set<String> = []
  @ObservationIgnored private var pendingJoins: [String] = []

  /// One stable anonymous identity per install, so reopening the session never
  /// double-counts (the server keys signed-in users by user id instead).
  @ObservationIgnored private lazy var presenceID: String = {
    let key = "pause.presenceId"
    if let existing = UserDefaults.standard.string(forKey: key) { return existing }
    let fresh = UUID().uuidString
    UserDefaults.standard.set(fresh, forKey: key)
    return fresh
  }()

  init(clock: SyncedClock, repository: any PauseEventRepository) {
    self.clock = clock
    self.repository = repository
    foregroundObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.willEnterForegroundNotification,
      object: nil,
      queue: .main
    ) { _ in
      // Background suspension freezes Task.sleep timers mid-count; recompute
      // from the wall clock the moment we're back.
      Task { @MainActor [weak self] in await self?.refreshSchedule() }
    }
  }

  deinit {
    if let foregroundObserver {
      NotificationCenter.default.removeObserver(foregroundObserver)
    }
  }

  // MARK: - Lifecycle

  /// Fetches the schedule and starts tracking window boundaries. Safe to call
  /// again (e.g. on foreground) — it simply re-resolves.
  func start() async {
    await refreshSchedule()
  }

  private func refreshSchedule() async {
    do {
      schedule = try await repository.schedule()
    } catch {
      // Keep whatever schedule we had; the boundary loop keeps working off it
      // and the next start()/foreground retries.
      if schedule == nil { return }
    }
    recomputeLive()
    armBoundaryTimer()
  }

  private func recomputeLive() {
    guard let window = schedule?.window(for: .meditation) else {
      isMeditationLive = false
      return
    }
    let now = clock.now
    isMeditationLive = now >= window.startsAt && now < window.endsAt
  }

  /// One sleeping task per upcoming boundary; re-armed after every firing,
  /// clock sync, or dev time jump. Crossing the final boundary re-fetches the
  /// next occurrence.
  private func armBoundaryTimer() {
    boundaryTask?.cancel()
    guard let schedule else { return }
    let now = clock.now
    guard let boundary = schedule.nextBoundary(after: now) else {
      // Window over; tomorrow's schedule replaces it. The delay keeps a stale
      // schedule whose fetch keeps failing from becoming a zero-backoff
      // request loop (refresh → no boundary → refresh …).
      boundaryTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(60))
        guard !Task.isCancelled else { return }
        await self?.refreshSchedule()
      }
      return
    }
    let delay = boundary.timeIntervalSince(now)
    boundaryTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(max(0.05, delay)))
      guard !Task.isCancelled else { return }
      guard let self else { return }
      self.recomputeLive()
      self.armBoundaryTimer()
    }
  }

  // MARK: - Session scope (presence + live polling)

  /// Starts heartbeats and live polling. Called when the session screen is
  /// presented.
  func enterSession() {
    guard heartbeatTask == nil else { return }
    let country = Locale.current.region?.identifier.uppercased()

    heartbeatTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        try? await self.repository.heartbeat(presenceID: self.presenceID, countryISO: country)
        try? await Task.sleep(for: .seconds(20))
      }
    }
    pollTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        await self.pollLive()
        try? await Task.sleep(for: .seconds(5))
      }
    }
  }

  func leaveSession() {
    heartbeatTask?.cancel()
    heartbeatTask = nil
    pollTask?.cancel()
    pollTask = nil
    seenJoins = []
    pendingJoins = []
    Task { [repository, presenceID] in
      await repository.leave(presenceID: presenceID)
    }
  }

  private func pollLive() async {
    guard let snapshot = try? await repository.live() else { return }
    participantCount = snapshot.participantCount
    participantsByCountry = snapshot.byCountry

    for join in snapshot.recentJoins {
      let key = "\(join.iso)-\(join.at.timeIntervalSince1970)"
      if !seenJoins.contains(key) {
        seenJoins.insert(key)
        pendingJoins.append(join.iso)
      }
    }
    // Clock sync can move a boundary; keep the timer honest.
    recomputeLive()
    armBoundaryTimer()
  }

  /// Joins that arrived since the last consume — the session screen turns
  /// these into globe ripples. Draining keeps one ripple per join.
  func consumeNewJoins() -> [String] {
    let joins = pendingJoins
    pendingJoins = []
    return joins
  }

  // MARK: - Reflection (messages, intention & mood)

  func post(message text: String) async throws -> PeaceMessage {
    let country = Locale.current.region?.identifier.uppercased()
    return try await repository.postMessage(text, countryISO: country)
  }

  func submit(intention: String?, mood: String?) async throws {
    try await repository.submitReflection(intention: intention, mood: mood)
  }

  // MARK: - Schedule phrasing

  /// "Tonight · 20:40 Thailand Time" / "Tomorrow · 20:40 Thailand Time",
  /// phrased against the pause's home timezone rather than the device's.
  func scheduleLine(for target: Date) -> String {
    var calendar = Calendar(identifier: .gregorian)
    let timeZone = TimeZone(identifier: schedule?.timezone ?? "Asia/Bangkok") ?? .current
    calendar.timeZone = timeZone

    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    formatter.dateFormat = "HH:mm"
    let time = formatter.string(from: target)

    let day = calendar.isDate(clock.now, inSameDayAs: target) ? "Tonight" : "Tomorrow"
    return "\(day) · \(time) Thailand Time"
  }

  // MARK: - Dev time travel

  /// Pins the clock 2 s into tonight's meditation window, so the live session
  /// can be entered immediately. Dev builds only.
  func debugEnterLive() {
    guard AppConfig.current.isDev,
          let window = schedule?.window(for: .meditation) else { return }
    clock.debugOverride = window.startsAt.addingTimeInterval(2)
    recomputeLive()
    armBoundaryTimer()
  }

  /// Pins the clock just past the meditation window's end, ending a running
  /// live session (the session screen crossfades into reflection). Dev builds
  /// only.
  func debugEndLive() {
    guard AppConfig.current.isDev,
          let window = schedule?.window(for: .meditation) else { return }
    clock.debugOverride = window.endsAt.addingTimeInterval(1)
    recomputeLive()
    armBoundaryTimer()
  }

  /// Clears the pinned clock, returning to real time. Dev builds only.
  func debugReturnToRealTime() {
    guard AppConfig.current.isDev else { return }
    clock.debugOverride = nil
    recomputeLive()
    armBoundaryTimer()
  }
}

// MARK: - Previews

#if DEBUG
extension GlobalPauseSession {
  /// A session backed by fixtures, optionally pinned live — for previews.
  static func preview(live: Bool = false) -> GlobalPauseSession {
    let session = GlobalPauseSession(
      clock: SyncedClock(),
      repository: FixturePauseEventRepository()
    )
    session.schedule = FixturePauseEventRepository.tonightSchedule()
    session.isMeditationLive = live
    session.participantCount = 4218
    session.participantsByCountry = ["TH": 1200, "JP": 640, "US": 580, "FR": 320]
    return session
  }
}
#endif

extension EnvironmentValues {
  /// The live pause engine. The coordinator injects the app-lifetime
  /// instance; the preview default keeps leaf screens hermetic.
  @Entry var globalPauseSession: GlobalPauseSession = {
    let session = GlobalPauseSession(
      clock: SyncedClock(),
      repository: FixturePauseEventRepository()
    )
    return session
  }()
}
