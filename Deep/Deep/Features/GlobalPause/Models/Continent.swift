import Foundation

/// The continents, as Global Pause names them.
///
/// Declaration order *is* display order: the longitude of each continent's
/// centre, west to east, so a row of these read left to right reads the world
/// the way the globe turns. Antarctica sits last rather than at its centre —
/// it wraps every longitude, so it has no place in the sweep.
///
/// North and South America are one case on purpose. "Americas" is how this
/// screen speaks about the world, and merging them keeps five names breathing
/// across the width of a phone.
enum Continent: String, CaseIterable, Identifiable, Sendable {
  case americas
  case europe
  case africa
  case asia
  case oceania
  case antarctica

  var id: String { rawValue }

  /// The name under the count. Sentence case; a caller that wants an
  /// all-caps label uppercases it there.
  var name: String {
    switch self {
    case .americas: "Americas"
    case .europe: "Europe"
    case .africa: "Africa"
    case .asia: "Asia"
    case .oceania: "Oceania"
    case .antarctica: "Antarctica"
    }
  }

  /// The name inside a sentence, for VoiceOver — "1,842 in the Americas".
  var spokenName: String {
    self == .americas ? "the Americas" : name
  }

  /// Reads the server's continent codes (MaxMind's alphabet, which the API
  /// speaks). The Americas answer to two of them.
  init?(iso: String) {
    switch iso.uppercased() {
    case "NA", "SA": self = .americas
    case "EU": self = .europe
    case "AF": self = .africa
    case "AS": self = .asia
    case "OC": self = .oceania
    case "AN": self = .antarctica
    default: return nil
    }
  }
}

/// One continent's share of the room — a line of the world's roll.
struct ContinentPresence: Identifiable, Equatable, Sendable {
  let continent: Continent
  let count: Int

  var id: Continent { continent }
}

extension ContinentPresence {
  /// Folds a wire tally (`["AS": 1842, "NA": 500, "SA": 303, …]`) into the
  /// display order, merging the two Americas.
  ///
  /// Empty continents are dropped rather than shown as zero: a continent with
  /// nobody in it has nothing to say, and a nought beside its name reads as an
  /// absence rather than a fact. One lighting up mid-session simply arrives.
  static func row(from byContinentISO: [String: Int]) -> [ContinentPresence] {
    var totals: [Continent: Int] = [:]
    for (iso, count) in byContinentISO where count > 0 {
      guard let continent = Continent(iso: iso) else { continue }
      totals[continent, default: 0] += count
    }
    return Continent.allCases.compactMap { continent in
      totals[continent].map { ContinentPresence(continent: continent, count: $0) }
    }
  }
}
