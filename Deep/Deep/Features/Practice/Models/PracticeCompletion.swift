import Foundation

/// One finished guided session, as the journal remembers it — what was
/// practised, for how long, and when. `isSynced` tracks whether the completion
/// has reached the backend yet; unsynced entries wait quietly for the next
/// push.
struct PracticeCompletion: Identifiable, Codable, Equatable {
  let id: UUID
  /// The session's title at the time of practice, e.g. "Balancing breath".
  let title: String
  let durationSeconds: Int
  let completedAt: Date
  var isSynced: Bool
}

/// A practice that keeps the day in the member's rhythm without being a DEEP
/// Session — a sound listened to its end, or a Global Pause the server counted.
/// Only the day matters: these never add minutes or session awards, they just
/// mark that the member returned. The server keeps its own record of both
/// (`activityDays` on the practice log); these local markers carry the day
/// until that record has been pulled.
struct PracticeActivity: Codable, Equatable {
  enum Kind: String, Codable {
    case track
    case pause
  }

  let kind: Kind
  let at: Date
}
