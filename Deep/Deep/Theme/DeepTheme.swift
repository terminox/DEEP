import SwiftUI

enum DeepColor {
  static let lavenderMist = Color(red: 0.722, green: 0.655, blue: 0.910) // #B8A7E8
  static let softLilac    = Color(red: 0.831, green: 0.773, blue: 0.941) // #D4C5F0
  static let blushPowder  = Color(red: 0.957, green: 0.788, blue: 0.831) // #F4C9D4
  static let skyWash      = Color(red: 0.773, green: 0.847, blue: 0.941) // #C5D8F0
  static let peachCloud   = Color(red: 0.961, green: 0.851, blue: 0.769) // #F5D9C4
  static let moonCream    = Color(red: 0.984, green: 0.969, blue: 1.000) // #FBF7FF
  static let deepPlum     = Color(red: 0.239, green: 0.212, blue: 0.329) // #3D3654
  static let driftGrey    = Color(red: 0.545, green: 0.510, blue: 0.659) // #8B82A8
}

enum DeepMotion {
  static let exhale = Animation.timingCurve(0.32, 0.0, 0.36, 1.0, duration: 0.8)
  static let bloom  = Animation.timingCurve(0.22, 0.61, 0.36, 1.0, duration: 0.7)
  static let settle = Animation.spring(response: 0.55, dampingFraction: 0.78)
}

enum DeepRadius {
  static let card: CGFloat = 24
  static let chip: CGFloat = 999
  static let tile: CGFloat = 20
}

enum DeepSpacing {
  static let edge: CGFloat = 20
  static let rhythm: CGFloat = 24
}
