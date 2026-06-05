import SwiftUI

/// Foliage tones for the Mind Garden. The core Deep palette (`DeepColor`) is
/// intentionally floral pastel and carries no green, so the garden introduces a
/// small, restrained set of muted sages that harmonise with the surrounding
/// lavender / blush atmosphere rather than fighting it.
enum GardenColor {
  static let meadow = Color(red: 0.812, green: 0.882, blue: 0.776) // #CFE1C6
  static let sage   = Color(red: 0.647, green: 0.776, blue: 0.620) // #A5C69E
  static let fern   = Color(red: 0.451, green: 0.616, blue: 0.471) // #739D78
  static let soil   = Color(red: 0.792, green: 0.722, blue: 0.647) // #CAB8A5
}
