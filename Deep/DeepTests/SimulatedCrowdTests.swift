import Foundation
import Testing
@testable import Deep

/// The world the participant-scale demo invents. What these guard: the demo is
/// shown to a client beside a headline number, so the parts must add up to that
/// number exactly, the payload must be shaped like a real one (never wider than
/// the server's own caps), and the same tier must look the same every time —
/// otherwise two showings of "300,000" are not comparable.
struct SimulatedCrowdTests {

  private let tiers = [1, 999, 1_000, 10_000, 300_000]

  // MARK: - The number on screen

  /// A demo showing 299,998 under a 300,000 headline reads as broken.
  @Test func continentPartsSumToTheHeadlineExactly() {
    for count in tiers {
      let crowd = SimulatedCrowd(participantCount: count)
      let total = crowd.byContinent.values.reduce(0, +)
      #expect(total == count, "continents summed to \(total), expected \(count)")
    }
  }

  /// The continent row is wider than the country list on purpose: the server
  /// counts people whose device never named a country.
  @Test func continentsAreWiderThanCountries() {
    for count in tiers {
      let crowd = SimulatedCrowd(participantCount: count)
      let continents = crowd.byContinent.values.reduce(0, +)
      let countries = crowd.byCountry.values.reduce(0, +)
      #expect(continents >= countries)
    }
  }

  @Test func emptyWorldSaysNothing() {
    let crowd = SimulatedCrowd(participantCount: 0)
    #expect(crowd.byContinent.isEmpty)
    #expect(crowd.byCountry.isEmpty)
    #expect(crowd.locations.isEmpty)
    #expect(crowd.joins(serverNow: Date(), since: Date().addingTimeInterval(-5)).isEmpty)
  }

  // MARK: - Payload shape

  /// The server bins to 1° cells and keeps the top 96 (`MAX_POINTS`). A demo
  /// payload wider than that would light a globe no real night could.
  @Test func pointsNeverExceedTheServersCap() {
    for count in tiers {
      let points = SimulatedCrowd(participantCount: count).locations
      #expect(points.count <= 96, "\(count) produced \(points.count) points")
    }
  }

  @Test func pointsArriveLargestFirst() {
    let points = SimulatedCrowd(participantCount: 300_000).locations
    let counts = points.map(\.count)
    #expect(counts == counts.sorted(by: >))
  }

  @Test func everyPointCarriesSomeone() {
    for count in tiers {
      let points = SimulatedCrowd(participantCount: count).locations
      #expect(points.allSatisfy { $0.count > 0 })
    }
  }

  /// Coordinates leave the server rounded to 0.1° for privacy; the demo's must
  /// not be finer than any real payload's.
  @Test func coordinatesAreRoundedLikeTheServers() {
    for cell in SimulatedCrowd.cells {
      #expect(abs((cell.lat * 10).rounded() - cell.lat * 10) < 0.001)
      #expect(abs((cell.lon * 10).rounded() - cell.lon * 10) < 0.001)
      #expect(cell.lat >= -90 && cell.lat <= 90)
      #expect(cell.lon >= -180 && cell.lon <= 180)
    }
  }

  // MARK: - Arrivals

  /// The regression this exists for: `pollLive()` dedupes joins on
  /// `"\(iso)-\(at.timeIntervalSince1970)"`. Fifty arrivals all stamped `now`
  /// would collapse to one spark per country, and the busiest tier would look
  /// quieter than the emptiest.
  @Test func everyJoinInABatchSurvivesTheDedupeKey() {
    let now = Date()
    let joins = SimulatedCrowd(participantCount: 300_000)
      .joins(serverNow: now, since: now.addingTimeInterval(-5))
    #expect(joins.count == 50)
    let keys = Set(joins.map { "\($0.iso)-\($0.at.timeIntervalSince1970)" })
    #expect(keys.count == joins.count)
  }

  /// Bigger crowds arrive faster — until the server's payload cap, which is the
  /// ceiling the demo exists to show.
  @Test func arrivalRateClimbsWithTheCrowdThenSaturates() {
    let now = Date()
    let since = now.addingTimeInterval(-5)
    func batch(_ count: Int) -> Int {
      SimulatedCrowd(participantCount: count).joins(serverNow: now, since: since).count
    }
    #expect(batch(1_000) == 1)
    #expect(batch(10_000) == 10)
    // 300,000 wants 300 arrivals in five seconds and gets the server's 50.
    #expect(batch(300_000) == 50)
    #expect(batch(50_000) == 50)
  }

  /// Some joins carry no coordinates, so the country-centroid fallback in
  /// `pollLive()` runs too.
  @Test func someJoinsArriveWithoutCoordinates() {
    let now = Date()
    let joins = SimulatedCrowd(participantCount: 300_000)
      .joins(serverNow: now, since: now.addingTimeInterval(-5))
    #expect(joins.contains { $0.lat == nil })
    #expect(joins.contains { $0.lat != nil })
  }

  /// Every join names a country the globe's own table knows, or its spark is
  /// silently dropped when the coordinates are absent.
  @MainActor
  @Test func everyJoinCountryIsOneTheGlobeCanPlace() {
    for iso in Set(SimulatedCrowd.cities.map(\.iso)) {
      #expect(CountryLookup.shared.country(forISO: iso) != nil, "\(iso) is unknown to the globe")
    }
  }

  // MARK: - Coverage

  /// The regression this exists for: the table once spread each city over three
  /// cells, overran the server's 96-point cap, and the cut deleted whole
  /// low-weight countries — Ghana, Morocco and Kenya all disappeared at 300,000,
  /// so Africa emptied as the world filled. Staying under the cap is what keeps
  /// the map a viewer reads honest.
  @Test func noPlaceIsEverSilentlyTrimmed() {
    #expect(SimulatedCrowd.cells.count <= SimulatedCrowd.maxPoints)
    for count in [1_000, 10_000, 300_000] {
      let lit = SimulatedCrowd(participantCount: count).locations
      #expect(
        lit.count == SimulatedCrowd.cells.count,
        "\(count) lit \(lit.count) of \(SimulatedCrowd.cells.count) places"
      )
    }
  }

  /// A demo is read as a claim about coverage. No inhabited continent may be
  /// reduced to a token light or two.
  @Test func everyContinentIsProperlyPeopled() {
    var perContinent: [String: Int] = [:]
    for city in SimulatedCrowd.cities {
      perContinent[city.continentISO, default: 0] += 1
    }
    #expect(perContinent["AF", default: 0] >= 8, "Africa: \(perContinent["AF"] ?? 0) cities")
    for (iso, cities) in perContinent {
      #expect(cities >= 3, "\(iso) has only \(cities) cities")
    }
  }

  /// Russia reading as one dot outside Moscow was the tell that this table was a
  /// fixture rather than a world. It spans about 170° of longitude; the lights
  /// on it should say so.
  @Test func russiaSpansItsOwnWidth() {
    let russian = SimulatedCrowd.cities.filter { $0.iso == "RU" }
    #expect(russian.count >= 3)
    let spread = (russian.map(\.lon).max() ?? 0) - (russian.map(\.lon).min() ?? 0)
    #expect(spread > 80, "Russian cities span only \(spread)°")
  }

  // MARK: - Determinism

  /// Scrubbing between tiers must move the lights, not rebuild the world —
  /// otherwise `EarthGlowStore` crossfades a new globe in instead of lerping.
  @Test func theSameCountAlwaysBuildsTheSameWorld() {
    let first = SimulatedCrowd(participantCount: 10_000)
    let second = SimulatedCrowd(participantCount: 10_000)
    #expect(first.byCountry == second.byCountry)
    #expect(first.byContinent == second.byContinent)
    #expect(first.locations.map(\.lat) == second.locations.map(\.lat))
    #expect(first.locations.map(\.count) == second.locations.map(\.count))
  }

  /// Positions come from the fixed table and are never invented per count, so a
  /// tier change brightens lights already on the globe rather than relocating
  /// them.
  @Test func everyLitPlaceComesFromTheFixedTable() {
    let known = Set(SimulatedCrowd.cells.map { "\($0.lat),\($0.lon)" })
    for count in tiers {
      let lit = Set(SimulatedCrowd(participantCount: count).locations.map { "\($0.lat),\($0.lon)" })
      #expect(lit.isSubset(of: known), "\(count) lit a place not in the table")
    }
  }

  // MARK: - Apportionment

  @Test func apportionmentAlwaysCloses() {
    #expect(SimulatedCrowd.apportion(10, across: [1, 1, 1]).reduce(0, +) == 10)
    #expect(SimulatedCrowd.apportion(7, across: [3, 1]) == [5, 2])
    #expect(SimulatedCrowd.apportion(0, across: [1, 2]) == [0, 0])
    #expect(SimulatedCrowd.apportion(5, across: []).isEmpty)
    #expect(SimulatedCrowd.apportion(5, across: [0, 0]) == [0, 0])
  }

  @Test func apportionmentIsStableForTheSameInput() {
    let once = SimulatedCrowd.apportion(1_000, across: [1, 1, 1, 1, 1, 1, 7])
    let twice = SimulatedCrowd.apportion(1_000, across: [1, 1, 1, 1, 1, 1, 7])
    #expect(once == twice)
    #expect(once.reduce(0, +) == 1_000)
  }
}
