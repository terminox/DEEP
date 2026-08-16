import SwiftUI
import Observation

/// The three faces of the Global Pause card: resting on the schedule line,
/// counting down the final lead before the meditation, or live. Computed by
/// `GlobalPauseSession` (which owns the clock and the boundaries); rendered by
/// the card chrome.
enum GlobalPauseCardState: Equatable {
  case off(scheduleLine: String)
  case countdown(target: Date, scheduleLine: String)
  case live
}

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
  /// What the card shows right now. Stored rather than computed on purpose:
  /// nothing observable changes at the countdown threshold, so a computed
  /// property would never wake the chrome's observation loop — the boundary
  /// timer recomputes this at every edge instead.
  private(set) var cardState: GlobalPauseCardState = .off(
    scheduleLine: "Breathe with the world, together"
  )
  private(set) var participantCount = 0
  private(set) var participantsByCountry: [String: Int] = [:]
  /// Located participants as server-clustered lat/lon points. Empty on older
  /// servers — the globe then glows per-country from `participantsByCountry`.
  private(set) var participantLocations: [PauseLiveSnapshot.GeoPoint] = []
  /// Participants the server couldn't geolocate; the globe renders these via
  /// the client-side country-centroid table.
  private(set) var unlocatedByCountry: [String: Int] = [:]
  /// Where *this* user is: the server's IP-resolved location when it has one
  /// (from the heartbeat response), else the device-locale country centroid.
  /// The session screen turns the globe here and seats the home glow.
  private(set) var myLocation: PauseJoinPoint?

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

  /// How long before the meditation the card flips to its countdown — a
  /// client presentation choice, deliberately not server config. The dev
  /// time-travel route mirrors this value (`COUNTDOWN_LEAD_MS` in
  /// deep-api/src/routes/pauseLive.ts) so its loop shows the whole arc.
  static let countdownLead: TimeInterval = 15 * 60

  private let repository: any PauseEventRepository
  @ObservationIgnored private var boundaryTask: Task<Void, Never>?
  @ObservationIgnored private var heartbeatTask: Task<Void, Never>?
  @ObservationIgnored private var pollTask: Task<Void, Never>?
  @ObservationIgnored private var foregroundObserver: NSObjectProtocol?
  /// Joins already turned into sparks, so a poll never replays old ones.
  @ObservationIgnored private var seenJoins: Set<String> = []
  @ObservationIgnored private var pendingJoins: [PauseJoinPoint] = []
  /// Your own join comes back in the server's feed like anyone else's — but
  /// the session screen already flares it the moment the globe lands on you,
  /// rather than waiting a poll for the echo. Swallow that echo once so your
  /// city doesn't spark twice.
  @ObservationIgnored private var hasSwallowedOwnJoin = false

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
      // (and retries on its own when there's no schedule at all).
    }
    recomputeState()
    armBoundaryTimer()
  }

  private func recomputeState() {
    guard let schedule, let window = schedule.window(for: .meditation) else {
      isMeditationLive = false
      setCardState(.off(scheduleLine: "Breathe with the world, together"))
      return
    }
    let now = clock.now
    isMeditationLive = now >= window.startsAt && now < window.endsAt
    let target = schedule.nextMeditationStart(after: now)
    if isMeditationLive {
      setCardState(.live)
    } else if target.timeIntervalSince(now) <= Self.countdownLead {
      setCardState(.countdown(target: target, scheduleLine: scheduleLine(for: target)))
    } else {
      setCardState(.off(scheduleLine: scheduleLine(for: target)))
    }
  }

  /// The live poll recomputes every few seconds, and `@Observable` fires on
  /// every assignment — the equality guard keeps the chrome's observation loop
  /// from re-arming when nothing actually changed.
  private func setCardState(_ new: GlobalPauseCardState) {
    if cardState != new { cardState = new }
  }

  /// The next instant the card's state can change: the next phase boundary, or
  /// the countdown start (meditation − lead), whichever comes first. Nil keeps
  /// the 60 s retry-refetch path below (no schedule, or window over — after
  /// which the fresh schedule supplies tomorrow's countdown start again).
  private func nextStateBoundary(after now: Date) -> Date? {
    guard let schedule, let phaseBoundary = schedule.nextBoundary(after: now) else { return nil }
    let countdownStart = schedule.nextMeditationStart(after: now)
      .addingTimeInterval(-Self.countdownLead)
    guard countdownStart > now else { return phaseBoundary }
    return min(phaseBoundary, countdownStart)
  }

  /// One sleeping task per upcoming boundary; re-armed after every firing and
  /// clock sync. Crossing the final boundary re-fetches the next occurrence.
  private func armBoundaryTimer() {
    boundaryTask?.cancel()
    let now = clock.now
    guard let boundary = nextStateBoundary(after: now) else {
      // No schedule yet (first fetch failed) or window over; the next fetch
      // supplies it. The delay keeps a failing fetch from becoming a
      // zero-backoff request loop (refresh → no boundary → refresh …).
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
      self.recomputeState()
      self.armBoundaryTimer()
    }
  }

  // MARK: - Session scope (presence + live polling)

  /// Starts heartbeats and live polling. Called when the session screen is
  /// presented.
  func enterSession() {
    guard heartbeatTask == nil else { return }
    let country = Locale.current.region?.identifier.uppercased()

    // Locale-centroid fallback immediately, so the globe can turn to
    // *somewhere* the moment the screen lands; the server's IP-resolved
    // location overwrites it as soon as the first heartbeat responds.
    if myLocation == nil, let country,
       let home = CountryLookup.shared.country(forISO: country) {
      myLocation = PauseJoinPoint(lat: home.latitude, lon: home.longitude)
    }

    heartbeatTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        if let resolved = try? await self.repository.heartbeat(
          presenceID: self.presenceID, countryISO: country
        ) {
          self.myLocation = resolved
        }
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
    hasSwallowedOwnJoin = false
    myLocation = nil
    Task { [repository, presenceID] in
      await repository.leave(presenceID: presenceID)
    }
  }

  private func pollLive() async {
    guard let snapshot = try? await repository.live() else { return }
    participantCount = snapshot.participantCount
    participantsByCountry = snapshot.byCountry
    participantLocations = snapshot.locations
    unlocatedByCountry = snapshot.unlocatedByCountry

    for join in snapshot.recentJoins {
      let key = "\(join.iso)-\(join.at.timeIntervalSince1970)"
      guard !seenJoins.contains(key) else { continue }
      seenJoins.insert(key)
      let point: PauseJoinPoint
      if let lat = join.lat, let lon = join.lon {
        point = PauseJoinPoint(lat: lat, lon: lon)
      } else if let country = CountryLookup.shared.country(forISO: join.iso) {
        // Server couldn't locate the IP — land the spark on the country centroid.
        point = PauseJoinPoint(lat: country.latitude, lon: country.longitude)
      } else {
        continue
      }
      // The match is exact by construction: a located join carries the very
      // coordinates the heartbeat resolved into `myLocation`, and an unlocated
      // one falls back to the same `CountryLookup` centroid the session seeded
      // itself with.
      if !hasSwallowedOwnJoin, point == myLocation {
        hasSwallowedOwnJoin = true
        continue
      }
      pendingJoins.append(point)
    }
    // Clock sync can move a boundary; keep the timer honest.
    recomputeState()
    armBoundaryTimer()
  }

  /// Joins that arrived since the last consume — the session screen turns
  /// these into globe sparks + ripples, minus your own, which it flares
  /// itself. Draining keeps one per join.
  func consumeNewJoins() -> [PauseJoinPoint] {
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
    if live { session.cardState = .live }
    session.participantCount = 4218
    session.participantsByCountry = ["TH": 1200, "JP": 640, "US": 580, "FR": 320]
    session.myLocation = PauseJoinPoint(lat: 13.8, lon: 100.5)  // Bangkok
    return session
  }

  /// A fixture session pinned to one card state — for chrome/card previews.
  static func preview(cardState: GlobalPauseCardState) -> GlobalPauseSession {
    let session = preview(live: cardState == .live)
    session.cardState = cardState
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
