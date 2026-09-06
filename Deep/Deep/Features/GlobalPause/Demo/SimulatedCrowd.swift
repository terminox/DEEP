#if DEBUG
import Foundation

/// A whole world derived from one number.
///
/// The same count always produces the same countries, the same cells and the
/// same continent split — so a tier looks identical every time it is shown, and
/// scrubbing between two tiers *moves* the lights rather than reshuffling the
/// world. Cell positions are fixed once, at type init; only the counts sitting
/// on them change, which is what lets `EarthGlowStore` lerp its glow instead of
/// crossfading a whole new world in.
///
/// This is a viewer, not a fix. It feeds the shipping renderer real-shaped
/// payloads and lets the caps speak for themselves: the globe saturates at
/// `pointSoftCap` people per cell and 64 sources, so 10,000 and 300,000 will
/// look the same. That is the finding, not a bug in this file.
struct SimulatedCrowd {

  // MARK: - World

  /// One population centre, and its share of the room.
  ///
  /// The table is deliberately wider than the server's dev stress-test list in
  /// `deep-api/src/lib/fakeCities.ts`, which carries a single Russian city and
  /// six African ones — enough to fill an ocean-free globe, not enough to look
  /// like the world. A demo shown to someone is read as a claim about coverage,
  /// so Russia spans Moscow to Vladivostok here and Africa reaches west, north,
  /// east and south.
  ///
  /// Every `iso` must be one `CountryLookup` knows (66 countries): a join that
  /// arrives without coordinates falls back to that table's centroid, and one
  /// filed under an unknown country is silently dropped. That constraint is why
  /// the African spread uses more cities inside eight countries rather than
  /// more countries — Kinshasa, Abidjan and Dakar have nowhere to land.
  ///
  /// `continentISO` matches `CountryLookup`'s own filing rather than geography
  /// (it files Russia under "AS"), so the continent row beneath the globe can
  /// never disagree with the globe above it.
  ///
  /// `weight` is a plausible demo shape, not a forecast.
  struct City {
    let iso: String
    let continentISO: String
    let lat: Double
    let lon: Double
    let weight: Double
  }

  /// One fixed point of light — one city. Its position is decided once and
  /// never moves; only the number of people standing on it changes.
  struct Cell {
    let iso: String
    let lat: Float
    let lon: Float
    /// Its city's share, so a country's people land on its cities in
    /// proportion rather than splitting evenly across them.
    let weight: Double
  }

  static let cities: [City] = [
    // MARK: Asia
    .init(iso: "TH", continentISO: "AS", lat: 13.7563, lon: 100.5018, weight: 8.0),   // Bangkok
    .init(iso: "JP", continentISO: "AS", lat: 35.6762, lon: 139.6503, weight: 5.0),   // Tokyo
    .init(iso: "KR", continentISO: "AS", lat: 37.5665, lon: 126.9780, weight: 2.6),   // Seoul
    .init(iso: "CN", continentISO: "AS", lat: 31.2304, lon: 121.4737, weight: 3.4),   // Shanghai
    .init(iso: "CN", continentISO: "AS", lat: 39.9042, lon: 116.4074, weight: 2.8),   // Beijing
    .init(iso: "TW", continentISO: "AS", lat: 25.0330, lon: 121.5654, weight: 1.0),   // Taipei
    .init(iso: "HK", continentISO: "AS", lat: 22.3193, lon: 114.1694, weight: 1.0),   // Hong Kong
    .init(iso: "SG", continentISO: "AS", lat: 1.3521, lon: 103.8198, weight: 1.8),    // Singapore
    .init(iso: "MY", continentISO: "AS", lat: 3.1390, lon: 101.6869, weight: 1.4),    // Kuala Lumpur
    .init(iso: "ID", continentISO: "AS", lat: -6.2088, lon: 106.8456, weight: 4.2),   // Jakarta
    .init(iso: "PH", continentISO: "AS", lat: 14.5995, lon: 120.9842, weight: 2.6),   // Manila
    .init(iso: "VN", continentISO: "AS", lat: 10.8231, lon: 106.6297, weight: 2.6),   // Ho Chi Minh City
    .init(iso: "IN", continentISO: "AS", lat: 19.0760, lon: 72.8777, weight: 4.0),    // Mumbai
    .init(iso: "IN", continentISO: "AS", lat: 28.7041, lon: 77.1025, weight: 4.0),    // Delhi
    .init(iso: "BD", continentISO: "AS", lat: 23.8103, lon: 90.4125, weight: 1.2),    // Dhaka
    .init(iso: "PK", continentISO: "AS", lat: 24.8607, lon: 67.0011, weight: 1.4),    // Karachi
    .init(iso: "AE", continentISO: "AS", lat: 25.2048, lon: 55.2708, weight: 1.3),    // Dubai
    .init(iso: "SA", continentISO: "AS", lat: 24.7136, lon: 46.6753, weight: 1.0),    // Riyadh
    .init(iso: "IL", continentISO: "AS", lat: 32.0853, lon: 34.7818, weight: 0.9),    // Tel Aviv
    .init(iso: "TR", continentISO: "AS", lat: 41.0082, lon: 28.9784, weight: 1.8),    // Istanbul
    // Four Russian cities, not one: the world's widest country reading as a
    // single dot outside Moscow was the tell that this table was a fixture.
    .init(iso: "RU", continentISO: "AS", lat: 55.7558, lon: 37.6173, weight: 2.0),    // Moscow
    .init(iso: "RU", continentISO: "AS", lat: 56.8389, lon: 60.6057, weight: 0.7),    // Yekaterinburg
    .init(iso: "RU", continentISO: "AS", lat: 55.0084, lon: 82.9357, weight: 0.7),    // Novosibirsk
    .init(iso: "RU", continentISO: "AS", lat: 43.1155, lon: 131.8855, weight: 0.5),   // Vladivostok

    // MARK: Europe
    .init(iso: "GB", continentISO: "EU", lat: 51.5074, lon: -0.1278, weight: 3.4),    // London
    .init(iso: "FR", continentISO: "EU", lat: 48.8566, lon: 2.3522, weight: 2.6),     // Paris
    .init(iso: "DE", continentISO: "EU", lat: 52.5200, lon: 13.4050, weight: 2.8),    // Berlin
    .init(iso: "NL", continentISO: "EU", lat: 52.3676, lon: 4.9041, weight: 1.3),     // Amsterdam
    .init(iso: "ES", continentISO: "EU", lat: 40.4168, lon: -3.7038, weight: 1.8),    // Madrid
    .init(iso: "PT", continentISO: "EU", lat: 38.7223, lon: -9.1393, weight: 0.8),    // Lisbon
    .init(iso: "IT", continentISO: "EU", lat: 41.9028, lon: 12.4964, weight: 1.8),    // Rome
    .init(iso: "PL", continentISO: "EU", lat: 52.2297, lon: 21.0122, weight: 1.3),    // Warsaw
    .init(iso: "UA", continentISO: "EU", lat: 50.4501, lon: 30.5234, weight: 1.0),    // Kyiv
    .init(iso: "SE", continentISO: "EU", lat: 59.3293, lon: 18.0686, weight: 1.0),    // Stockholm

    // MARK: Africa
    // Eleven cities across the eight African countries `CountryLookup` knows,
    // reaching every corner of the continent rather than clustering on three.
    .init(iso: "MA", continentISO: "AF", lat: 33.5731, lon: -7.5898, weight: 0.7),    // Casablanca
    .init(iso: "EG", continentISO: "AF", lat: 30.0444, lon: 31.2357, weight: 1.4),    // Cairo
    .init(iso: "NG", continentISO: "AF", lat: 6.5244, lon: 3.3792, weight: 1.8),      // Lagos
    .init(iso: "NG", continentISO: "AF", lat: 9.0765, lon: 7.3986, weight: 0.8),      // Abuja
    .init(iso: "GH", continentISO: "AF", lat: 5.6037, lon: -0.1870, weight: 0.7),     // Accra
    .init(iso: "ET", continentISO: "AF", lat: 9.0250, lon: 38.7469, weight: 1.0),     // Addis Ababa
    .init(iso: "KE", continentISO: "AF", lat: -1.2921, lon: 36.8219, weight: 1.1),    // Nairobi
    .init(iso: "KE", continentISO: "AF", lat: -4.0435, lon: 39.6682, weight: 0.5),    // Mombasa
    .init(iso: "TZ", continentISO: "AF", lat: -6.7924, lon: 39.2083, weight: 0.8),    // Dar es Salaam
    .init(iso: "ZA", continentISO: "AF", lat: -26.2041, lon: 28.0473, weight: 1.3),   // Johannesburg
    .init(iso: "ZA", continentISO: "AF", lat: -33.9249, lon: 18.4241, weight: 0.8),   // Cape Town

    // MARK: Americas
    .init(iso: "US", continentISO: "NA", lat: 40.7128, lon: -74.0060, weight: 4.0),   // New York
    .init(iso: "US", continentISO: "NA", lat: 34.0522, lon: -118.2437, weight: 3.2),  // Los Angeles
    .init(iso: "US", continentISO: "NA", lat: 41.8781, lon: -87.6298, weight: 2.0),   // Chicago
    .init(iso: "CA", continentISO: "NA", lat: 43.6532, lon: -79.3832, weight: 1.7),   // Toronto
    .init(iso: "CA", continentISO: "NA", lat: 49.2827, lon: -123.1207, weight: 0.8),  // Vancouver
    .init(iso: "MX", continentISO: "NA", lat: 19.4326, lon: -99.1332, weight: 2.1),   // Mexico City
    .init(iso: "BR", continentISO: "SA", lat: -23.5505, lon: -46.6333, weight: 2.8),  // São Paulo
    .init(iso: "BR", continentISO: "SA", lat: -22.9068, lon: -43.1729, weight: 1.2),  // Rio de Janeiro
    .init(iso: "CO", continentISO: "SA", lat: 4.7110, lon: -74.0721, weight: 1.0),    // Bogotá
    .init(iso: "PE", continentISO: "SA", lat: -12.0464, lon: -77.0428, weight: 0.8),  // Lima
    .init(iso: "CL", continentISO: "SA", lat: -33.4489, lon: -70.6693, weight: 0.8),  // Santiago
    .init(iso: "AR", continentISO: "SA", lat: -34.6037, lon: -58.3816, weight: 1.3),  // Buenos Aires

    // MARK: Oceania
    .init(iso: "AU", continentISO: "OC", lat: -33.8688, lon: 151.2093, weight: 1.5),  // Sydney
    .init(iso: "AU", continentISO: "OC", lat: -37.8136, lon: 144.9631, weight: 1.0),  // Melbourne
    .init(iso: "NZ", continentISO: "OC", lat: -36.8485, lon: 174.7633, weight: 0.7),  // Auckland
  ]

  /// Every point of light: one per city, positioned exactly where that city is.
  ///
  /// One cell per city, deliberately. An earlier version spread each city over
  /// three jittered cells, which pushed the table past the server's 96-point cap
  /// and made the cut delete whole low-weight countries — Ghana, Morocco and
  /// Kenya all vanished at 300,000, so the demo showed Africa emptying as the
  /// world filled. Staying under the cap means nothing is ever silently
  /// dropped, and the map a viewer reads is the map the table describes.
  ///
  /// No jitter either. The server jitters because it draws the same forty
  /// cities repeatedly for *different* fake participants; with one cell per city
  /// jitter would only shift Cairo off Cairo, and real presence — MaxMind city
  /// coordinates rounded to 0.1° — lands on the cities themselves.
  static let cells: [Cell] = cities.map { city in
    Cell(
      iso: city.iso,
      lat: round1(city.lat),
      lon: round1(city.lon),
      weight: city.weight
    )
  }

  /// The cells belonging to each country, so a country's people spread across
  /// its own cities and nowhere else.
  static let cellsByCountry: [String: [Cell]] = Dictionary(grouping: cells, by: { $0.iso })

  // MARK: - Shape

  let participantCount: Int

  /// One person in every five thousand arrives each second. So 1,000 sends a
  /// join every five seconds, 10,000 sends ten a poll, and 300,000 overruns the
  /// server's own 50-per-payload cap several times over — which is exactly the
  /// ceiling worth showing.
  static func joinsPerSecond(forCount count: Int) -> Double {
    Double(count) / 5_000.0
  }

  /// The server never sends more joins than this in one payload
  /// (`RECENT_JOINS_CAP` in `deep-api/src/lib/pausePresence.ts`).
  static let recentJoinsCap = 50

  /// The server never sends more clustered points than this
  /// (`MAX_POINTS` in `deep-api/src/lib/geoCluster.ts`). The table stays under
  /// it on purpose — see `cells`.
  static let maxPoints = 96

  /// Roughly this share of the room is placed on the map; the rest are people
  /// the server counted but never located. Keeping the gap real matters:
  /// `PauseLiveSnapshot.byContinent` is documented as wider than `byCountry`,
  /// and production behaves that way.
  static let locatedShare = 0.92

  /// Of a country's people, the share the server knows the country of but not
  /// the coordinates. Sending these *and* `locations` is what makes
  /// `applyLiveGlobe()` exercise the point-glow and the country-blob path in one
  /// snapshot — more of the shipping renderer than the fixture reaches.
  static let unlocatedShare = 0.05

  /// Builds one poll's worth of world. `joinsSince` is the previous poll's
  /// instant; joins spread evenly across that window so no two share a
  /// timestamp — `GlobalPauseSession.pollLive()` dedupes on `iso` + `at`, and a
  /// batch all stamped `now` would collapse to one spark per country.
  func snapshot(serverNow: Date, joinsSince: Date) -> PauseLiveSnapshot {
    PauseLiveSnapshot(
      serverNow: serverNow,
      participantCount: participantCount,
      byCountry: byCountry,
      byContinent: byContinent,
      locations: locations,
      unlocatedByCountry: unlocatedByCountry,
      recentJoins: joins(serverNow: serverNow, since: joinsSince)
    )
  }

  /// The continent tally — the whole room, apportioned by weight so the parts
  /// sum to exactly `participantCount`. A demo showing 299,998 under a 300,000
  /// headline reads as broken, so the rounding is made to close.
  var byContinent: [String: Int] {
    var weights: [String: Double] = [:]
    for city in Self.cities {
      weights[city.continentISO, default: 0] += city.weight
    }
    let isos = weights.keys.sorted()
    let parts = Self.apportion(participantCount, across: isos.map { weights[$0] ?? 0 })
    return Dictionary(uniqueKeysWithValues: zip(isos, parts).filter { $0.1 > 0 })
  }

  /// The country tally — only the located share of the room, so it reads
  /// narrower than the continents above it, the way the real one does.
  var byCountry: [String: Int] {
    var weights: [String: Double] = [:]
    for city in Self.cities {
      weights[city.iso, default: 0] += city.weight
    }
    let isos = weights.keys.sorted()
    let located = Int((Double(participantCount) * Self.locatedShare).rounded())
    let parts = Self.apportion(located, across: isos.map { weights[$0] ?? 0 })
    return Dictionary(uniqueKeysWithValues: zip(isos, parts).filter { $0.1 > 0 })
  }

  /// People the server counted and filed under a country, but never placed. The
  /// globe renders these through its own country-centroid table.
  var unlocatedByCountry: [String: Int] {
    byCountry.compactMapValues { count in
      let share = Int((Double(count) * Self.unlocatedShare).rounded())
      return share > 0 ? share : nil
    }
  }

  /// The clustered points, built the way the server builds them: apportion each
  /// country's placed people across its own cities *by their weight*, drop the
  /// empty ones, sort by size and keep the top 96. `EarthGlowStore` then evicts
  /// to 64 by intensity — the production path, untouched.
  var locations: [PauseLiveSnapshot.GeoPoint] {
    let unlocated = unlocatedByCountry
    var points: [PauseLiveSnapshot.GeoPoint] = []
    for (iso, total) in byCountry {
      guard let cells = Self.cellsByCountry[iso], !cells.isEmpty else { continue }
      let placed = total - (unlocated[iso] ?? 0)
      guard placed > 0 else { continue }
      let parts = Self.apportion(placed, across: cells.map(\.weight))
      for (cell, count) in zip(cells, parts) where count > 0 {
        points.append(.init(lat: cell.lat, lon: cell.lon, count: count))
      }
    }
    // Sorted the way the server sorts, with position breaking ties so the trim
    // is stable rather than dictionary-order.
    return Array(
      points
        .sorted { ($0.count, $0.lat, $0.lon) > ($1.count, $1.lat, $1.lon) }
        .prefix(Self.maxPoints)
    )
  }

  /// The arrivals for one poll window. Cities are walked heaviest-first and
  /// cycled, so a busy world lights many places while a quiet one keeps
  /// returning to the same few — which is what the tiers actually differ by.
  ///
  /// Roughly one join in ten carries no coordinates, so the country-centroid
  /// fallback in `pollLive()` runs too.
  func joins(serverNow: Date, since: Date) -> [PauseLiveSnapshot.Join] {
    let window = max(0.25, serverNow.timeIntervalSince(since))
    let wanted = Int((Self.joinsPerSecond(forCount: participantCount) * window).rounded())
    let count = min(Self.recentJoinsCap, wanted)
    guard count > 0 else { return [] }

    let ordered = Self.cities.enumerated().sorted { left, right in
      left.element.weight == right.element.weight
        ? left.offset < right.offset
        : left.element.weight > right.element.weight
    }
    // Anchored to the window so consecutive polls keep walking the list rather
    // than replaying the same arrivals.
    let base = Int(since.timeIntervalSince1970 * 1_000) / 250

    return (0..<count).map { index in
      let city = ordered[(base &+ index) % ordered.count].element
      let cells = Self.cellsByCountry[city.iso] ?? []
      let cell = cells.isEmpty ? nil : cells[(base &+ index) % cells.count]
      // Evenly spread inside the window: every timestamp distinct, so no two
      // joins collapse into one under `pollLive()`'s dedupe key.
      let at = since.addingTimeInterval(window * (Double(index) + 0.5) / Double(count))
      let unlocated = (base &+ index) % 10 == 0
      return .init(
        iso: city.iso,
        at: at,
        lat: unlocated ? nil : cell?.lat,
        lon: unlocated ? nil : cell?.lon
      )
    }
  }

  // MARK: - Arithmetic

  /// Splits `total` across `weights` so the parts sum to exactly `total`
  /// (largest remainder). Ties break on index, so the same input always yields
  /// the same split.
  static func apportion(_ total: Int, across weights: [Double]) -> [Int] {
    guard !weights.isEmpty else { return [] }
    let sum = weights.reduce(0, +)
    guard sum > 0, total > 0 else { return Array(repeating: 0, count: weights.count) }

    let exact = weights.map { Double(total) * $0 / sum }
    var parts = exact.map { Int($0.rounded(.down)) }
    var remaining = total - parts.reduce(0, +)
    guard remaining > 0 else { return parts }

    let order = exact.indices.sorted {
      let left = exact[$0] - Double(parts[$0])
      let right = exact[$1] - Double(parts[$1])
      return left == right ? $0 < $1 : left > right
    }
    var cursor = 0
    while remaining > 0 {
      parts[order[cursor % order.count]] += 1
      remaining -= 1
      cursor += 1
    }
    return parts
  }

  /// The server rounds every coordinate to 0.1° before it leaves the building
  /// (privacy), and the globe re-quantises on top of that. Round here too, or
  /// the demo's cells would be finer than any real payload's.
  private static func round1(_ value: Double) -> Float {
    Float((value * 10).rounded() / 10)
  }
}
#endif
