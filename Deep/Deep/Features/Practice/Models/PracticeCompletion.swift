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
