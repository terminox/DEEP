import Testing
import Foundation
@testable import Deep

/// Where Settings sends a member to manage DEEP Premium.
@MainActor
struct SubscriptionManagementTests {
  private static let page = URL(string: "https://billing.example.test/manage")!

  @Test("An App Store purchase is managed in Apple's sheet, whatever URL RevenueCat names")
  func appStore() {
    #expect(RevenueCatSubscriptionStore.management(isAppStore: true, managementURL: Self.page) == .appStore)
    #expect(RevenueCatSubscriptionStore.management(isAppStore: true, managementURL: nil) == .appStore)
  }

  @Test("A purchase made elsewhere is managed at the page RevenueCat names")
  func elsewhere() {
    #expect(RevenueCatSubscriptionStore.management(isAppStore: false, managementURL: Self.page) == .web(Self.page))
  }

  @Test("Elsewhere with no page named falls back to Apple's sheet")
  func elsewhereWithoutPage() {
    #expect(RevenueCatSubscriptionStore.management(isAppStore: false, managementURL: nil) == .appStore)
  }
}
