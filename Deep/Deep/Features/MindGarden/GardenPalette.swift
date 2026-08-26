import SwiftUI

/// Foliage and light for the Mind Garden. The core Deep palette (`DeepColor`)
/// is intentionally floral pastel and carries neither green nor gold, so the
/// garden introduces a small, restrained set of its own — muted sages for the
/// plant, one honey for the sunlight that feeds it — that harmonise with the
/// surrounding lavender / blush atmosphere rather than fighting it.
enum GardenColor {
  static let meadow  = Color(red: 0.812, green: 0.882, blue: 0.776) // #CFE1C6
  static let sage    = Color(red: 0.647, green: 0.776, blue: 0.620) // #A5C69E
  static let fern    = Color(red: 0.451, green: 0.616, blue: 0.471) // #739D78

  /// Sunlight — the garden's currency, dimmed to the same tonal weight as
  /// `fern` so the figure it marks reads with equal strength on frost.
  static let sunbeam = Color(red: 0.710, green: 0.584, blue: 0.290) // #B5954A
}
