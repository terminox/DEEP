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

/// The Global Pause engine: holds the resolved occurrence, tracks whether
/// its meditation is live against the synced clock (flipping
/// `isMeditationLive` at exact window boundaries), and scopes the live
/// presence/polling loops to the time the session screen is open.
///
/// Lives app-long (built in `AppDependencies`) because the feed needs the
/// schedule line even when the session has never been opened.
@MainActor
@Observable
final class GlobalPauseSession {
  let clock: SyncedClock

  /// The occurrence the server resolved — the one under way, else the next.
  /// Nil until the first fetch lands.
  private(set) var schedule: PauseSchedule?
  /// True exactly while the nightly meditation window is open — the one state
  /// the live session has. The boundary timer flips it at the window edges.
  private(set) var isMeditationLive = false
  /// True exactly while DJ Fuku's lounge set is playing. Stored and flipped by
  /// the same boundary timer as `cardState`, so the lounge and the home card
  /// that opens it light their ON AIR badge over identically the same minutes —
  /// and a screen that is merely sitting there gets the change without polling.
  private(set) var isFukuOnAir = false
  /// What the card shows right now. Stored rather than computed on purpose:
  /// nothing observable changes at the countdown threshold, so a computed
  /// property would never wake the chrome's observation loop — the boundary
  /// timer recomputes this at every edge instead.
  private(set) var cardState: GlobalPauseCardState = .off(
    scheduleLine: GlobalPauseSession.restingLine
  )

  /// What the card says when there is no next pause to name — before the first
  /// schedule lands, or on a server with no sessions configured at all.
  static let restingLine = "Breathe with the world, together"
  private(set) var participantCount = 0
  private(set) var participantsByCountry: [String: Int] = [:]
  /// Tallied by continent code — what the live session names beneath the
  /// globe. Server-resolved, so it reaches past the countries the globe's own
  /// table knows.
  private(set) var participantsByContinent: [String: Int] = [:]
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

  /// Tonight's settled attendance award, once the claim has landed — the
  /// reflection screen's quiet caption reads it. Nil until claimed (or when
  /// the server judged the night ineligible). Deliberately *not* cleared by
  /// `leaveSession()`: the reflection handback releases presence while the
  /// reflection screen — the award's one reader — is still up, and the claim
  /// may still be in flight. Cleared as the next session visit begins.
  private(set) var pauseAward: AwardGrant?

  /// Tonight's peace-message award, when the first message of the night earned
  /// one. Held for the same reason as `pauseAward`: the ending ritual totals
  /// both, and it is composed after the composer has had its say.
  private(set) var messageAward: AwardGrant?

  /// Tonight's peace message, kept from the moment it posts so the lounge can
  /// seat it at the head of a feed that was fetched before it existed. Cleared
  /// with the awards as the next visit begins.
  private(set) var postedMessage: PeaceMessage?

  /// When the next meditation begins — the countdown target for the card's
  /// caption. Nil until the schedule lands, or when it carries no meditation.
  var nextMeditationStart: Date? {
    schedule.flatMap { $0.nextMeditationStart(after: clock.now) }
  }

  /// Seconds into the meditation stream at the synced clock's now.
  var meditationElapsed: TimeInterval {
    guard let start = schedule?.window(for: .meditation)?.startsAt else { return 0 }
    return max(0, clock.now.timeIntervalSince(start))
  }

  var meditationDuration: TimeInterval { schedule?.meditationDuration ?? 0 }

  /// This occurrence's lounge set, once the schedule has landed and the intro
  /// clip has been measured. Nil when there is nothing to broadcast.
  var loungeBroadcast: LoungeBroadcast? {
    schedule?.loungeBroadcast(introDuration: introDuration)
  }

  /// Seconds into the lounge track at the synced clock's now — the offset a
  /// latecomer joins on, and what the radio re-seeks to after an interruption.
  var loungeElapsed: TimeInterval {
    guard case .music(let offset)? = loungeBroadcast?.stage(at: clock.now) else { return 0 }
    return offset
  }

  /// How long before the meditation the card flips to its countdown — a
  /// client presentation choice, deliberately not server config. The dev
  /// time-travel route mirrors this value (`COUNTDOWN_LEAD_MS` in
  /// deep-api/src/routes/pauseLive.ts) so its loop shows the whole arc.
  static let countdownLead: TimeInterval = 15 * 60

  private let repository: any PauseEventRepository
  /// The reward backend, for the attendance claim. Nil in fixtures/previews —
  /// the claim then quietly does nothing.
  @ObservationIgnored private let rewards: (any RewardsRemote)?
  /// Where settled awards (attendance claim, first peace message) are handed —
  /// `AppDependencies` points this at the shared ingest closure.
  @ObservationIgnored private let awardSink: (@MainActor (AwardGrant) -> Void)?
  /// The bundled intro clip's length, read off the file once (see
  /// `FukuClip.introDuration()`). Zero until it lands, which only makes the
  /// first moments of a very early visit treat the set as intro-less.
  @ObservationIgnored private var introDuration: TimeInterval = 0
  @ObservationIgnored private var hasMeasuredIntro = false
  @ObservationIgnored private var pauseAwardTask: Task<Void, Never>?
  @ObservationIgnored private var boundaryTask: Task<Void, Never>?
  /// The window end we have already gone back to the server for; see
  /// `armBoundaryTimer`.
  @ObservationIgnored private var refetchedWindowEnd: Date?
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

  init(
    clock: SyncedClock,
    repository: any PauseEventRepository,
    rewards: (any RewardsRemote)? = nil,
    awardSink: (@MainActor (AwardGrant) -> Void)? = nil
  ) {
    self.clock = clock
    self.repository = repository
    self.rewards = rewards
    self.awardSink = awardSink
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
    await measureIntroIfNeeded()
    await refreshSchedule()
  }

  /// Reads the bundled intro clip's length once per launch. It decides where
  /// the set hands off from Fuku's voice to the music, and therefore when the
  /// whole broadcast ends — so it is read from the file rather than typed.
  private func measureIntroIfNeeded() async {
    guard !hasMeasuredIntro else { return }
    hasMeasuredIntro = true
    introDuration = await FukuClip.introDuration()
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
      setFukuOnAir(false)
      setCardState(.off(scheduleLine: Self.restingLine))
      return
    }
    let now = clock.now
    isMeditationLive = now >= window.startsAt && now < window.endsAt
    setFukuOnAir(loungeBroadcast?.isOnAir(at: now) ?? false)
    if isMeditationLive {
      setCardState(.live)
    } else if let target = schedule.nextMeditationStart(after: now) {
      let line = scheduleLine(for: target)
      setCardState(
        target.timeIntervalSince(now) <= Self.countdownLead
          ? .countdown(target: target, scheduleLine: line)
          : .off(scheduleLine: line)
      )
    } else {
      setCardState(.off(scheduleLine: Self.restingLine))
    }
  }

  /// The live poll recomputes every few seconds, and `@Observable` fires on
  /// every assignment — the equality guard keeps the chrome's observation loop
  /// from re-arming when nothing actually changed.
  private func setCardState(_ new: GlobalPauseCardState) {
    if cardState != new { cardState = new }
  }

  /// Guarded for the same reason as `setCardState`: the live poll recomputes
  /// every few seconds, and an unchanged assignment would still wake every
  /// badge observing it.
  private func setFukuOnAir(_ new: Bool) {
    if isFukuOnAir != new { isFukuOnAir = new }
  }

  /// The next instant anything on screen can change: the next phase boundary,
  /// the countdown start (meditation − lead), or the moment Fuku's set signs
  /// off — whichever comes first. Nil keeps the 60 s retry-refetch path below
  /// (no schedule, or window over — after which the fresh schedule supplies
  /// tomorrow's countdown start again).
  private func nextStateBoundary(after now: Date) -> Date? {
    guard let schedule, let phaseBoundary = schedule.nextBoundary(after: now) else { return nil }
    var candidates = [phaseBoundary]
    if let next = schedule.nextMeditationStart(after: now) {
      let countdownStart = next.addingTimeInterval(-Self.countdownLead)
      if countdownStart > now { candidates.append(countdownStart) }
    }
    // The set ends partway through the lobby phase, so its end is not a phase
    // boundary of its own — without it the ON AIR badge would stay lit through
    // the quiet run-up to the welcome.
    if let setEnd = loungeBroadcast?.endsAt, setEnd > now { candidates.append(setEnd) }
    return candidates.min()
  }

  /// One sleeping task per upcoming boundary; re-armed after every firing and
  /// clock sync. An occurrence that is over is re-fetched rather than waited
  /// out, because only the server knows what comes next.
  private func armBoundaryTimer() {
    boundaryTask?.cancel()
    let now = clock.now

    // The occurrence in hand is spent. Only a fetch can name the next one —
    // its phases, its lobby set, its welcome lines, the pauseDate the awards
    // key on — and this has to be tested first rather than left to the
    // no-boundary case below: once the schedule carries the next occurrence's
    // meditation start, there IS still a boundary here (the countdown), so
    // that case would never fire and the phases would never be refreshed.
    //
    // Latched on the spent window's own end, which is what keeps a server that
    // keeps handing back the same finished occurrence from becoming a
    // zero-backoff request loop: a fetch landing a new occurrence moves
    // `windowEnd` and re-arms the latch for free, while one landing the same
    // occurrence — or failing, which leaves the old schedule in place on
    // purpose — falls through to the 60s sleep below. Cost of a misbehaving
    // server: exactly one extra request.
    if let windowEnd = schedule?.windowEnd, now >= windowEnd,
       refetchedWindowEnd != windowEnd {
      refetchedWindowEnd = windowEnd
      // Spawned rather than awaited: armBoundaryTimer is called *from*
      // refreshSchedule, so a direct call would recurse on the same turn.
      boundaryTask = Task { [weak self] in
        guard !Task.isCancelled else { return }
        await self?.refreshSchedule()
      }
      return
    }

    guard let boundary = nextStateBoundary(after: now) else {
      // No schedule yet (first fetch failed), or one we have already been back
      // for. The delay keeps a failing fetch from becoming a zero-backoff
      // request loop (refresh → no boundary → refresh …).
      boundaryTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(60))
        guard !Task.isCancelled else { return }
        await self?.refreshSchedule()
      }
      return
    }

    // A live boundary means the occurrence in hand is current again.
    refetchedWindowEnd = nil
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
    // A fresh visit must not greet tonight's reflection with a stale award
    // from an earlier night — forget it (and any orphaned claim) here rather
    // than on leave, which runs mid-reflection (see `pauseAward`).
    pauseAwardTask?.cancel()
    pauseAwardTask = nil
    pauseAward = nil
    messageAward = nil
    postedMessage = nil
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

  // MARK: - Awards

  /// Claims tonight's attendance award — called as reflection begins. Always
  /// claims; the server judges eligibility (attended through the meditation,
  /// once per pause night), so an ineligible claim just resolves to nothing.
  func claimPauseAward() {
    guard pauseAward == nil, pauseAwardTask == nil, let rewards else { return }
    pauseAwardTask = Task { [weak self] in
      let grant = try? await rewards.claimPauseAward()
      // A cancelled claim (a fresh visit superseded it) must not touch state —
      // its `pauseAwardTask` slot may already belong to the new visit's claim.
      guard let self, !Task.isCancelled else { return }
      self.pauseAwardTask = nil
      guard let grant else { return }
      withAnimation(.exhale) { self.pauseAward = grant }
      self.awardSink?(grant)
    }
  }

  /// Lets a claim already in flight land before the ending ritual reads the
  /// books, so the first reward screen opens on settled figures rather than
  /// zeros. Returns the moment it settles, or after `timeout` — a claim that
  /// never arrives simply reconciles the stores behind the ritual.
  func settlePauseAward(timeout: Duration = .seconds(2)) async {
    guard pauseAwardTask != nil else { return }
    let tick = Duration.milliseconds(100)
    var waited = Duration.zero
    while pauseAwardTask != nil, waited < timeout {
      try? await Task.sleep(for: tick)
      guard !Task.isCancelled else { return }
      waited += tick
    }
  }

  private func pollLive() async {
    guard let snapshot = try? await repository.live() else { return }
    participantCount = snapshot.participantCount
    participantsByCountry = snapshot.byCountry
    participantsByContinent = snapshot.byContinent
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

  /// Posts a peace message, tagged with the intention the member chose (the
  /// server stores it on the message *and* upserts tonight's reflection row,
  /// so this one call is the whole feedback phase). Returns the posted
  /// envelope; the first message of the night carries an award.
  @discardableResult
  func post(message text: String, intention: String?) async throws -> PostedPeaceMessage {
    let country = Locale.current.region?.identifier.uppercased()
    let posted = try await repository.postMessage(
      text,
      countryISO: country,
      intention: intention
    )
    postedMessage = posted.message
    // The first message of the night earns; later ones come back bare.
    if let award = posted.award {
      messageAward = award
      awardSink?(award)
    }
    return posted
  }

  func submit(intention: String?, mood: String?) async throws {
    try await repository.submitReflection(intention: intention, mood: mood)
  }

  // MARK: - Schedule phrasing

  /// "Today · 8:10 AM" — when the next pause begins, in the member's own clock.
  ///
  /// Read against the synced clock rather than the device's: dev time travel
  /// moves `serverNow` arbitrarily far from the real one, and the day word
  /// would lie all through QA otherwise.
  func scheduleLine(for target: Date) -> String {
    PauseScheduleLine.text(target: target, now: clock.now)
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
    session.schedule = FixturePauseEventRepository.nextOccurrence()
    session.isMeditationLive = live
    if live { session.cardState = .live }
    session.participantCount = 4218
    session.participantsByCountry = ["TH": 1200, "JP": 640, "US": 580, "FR": 320]
    session.participantsByContinent = ["AS": 2612, "EU": 1106, "NA": 604, "SA": 410, "AF": 291, "OC": 176]
    session.myLocation = PauseJoinPoint(lat: 13.8, lon: 100.5)  // Bangkok
    return session
  }

  /// A fixture session pinned to one card state — for chrome/card previews.
  static func preview(cardState: GlobalPauseCardState) -> GlobalPauseSession {
    let session = preview(live: cardState == .live)
    session.cardState = cardState
    return session
  }

  /// A fixture session with DJ Fuku's set on air — for the lounge and the card
  /// that opens it. The schedule carries a placeholder track URL that only the
  /// mock radio player ever sees, so nothing is fetched.
  static func previewOnAir() -> GlobalPauseSession {
    let session = preview()
    session.schedule = FixturePauseEventRepository.nextOccurrence(
      lobbyAudioURL: URL(string: "fixture://lounge-set")
    )
    session.isFukuOnAir = true
    return session
  }

  /// A session whose attendance claim has settled — the reflection screen's
  /// award caption reads it.
  static func previewAwarded() -> GlobalPauseSession {
    let session = preview()
    session.pauseAward = AwardGrant(hearts: 5, sunlight: 5, plantId: "oak")
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
