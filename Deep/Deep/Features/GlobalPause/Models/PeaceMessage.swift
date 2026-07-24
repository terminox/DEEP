import Foundation

/// A message left in the feedback phase — the "voices of peace" content.
struct PeaceMessage: Identifiable, Hashable {
  let id: String
  let displayName: String
  let countryISO: String?
  let text: String
  let createdAt: Date

  /// Country display name from the ISO code, in the user's locale.
  var countryName: String {
    guard let countryISO else { return "" }
    return Locale.current.localizedString(forRegionCode: countryISO) ?? countryISO
  }

  /// Bridges into the shelved `VoicesOfPeaceSection` design. The tint is
  /// hashed from the id so a message keeps its colour across refreshes.
  var asVoiceOfPeace: VoiceOfPeace {
    let tints: [VoiceOfPeace.AvatarTint] = [.lavender, .blush, .sky, .peach]
    let index = abs(id.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }) % tints.count
    return VoiceOfPeace(
      name: displayName,
      country: countryName,
      quote: text,
      avatarTint: tints[index]
    )
  }
}
