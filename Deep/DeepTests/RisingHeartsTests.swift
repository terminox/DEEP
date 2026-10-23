import Testing
@testable import Deep

/// How many hearts a gift sends up: more for a bigger gift, never a flood.
struct RisingHeartsTests {
  @Test("One heart still sends a small drift")
  func oneHeart() {
    #expect(RisingHearts.count(for: 1) == 5)
  }

  @Test("The field grows with the gift", arguments: [(2, 9), (5, 14), (10, 18), (30, 24)])
  func grows(amount: Int, expected: Int) {
    #expect(RisingHearts.count(for: amount) == expected)
  }

  @Test("Big gifts all rise the same capped field", arguments: [27, 100, 10_000])
  func capped(amount: Int) {
    #expect(RisingHearts.count(for: amount) == 24)
  }

  @Test("Never fewer hearts for a bigger gift")
  func monotonic() {
    let counts = (1...200).map(RisingHearts.count(for:))
    #expect(zip(counts, counts.dropFirst()).allSatisfy { $0 <= $1 })
  }
}
