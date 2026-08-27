import Foundation

/// A message left after the meditation — the peace-messages content, consumed
/// directly by `PeaceMessagesSection` in Fuku's Lounge.
struct PeaceMessage: Identifiable, Hashable {
  let id: String
  let displayName: String
  let countryISO: String?
  let text: String
  /// The intention key the author tagged this with, `nil` when they left it
  /// untagged. Resolved to display copy against tonight's options.
  let intention: String?
  let createdAt: Date

  /// Country display name from the ISO code, in the user's locale.
  var countryName: String {
    guard let countryISO else { return "" }
    return Locale.current.localizedString(forRegionCode: countryISO) ?? countryISO
  }

  /// The tag's display label, looked up in the options tonight's schedule
  /// carries. Falls back to the key humanised, so a word retired in the admin
  /// still reads on the older messages that carry it.
  func intentionLabel(in options: [Intention]) -> String? {
    guard let intention else { return nil }
    if let match = options.first(where: { $0.key == intention }) { return match.label }
    return intention.replacingOccurrences(of: "-", with: " ").capitalized
  }
}
