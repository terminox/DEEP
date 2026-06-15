import Foundation

/// A cause the app supports. Hearts the user sends here are pooled across the
/// community; the app owner then donates real money to the partner organisation
/// in proportion to the cause's `allocation`, and reports outcomes back via
/// `FieldReport`s. Until real imagery exists, each cause renders as a gradient
/// `palette` carrying its `symbol` motif (see `SoundArtwork`).
struct CompassionCategory: Identifiable, Hashable {
  let id: String
  let name: String
  let tagline: String
  /// SF Symbol motif drawn over the gradient artwork (e.g. "bird.fill").
  let symbol: String
  let palette: ArtworkPalette
  /// Share of the owner's giving this cause receives, 0...1.
  let allocation: Double
  let peopleReached: Int
  let partner: CompassionPartner
  /// The cause's initiatives. Mutable so a project's pooled hearts can climb.
  var projects: [CompassionProject]
  /// Community hearts pooled into this cause. Mutated as members send hearts.
  var heartsShared: Int
}

/// The real-world organisation a cause's donations flow to.
struct CompassionPartner: Hashable {
  let name: String
  let blurb: String
  /// Where the partner operates, e.g. "Thailand" or "Global".
  let scope: String
  let since: Int
  let website: String
  /// SF Symbol standing in for the partner's mark.
  let symbol: String
}

/// A concrete initiative within a cause — the thing hearts visibly move.
struct CompassionProject: Identifiable, Hashable {
  let id: String
  let title: String
  let blurb: String
  let palette: ArtworkPalette
  let symbol: String
  let peopleReached: Int
  /// Progress toward this project's current goal, 0...1.
  let progress: Double
  var heartsShared: Int
}

/// One headline figure shown in a stat cluster.
struct ImpactStat: Identifiable, Hashable {
  var id: String { label }
  let label: String
  let value: String
  let symbol: String
}

/// A real-world outcome reported back to the app — the "from the field" feed
/// that closes the loop between hearts given and lives touched.
struct FieldReport: Identifiable, Hashable {
  let id: String
  let categoryName: String
  let title: String
  let blurb: String
  let location: String
  let date: Date
  let symbol: String
  let palette: ArtworkPalette
}
