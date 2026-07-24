import Foundation
import SwiftUI

/// Backend seam for the Global Pause event: tonight's schedule, live presence,
/// and peace messages. UI depends on this protocol so screens preview against
/// the fixture with no network.
@MainActor
protocol PauseEventRepository: AnyObject {
  func schedule() async throws -> PauseSchedule
  func live() async throws -> PauseLiveSnapshot
  func heartbeat(presenceID: String, countryISO: String?) async throws
  /// Best-effort; failures are irrelevant (the server sweeps stale presence).
  func leave(presenceID: String) async
  func recentMessages(limit: Int) async throws -> [PeaceMessage]
  func postMessage(_ text: String, countryISO: String?) async throws -> PeaceMessage
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
      phase: PausePhaseWindow.Key(rawValue: dto.phase),
      participantCount: dto.participantCount,
      byCountry: Dictionary(
        dto.byCountry.map { ($0.iso, $0.count) },
        uniquingKeysWith: { first, _ in first }
      ),
      recentJoins: dto.recentJoins.map { .init(iso: $0.iso, at: date($0.at)) },
      messages: dto.messages.map(mapMessage)
    )
  }

  func heartbeat(presenceID: String, countryISO: String?) async throws {
    try await client.request(
      "/pause/presence/heartbeat",
      method: "POST",
      body: PauseHeartbeatRequestDTO(presenceId: presenceID, countryISO: countryISO),
      as: OKResponseDTO.self
    )
  }

  func leave(presenceID: String) async {
    _ = try? await client.request(
      "/pause/presence/\(presenceID)",
      method: "DELETE",
      as: OKResponseDTO.self
    )
  }

  func recentMessages(limit: Int) async throws -> [PeaceMessage] {
    let dto: PauseMessagesResponseDTO = try await client.request("/pause/messages?limit=\(limit)")
    clock.sync(serverNow: date(dto.serverNow))
    return dto.messages.map(mapMessage)
  }

  func postMessage(_ text: String, countryISO: String?) async throws -> PeaceMessage {
    let dto: PauseMessagePostResponseDTO = try await client.request(
      "/pause/messages",
      method: "POST",
      body: PeaceMessagePostRequestDTO(text: text, countryISO: countryISO)
    )
    clock.sync(serverNow: date(dto.serverNow))
    return mapMessage(dto.message)
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
      createdAt: Date().addingTimeInterval(-3600)
    ),
    PeaceMessage(
      id: "fixture-2",
      displayName: "Haruki",
      countryISO: "JP",
      text: "Breathing with you all from Kyoto.",
      createdAt: Date().addingTimeInterval(-4200)
    ),
    PeaceMessage(
      id: "fixture-3",
      displayName: "Camille",
      countryISO: "FR",
      text: "Ce soir, le monde respire ensemble.",
      createdAt: Date().addingTimeInterval(-5000)
    ),
    PeaceMessage(
      id: "fixture-4",
      displayName: "Luana",
      countryISO: "BR",
      text: "Sending warmth from São Paulo.",
      createdAt: Date().addingTimeInterval(-5600)
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
      phase: Self.tonightSchedule().phase(at: Date()),
      participantCount: 4200 + posted.count,
      byCountry: ["TH": 1200, "JP": 640, "US": 580, "FR": 320, "BR": 410, "IN": 700],
      recentJoins: [.init(iso: "TH", at: Date())],
      messages: posted + Self.sampleMessages
    )
  }

  func heartbeat(presenceID: String, countryISO: String?) async throws {}
  func leave(presenceID: String) async {}

  func recentMessages(limit: Int) async throws -> [PeaceMessage] {
    Array((posted + Self.sampleMessages).prefix(limit))
  }

  func postMessage(_ text: String, countryISO: String?) async throws -> PeaceMessage {
    let message = PeaceMessage(
      id: UUID().uuidString,
      displayName: "You",
      countryISO: countryISO,
      text: text,
      createdAt: Date()
    )
    posted.insert(message, at: 0)
    return message
  }

  func submitReflection(intention: String?, mood: String?) async throws {}
}

extension EnvironmentValues {
  /// The Global Pause event backend. The coordinator injects the API-backed
  /// instance; the fixture default keeps previews hermetic.
  @Entry var pauseEventRepository: any PauseEventRepository = FixturePauseEventRepository()
}
