import Foundation

struct CountryPause: Identifiable, Hashable {
  let id = UUID()
  let countryName: String
  let flagEmoji: String
  let localTime: String
  let participantCount: Int
  let imageURL: URL?

  /// Live mapping from a presence count. Name comes from the locale, the flag
  /// from the ISO's regional-indicator pair, and the local time is a
  /// longitude-based approximation (±30 min is plenty for an ambient card) —
  /// no per-country timezone table needed.
  @MainActor
  init?(iso: String, count: Int, now: Date) {
    guard let country = CountryLookup.shared.country(forISO: iso) else { return nil }
    let offsetHours = (Double(country.longitude) / 15).rounded()
    let local = now.addingTimeInterval(offsetHours * 3600)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
    let parts = calendar.dateComponents([.hour, .minute], from: local)

    self.countryName = Locale.current.localizedString(forRegionCode: iso) ?? country.name
    self.flagEmoji = Self.flag(forISO: iso)
    self.localTime = String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    self.participantCount = count
    self.imageURL = nil
  }

  init(
    countryName: String,
    flagEmoji: String,
    localTime: String,
    participantCount: Int,
    imageURL: URL?
  ) {
    self.countryName = countryName
    self.flagEmoji = flagEmoji
    self.localTime = localTime
    self.participantCount = participantCount
    self.imageURL = imageURL
  }

  /// "TH" → 🇹🇭 via regional-indicator scalars.
  static func flag(forISO iso: String) -> String {
    String(iso.uppercased().unicodeScalars.compactMap {
      Unicode.Scalar(127397 + $0.value).map(Character.init)
    })
  }

  static let samples: [CountryPause] = [
    CountryPause(
      countryName: "Thailand",
      flagEmoji: "🇹🇭",
      localTime: "21:00",
      participantCount: 8_123,
      imageURL: URL(string: "https://images.unsplash.com/photo-1528181304800-259b08848526?w=600&q=80")
    ),
    CountryPause(
      countryName: "Japan",
      flagEmoji: "🇯🇵",
      localTime: "23:00",
      participantCount: 6_432,
      imageURL: URL(string: "https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=600&q=80")
    ),
    CountryPause(
      countryName: "France",
      flagEmoji: "🇫🇷",
      localTime: "15:00",
      participantCount: 4_754,
      imageURL: URL(string: "https://images.unsplash.com/photo-1431274172761-fca41d930114?w=600&q=80")
    ),
    CountryPause(
      countryName: "Brazil",
      flagEmoji: "🇧🇷",
      localTime: "11:00",
      participantCount: 3_109,
      imageURL: URL(string: "https://images.unsplash.com/photo-1483729558449-99ef09a8c325?w=600&q=80")
    )
  ]
}
