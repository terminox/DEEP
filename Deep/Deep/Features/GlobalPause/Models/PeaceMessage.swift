import Foundation

/// A message left after the meditation — the peace-messages content, consumed
/// directly by `PeaceMessagesSection` in Fuku's Lounge.
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
}
