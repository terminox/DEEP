import Foundation

struct CountryPause: Identifiable, Hashable {
  let id = UUID()
  let countryName: String
  let flagEmoji: String
  let localTime: String
  let participantCount: Int
  let imageURL: URL?

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
