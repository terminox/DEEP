import Testing
@testable import Deep

/// The fold behind the live session's continent row. What it guards: the row
/// is a map, not a leaderboard — its order must come from geography and never
/// from the counts, or columns reshuffle underneath someone who is meditating.
struct ContinentRollTests {
  @Test func ordersWestToEastRegardlessOfSize() {
    let row = ContinentPresence.row(
      from: ["OC": 9000, "AS": 1, "AF": 500, "EU": 20, "NA": 3]
    )
    #expect(row.map(\.continent) == [.americas, .europe, .africa, .asia, .oceania])
  }

  @Test func mergesTheTwoAmericas() {
    let row = ContinentPresence.row(from: ["NA": 604, "SA": 199])
    #expect(row.count == 1)
    #expect(row[0].continent == .americas)
    #expect(row[0].count == 803)
  }

  /// A continent nobody is in has nothing to say — a nought beside its name
  /// would read as an absence rather than a fact.
  @Test func dropsEmptyAndUnknownContinents() {
    let row = ContinentPresence.row(from: ["AS": 12, "AF": 0, "EU": -3, "XX": 99])
    #expect(row.map(\.continent) == [.asia])
    #expect(ContinentPresence.row(from: [:]).isEmpty)
  }

  @Test func antarcticaComesLastWhenSomeoneIsThere() {
    let row = ContinentPresence.row(from: ["AN": 1, "AS": 40, "NA": 7])
    #expect(row.map(\.continent) == [.americas, .asia, .antarctica])
  }

  @Test func readsCodesCaseInsensitivelyAndRefusesJunk() {
    #expect(Continent(iso: "as") == .asia)
    #expect(Continent(iso: "sa") == .americas)
    #expect(Continent(iso: "ZZ") == nil)
    #expect(Continent(iso: "") == nil)
  }

  /// "the Americas" inside a sentence, "Americas" as a label.
  @Test func spokenNameSuitsASentence() {
    #expect(Continent.americas.spokenName == "the Americas")
    #expect(Continent.americas.name == "Americas")
    #expect(Continent.asia.spokenName == "Asia")
  }
}
