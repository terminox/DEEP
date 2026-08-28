import Foundation
import SwiftUI

/// One page of the peace-message feed. `nextCursor` is an opaque server token;
/// pass it back to fetch the next page, `nil` means the feed is exhausted.
struct PeaceMessagesPage {
  let messages: [PeaceMessage]
  let nextCursor: String?
}

/// A freshly posted peace message, plus the award the first message of the
/// night earns — nil for every later message (and on older servers).
struct PostedPeaceMessage {
  let message: PeaceMessage
  let award: AwardGrant?
}

/// Backend seam for the Global Pause event: tonight's schedule, live presence,
/// and peace messages. UI depends on this protocol so screens preview against
/// the fixture with no network.
@MainActor
protocol PauseEventRepository: AnyObject {
  func schedule() async throws -> PauseSchedule
  func live() async throws -> PauseLiveSnapshot
  /// Returns the caller's own server-resolved location (privacy-rounded),
  /// nil when the server couldn't place the IP — used to turn the globe to
  /// the user and seat their home glow.
  @discardableResult
  func heartbeat(presenceID: String, countryISO: String?) async throws -> PauseJoinPoint?
  /// Best-effort; failures are irrelevant (the server sweeps stale presence).
  func leave(presenceID: String) async
  func messages(limit: Int, cursor: String?) async throws -> PeaceMessagesPage
  func postMessage(
    _ text: String,
    countryISO: String?,
    intention: String?
  ) async throws -> PostedPeaceMessage
  func submitReflection(intention: String?, mood: String?) async throws
}

// MARK: - API-backed

/// Maps the `/pause/*` event endpoints into domain models. Every response's
/// `serverNow` is pushed into the shared `SyncedClock` so the phase engine
/// keeps agreeing with the server.
@MainActor
final class APIPauseEventRepository: PauseEventRepository {
  private let client: APIClient
  private let clock: SyncedClock
  private let iso = ISO8601DateFormatter()
  private let isoFractional: ISO8601DateFormatter

  init(client: APIClient, clock: SyncedClock) {
    self.client = client
    self.clock = clock
    self.isoFractional = ISO8601DateFormatter()
    self.isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  }

  private func date(_ raw: String) -> Date {
    isoFractional.date(from: raw) ?? iso.date(from: raw) ?? Date()
  }

  func schedule() async throws -> PauseSchedule {
    let dto: PauseScheduleDTO = try await client.request("/pause/schedule")
    clock.sync(serverNow: date(dto.serverNow))
    return PauseSchedule(
      pauseDate: dto.pauseDate,
      timezone: dto.timezone,
      phases: dto.phases.compactMap { phase in
        PausePhaseWindow.Key(rawValue: phase.key).map {
          PausePhaseWindow(key: $0, startsAt: date(phase.startsAt), endsAt: date(phase.endsAt))
        }
      },
      lobbyAudioURL: dto.lobbyAudioUrl.flatMap(URL.init(string:)),
      meditationAudioURL: dto.meditationAudioUrl.flatMap(URL.init(string:)),
      meditationDuration: TimeInterval(dto.meditationDurationSeconds),
      welcomeMessages: dto.welcomeMessages,
      intentions: dto.intentions.map { Intention(key: $0.key, label: $0.label) }
    )
  }

  func live() async throws -> PauseLiveSnapshot {
    let dto: PauseLiveDTO = try await client.request("/pause/live")
    clock.sync(serverNow: date(dto.serverNow))
    return PauseLiveSnapshot(
      serverNow: date(dto.serverNow),
      participantCount: dto.participantCount,
      byCountry: Dictionary(
        dto.byCountry.map { ($0.iso, $0.count) },
        uniquingKeysWith: { first, _ in first }
      ),
      byContinent: continentTally(dto),
      locations: (dto.points ?? []).map {
        .init(lat: Float($0.lat), lon: Float($0.lon), count: $0.count)
      },
      unlocatedByCountry: Dictionary(
        (dto.unlocatedByCountry ?? []).map { ($0.iso, $0.count) },
        uniquingKeysWith: { first, _ in first }
      ),
      recentJoins: dto.recentJoins.map {
        .init(
          iso: $0.iso,
          at: date($0.at),
          lat: $0.lat.map(Float.init),
          lon: $0.lon.map(Float.init)
        )
      }
    )
  }

  /// The continent tally, with a fallback for servers that predate the field:
  /// fold `byCountry` through the globe's own country table. That table knows
  /// only the ~67 countries whose glow was hand-tuned, so the fallback
  /// undercounts — it exists to keep an older server readable, not to be
  /// authoritative.
  private func continentTally(_ dto: PauseLiveDTO) -> [String: Int] {
    if let byContinent = dto.byContinent, !byContinent.isEmpty {
      return Dictionary(
        byContinent.map { ($0.iso, $0.count) },
        uniquingKeysWith: { first, _ in first }
      )
    }
    var tally: [String: Int] = [:]
    for entry in dto.byCountry {
      guard let country = CountryLookup.shared.country(forISO: entry.iso) else { continue }
      tally[country.continentISO, default: 0] += entry.count
    }
    return tally
  }

  @discardableResult
  func heartbeat(presenceID: String, countryISO: String?) async throws -> PauseJoinPoint? {
    let dto: PauseHeartbeatResponseDTO = try await client.request(
      "/pause/presence/heartbeat",
      method: "POST",
      body: PauseHeartbeatRequestDTO(presenceId: presenceID, countryISO: countryISO)
    )
    return dto.location.map { PauseJoinPoint(lat: Float($0.lat), lon: Float($0.lon)) }
  }

  func leave(presenceID: String) async {
    _ = try? await client.request(
      "/pause/presence/\(presenceID)",
      method: "DELETE",
      as: OKResponseDTO.self
    )
  }

  func messages(limit: Int, cursor: String?) async throws -> PeaceMessagesPage {
    // The cursor is server-issued base64url — already query-safe verbatim.
    var path = "/pause/messages?limit=\(limit)"
    if let cursor { path += "&cursor=\(cursor)" }
    let dto: PauseMessagesResponseDTO = try await client.request(path)
    clock.sync(serverNow: date(dto.serverNow))
    return PeaceMessagesPage(messages: dto.messages.map(mapMessage), nextCursor: dto.nextCursor)
  }

  func postMessage(
    _ text: String,
    countryISO: String?,
    intention: String?
  ) async throws -> PostedPeaceMessage {
    let dto: PauseMessagePostResponseDTO = try await client.request(
      "/pause/messages",
      method: "POST",
      body: PeaceMessagePostRequestDTO(
        text: text,
        countryISO: countryISO,
        intention: intention
      )
    )
    clock.sync(serverNow: date(dto.serverNow))
    return PostedPeaceMessage(
      message: mapMessage(dto.message),
      award: AwardGrant(
        outcomes: [dto.award].compactMap { $0 },
        wallet: dto.wallet,
        plant: dto.plant
      )
    )
  }

  func submitReflection(intention: String?, mood: String?) async throws {
    try await client.request(
      "/pause/reflection",
      method: "POST",
      body: PauseReflectionRequestDTO(intention: intention, mood: mood),
      as: OKResponseDTO.self
    )
  }

  private func mapMessage(_ dto: PeaceMessageDTO) -> PeaceMessage {
    PeaceMessage(
      id: dto.id,
      displayName: dto.displayName,
      countryISO: dto.countryISO,
      text: dto.text,
      intention: dto.intention,
      createdAt: date(dto.createdAt)
    )
  }
}

// MARK: - Fixture

/// Deterministic sample data for previews and the environment default.
/// Tonight's schedule is computed from the real Bangkok wall clock, so
/// previews behave like the app would right now.
@MainActor
final class FixturePauseEventRepository: PauseEventRepository {
  private var posted: [PeaceMessage] = []

  static let sampleMessages: [PeaceMessage] = [
    PeaceMessage(
      id: "fixture-1",
      displayName: "Nan",
      countryISO: "TH",
      text: "Peace for every quiet heart tonight.",
      intention: "peace",
      createdAt: Date().addingTimeInterval(-3600)
    ),
    PeaceMessage(
      id: "fixture-2",
      displayName: "Haruki",
      countryISO: "JP",
      text: "Breathing with you all from Kyoto.",
      intention: "peace",
      createdAt: Date().addingTimeInterval(-4200)
    ),
    PeaceMessage(
      id: "fixture-3",
      displayName: "Camille",
      countryISO: "FR",
      text: "Ce soir, le monde respire ensemble.",
      intention: "peace",
      createdAt: Date().addingTimeInterval(-5000)
    ),
    PeaceMessage(
      id: "fixture-4",
      displayName: "Luana",
      countryISO: "BR",
      text: "Sending warmth from São Paulo.",
      intention: "someone-i-love",
      createdAt: Date().addingTimeInterval(-5600)
    ),
    PeaceMessage(
      id: "fixture-5",
      displayName: "Amara",
      countryISO: "KE",
      text: "May stillness find whoever needs it.",
      intention: "healing",
      createdAt: Date().addingTimeInterval(-6300)
    ),
    PeaceMessage(
      id: "fixture-6",
      displayName: "Noah",
      countryISO: "US",
      text: "Grateful for this minute of quiet.",
      intention: "gratitude",
      createdAt: Date().addingTimeInterval(-7100)
    ),
    PeaceMessage(
      id: "fixture-7",
      displayName: "Mira",
      countryISO: "IN",
      text: "Shanti. Shanti. Shanti.",
      intention: "peace",
      createdAt: Date().addingTimeInterval(-8000)
    ),
    PeaceMessage(
      id: "fixture-8",
      displayName: "Elin",
      countryISO: "SE",
      text: "The lake is still here too. Goodnight.",
      intention: nil,
      createdAt: Date().addingTimeInterval(-9200)
    ),
    PeaceMessage(
      id: "fixture-9",
      displayName: "Tomás",
      countryISO: "AR",
      text: "Un abrazo enorme desde Buenos Aires.",
      intention: "someone-i-love",
      createdAt: Date().addingTimeInterval(-10500)
    ),
    PeaceMessage(
      id: "fixture-10",
      displayName: "Yuki",
      countryISO: "JP",
      text: "May tomorrow be gentler than today.",
      intention: nil,
      createdAt: Date().addingTimeInterval(-11800)
    ),
  ]

  static func tonightSchedule(now: Date = Date()) -> PauseSchedule {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Bangkok") ?? .current

    func tonight(_ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
      calendar.date(
        bySettingHour: hour, minute: minute, second: second, of: now
      ) ?? now
    }

    let lobby = tonight(20, 30)
    let welcome = tonight(20, 39, 50)
    let meditation = tonight(20, 40)
    let feedback = tonight(20, 50)
    let end = tonight(21, 0)

    return PauseSchedule(
      pauseDate: now.formatted(.iso8601.year().month().day()),
      timezone: "Asia/Bangkok",
      phases: [
        PausePhaseWindow(key: .lobby, startsAt: lobby, endsAt: welcome),
        PausePhaseWindow(key: .welcome, startsAt: welcome, endsAt: meditation),
        PausePhaseWindow(key: .meditation, startsAt: meditation, endsAt: feedback),
        PausePhaseWindow(key: .feedback, startsAt: feedback, endsAt: end),
      ],
      lobbyAudioURL: nil,
      meditationAudioURL: nil,
      meditationDuration: 600,
      welcomeMessages: [
        "Welcome. Tonight the world pauses together.",
        "Wherever you are, you are not alone.",
        "Settle in. We begin in a moment.",
      ],
      intentions: Intention.samples
    )
  }

  func schedule() async throws -> PauseSchedule {
    Self.tonightSchedule()
  }

  func live() async throws -> PauseLiveSnapshot {
    PauseLiveSnapshot(
      serverNow: Date(),
      participantCount: 4200 + posted.count,
      byCountry: ["TH": 1200, "JP": 640, "US": 580, "FR": 320, "BR": 410, "IN": 700],
      // Deliberately wider than the countries above — the server sees people
      // the device-reported country list never names.
      byContinent: ["AS": 2612, "EU": 1106, "NA": 604, "SA": 410, "AF": 291, "OC": 176],
      // City-level clusters so every preview exercises the point-glow path.
      locations: [
        .init(lat: 13.8, lon: 100.5, count: 3),   // Bangkok
        .init(lat: 35.0, lon: 135.8, count: 1),   // Kyoto
        .init(lat: 40.7, lon: -74.0, count: 2),   // New York
        .init(lat: 48.9, lon: 2.4, count: 1),     // Paris
        .init(lat: -23.6, lon: -46.6, count: 2),  // São Paulo
        .init(lat: -1.3, lon: 36.8, count: 1),    // Nairobi
      ],
      unlocatedByCountry: ["FR": 2],
      recentJoins: [.init(iso: "TH", at: Date(), lat: 13.8, lon: 100.5)]
    )
  }

  @discardableResult
  func heartbeat(presenceID: String, countryISO: String?) async throws -> PauseJoinPoint? {
    // Bangkok — previews get a home to turn to.
    PauseJoinPoint(lat: 13.8, lon: 100.5)
  }
  func leave(presenceID: String) async {}

  func messages(limit: Int, cursor: String?) async throws -> PeaceMessagesPage {
    // Fixture cursor: the plain offset into the sample feed.
    let all = posted + Self.sampleMessages
    let offset = cursor.flatMap(Int.init) ?? 0
    let page = Array(all.dropFirst(offset).prefix(limit))
    let nextOffset = offset + page.count
    return PeaceMessagesPage(
      messages: page,
      nextCursor: nextOffset < all.count ? String(nextOffset) : nil
    )
  }

  func postMessage(
    _ text: String,
    countryISO: String?,
    intention: String?
  ) async throws -> PostedPeaceMessage {
    let message = PeaceMessage(
      id: UUID().uuidString,
      displayName: "You",
      countryISO: countryISO,
      text: text,
      intention: intention,
      createdAt: Date()
    )
    let isFirstOfTheNight = posted.isEmpty
    posted.insert(message, at: 0)
    return PostedPeaceMessage(
      message: message,
      award: isFirstOfTheNight ? AwardGrant(hearts: 1, sunlight: 1, plantId: Plant.oakFixture.id) : nil
    )
  }

  func submitReflection(intention: String?, mood: String?) async throws {}
}

extension EnvironmentValues {
  /// The Global Pause event backend. The coordinator injects the API-backed
  /// instance; the fixture default keeps previews hermetic.
  @Entry var pauseEventRepository: any PauseEventRepository = FixturePauseEventRepository()
}
