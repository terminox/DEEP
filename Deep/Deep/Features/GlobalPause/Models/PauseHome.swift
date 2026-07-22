import Foundation

/// One server-composed shelf on the Global Pause home ("Popular now",
/// "Today's sessions", "Made for you"). `id` is the backend's stable section
/// key; items are full Deep Sound collections, so a card can push the real
/// collection detail or start playback with no follow-up fetch.
struct PauseHomeSection: Identifiable, Hashable {
  let id: String
  let title: String
  let collections: [SoundCollection]
}

/// A content category surfaced in the home's "Explore" grid, with its
/// collections so a tap can push the list directly.
struct PauseCategory: Identifiable, Hashable {
  let id: String
  let slug: String
  let title: String
  let collections: [SoundCollection]

  /// Explore-tile artwork borrows the category's lead collection.
  var artwork: SoundCollection? { collections.first }
}

/// Everything the Global Pause home renders below its fixed cards.
struct PauseHome: Hashable {
  let sections: [PauseHomeSection]
  let categories: [PauseCategory]
}
