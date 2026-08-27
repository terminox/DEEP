import SwiftUI

/// The parts a peace message is made of, shared by the card in Fuku's Lounge
/// and by the composer the member writes into at the end of a pause.
///
/// They are one file on purpose: the composer is a *preview* of the card, so
/// the two must be the same object. Anything that lives in only one of them is
/// a promise the other breaks.

/// A radial-gradient avatar with a serif italic initial.
struct PeaceMessageAvatar: View {
  let tint: Color
  let initial: String

  var body: some View {
    ZStack {
      Circle()
        .fill(
          RadialGradient(
            colors: [.white.opacity(0.95), tint.opacity(0.85)],
            center: .topLeading,
            startRadius: 1,
            endRadius: 24
          )
        )
      Text(initial)
        .font(.system(.subheadline, design: .serif, weight: .light))
        .italic()
        .foregroundStyle(Color.deepPlum.opacity(0.85))
    }
    .overlay(
      Circle().stroke(.white.opacity(0.7), lineWidth: 0.6)
    )
    .shadow(color: tint.opacity(0.4), radius: 6, x: 0, y: 3)
  }
}

/// Who left the message, and where from — the two lines that head every card.
/// The place is what finally spends the country the app has always collected.
struct PeaceMessageIdentity: View {
  let name: String
  /// Localised country name; empty when the place isn't known, in which case
  /// the line is simply absent rather than blank.
  let place: String
  /// Seed for the avatar's tint — a message id in the feed, the member's own
  /// name in the composer, so a person's colour holds still.
  let tintSeed: String

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      PeaceMessageAvatar(
        tint: Self.tint(for: tintSeed),
        initial: name.first.map(String.init) ?? "?"
      )
      .frame(width: 32, height: 32)

      VStack(alignment: .leading, spacing: 1) {
        Text(name)
          .font(DeepType.body.weight(.medium))
          .foregroundStyle(.deepPlum)
          .lineLimit(1)
        if !place.isEmpty {
          Text(place)
            .font(DeepType.micro)
            .foregroundStyle(.driftGrey)
            .lineLimit(1)
        }
      }
      // Not a Spacer: a Spacer would bid against this flexible text column and
      // truncate names that have room.
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  /// Hashes the seed into one of four tints so a message keeps its colour
  /// across refreshes.
  static func tint(for seed: String) -> Color {
    let tints: [Color] = [.lavenderMist, .blushPowder, .skyWash, .peachCloud]
    let index = abs(seed.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }) % tints.count
    return tints[index]
  }
}

extension View {
  /// The surface every peace message sits on, composed or published.
  func peaceMessageCard() -> some View {
    self
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .frostedCard(cornerRadius: .tile)
  }
}

#Preview("Card chrome") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: .rhythm) {
      PeaceMessageIdentity(name: "Haruki", place: "Japan", tintSeed: "fixture-2")
        .peaceMessageCard()
      PeaceMessageIdentity(name: "Friend", place: "", tintSeed: "friend")
        .peaceMessageCard()
    }
    .padding(.edge)
  }
}
