import Testing
import Foundation
import StoreKit
@testable import Deep

/// The one price-and-trial recipe both store conformers must share: a monthly
/// plan shows the store's own price untouched, a yearly plan shows a twelfth of
/// itself in the store's currency, and a trial is spoken in the units a member
/// reads.
@MainActor
struct SubscriptionPlanFormattingTests {
  /// The style StoreKit hands over for a US storefront, built explicitly.
  ///
  /// Never `.currency(code: "USD")` on its own: that picks up whatever locale
  /// the test runner happens to sit in and renders "US$5.00" on a machine set
  /// to Thai, which passes at a desk and fails in CI.
  private static let usd = Decimal.FormatStyle.Currency(
    code: "USD",
    locale: Locale(identifier: "en_US")
  )

  private static func decimal(_ string: String) -> Decimal {
    Decimal(string: string)!
  }

  // MARK: - Per-month label

  @Test("A monthly plan shows the store's own price, untouched")
  func monthlyPassesDisplayPriceThrough() {
    // The price deliberately disagrees with the display price: the monthly
    // branch must pass the store's string through rather than re-format it.
    let label = SubscriptionPlanFormatting.perMonthLabel(
      period: .monthly,
      displayPrice: "$19.98",
      price: Self.decimal("999.00"),
      currency: Self.usd
    )
    #expect(label == "$19.98/mo")
  }

  @Test("A yearly plan shows a twelfth of itself")
  func yearlyDividesByTwelve() {
    let price = Self.decimal("59.99")
    let label = SubscriptionPlanFormatting.perMonthLabel(
      period: .yearly,
      displayPrice: "$59.99",
      price: price,
      currency: Self.usd
    )
    #expect(label == "$5.00/mo")
  }

  @Test("A yearly price that divides to an exact half-cent rounds up, not to even")
  func yearlyRoundsHalfAwayFromZero() {
    // 91.98 / 12 = 7.665 exactly. Foundation's default half-to-even rounding
    // would render $7.66 — a cent below the figure the member is quoted.
    let label = SubscriptionPlanFormatting.perMonthLabel(
      period: .yearly,
      displayPrice: "$91.98",
      price: Self.decimal("91.98"),
      currency: Self.usd
    )
    #expect(label == "$7.67/mo")
  }

  @Test("The per-month figure is spelled in the store's own currency")
  func yearlyUsesTheStoresCurrency() {
    let baht = Decimal.FormatStyle.Currency(code: "THB", locale: Locale(identifier: "th_TH"))
    let label = SubscriptionPlanFormatting.perMonthLabel(
      period: .yearly,
      displayPrice: "฿1,200.00",
      price: Self.decimal("1200.00"),
      currency: baht
    )
    // Whatever the locale spells it as, it is a hundred baht and a /mo suffix.
    #expect(label.hasSuffix("/mo"))
    #expect(label.contains("100"))
    #expect(label == "\(baht.format(Self.decimal("100.00")))/mo")
  }

  // MARK: - Trial note

  @Test("A trial counted in days is spoken in days")
  func trialInDays() {
    #expect(SubscriptionPlanFormatting.trialNote(count: 3, unit: .day) == "3-day free trial")
  }

  @Test("A trial counted in weeks is spoken in days")
  func trialInWeeksBecomesDays() {
    // The stores record a trial as one week; it is offered, and read, as seven
    // days. Both plans in the product carry this one.
    #expect(SubscriptionPlanFormatting.trialNote(count: 1, unit: .week) == "7-day free trial")
    #expect(SubscriptionPlanFormatting.trialNote(count: 2, unit: .week) == "14-day free trial")
  }

  @Test("A trial counted in months or years keeps its own unit")
  func trialInMonthsAndYears() {
    #expect(SubscriptionPlanFormatting.trialNote(count: 1, unit: .month) == "1-month free trial")
    #expect(SubscriptionPlanFormatting.trialNote(count: 1, unit: .year) == "1-year free trial")
  }

  // MARK: - Trial days

  @Test("Only fixed-length units yield a day count")
  func trialDaysOnlyForFixedUnits() {
    #expect(SubscriptionPlanFormatting.trialDays(count: 3, unit: .day) == 3)
    #expect(SubscriptionPlanFormatting.trialDays(count: 1, unit: .week) == 7)
    // A month is 28 to 31 days. Guessing would put a wrong number in a
    // sentence about money.
    #expect(SubscriptionPlanFormatting.trialDays(count: 1, unit: .month) == nil)
    #expect(SubscriptionPlanFormatting.trialDays(count: 1, unit: .year) == nil)
  }

  // MARK: - StoreKit narrowing

  @Test("StoreKit's period units narrow to ours one for one")
  func storeKitUnitsNarrow() {
    #expect(StoreKitSubscriptionStore.unit(.day) == .day)
    #expect(StoreKitSubscriptionStore.unit(.week) == .week)
    #expect(StoreKitSubscriptionStore.unit(.month) == .month)
    #expect(StoreKitSubscriptionStore.unit(.year) == .year)
    // The `@unknown default` arm can't be reached from a test — StoreKit's
    // enum has no case to hand it. It exists so a future OS adding one degrades
    // to the shortest trial rather than failing to compile.
  }
}
