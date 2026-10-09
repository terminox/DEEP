import Testing
import SwiftUI
import UIKit
@testable import Deep

/// The mini player's notice line. The regression it guards: "Today's 3 sound
/// hearts are in" truncated in the mini player ("Today's 3 sound hearts ar…"),
/// and Thai runs longer still — so the mini player reads a compact count while
/// Now Playing and VoiceOver keep the sentence.
@MainActor
struct ListenNoticeLabelTests {
  /// The subtitle column the mini player leaves on the narrowest supported
  /// iPhone (375pt, iPhone SE): a ~335pt accessory pill, less the bar's
  /// padding (24), artwork (36), two transport buttons (80), the spacer's
  /// minimum (8) and four 10pt gaps (40) — about 147pt. Measured against a
  /// little less, for margin.
  private static let narrowestColumn: CGFloat = 140

  private static let dayComplete = ListenNotice(
    id: UUID(),
    kind: .dayComplete(perDay: RewardRules.trackDailyLimit)
  )

  private static let english = Bundle.main.path(forResource: "en", ofType: "lproj")
    .flatMap(Bundle.init(path:)) ?? .main
  private static let thai = Bundle.main.path(forResource: "th", ofType: "lproj")
    .flatMap(Bundle.init(path:)) ?? .main

  private func label(compact: Bool, bundle: Bundle, locale: Locale) -> ListenNoticeLabel {
    ListenNoticeLabel(notice: Self.dayComplete, isCompact: compact, bundle: bundle, locale: locale)
  }

  /// The label's natural single-line width at default Dynamic Type.
  private func idealWidth(of label: ListenNoticeLabel) -> CGFloat {
    let host = UIHostingController(rootView: label.environment(\.dynamicTypeSize, .large))
    return host.sizeThatFits(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 200)).width
  }

  @Test("The mini player says today's hearts as a count; the sentence stays for Now Playing")
  func compactAndFullWording() {
    let english = Locale(identifier: "en")
    let thai = Locale(identifier: "th")

    #expect(label(compact: true, bundle: Self.english, locale: english).message == "3/3 hearts today")
    #expect(label(compact: false, bundle: Self.english, locale: english).message == "Today's 3 sound hearts are in")
    #expect(label(compact: true, bundle: Self.thai, locale: thai).message == "วันนี้ครบ 3/3 หัวใจ")
    #expect(
      label(compact: false, bundle: Self.thai, locale: thai).message
        == "วันนี้ได้รับหัวใจจากการฟังครบ 3 ดวงแล้ว"
    )
  }

  @Test("The compact count fits the narrowest iPhone's mini player, in English and Thai")
  func compactFitsTheNarrowestColumn() {
    let english = idealWidth(of: label(compact: true, bundle: Self.english, locale: Locale(identifier: "en")))
    let thai = idealWidth(of: label(compact: true, bundle: Self.thai, locale: Locale(identifier: "th")))
    let sentence = idealWidth(of: label(compact: false, bundle: Self.english, locale: Locale(identifier: "en")))

    #expect(english <= Self.narrowestColumn, "EN compact is \(english)pt")
    #expect(thai <= Self.narrowestColumn, "TH compact is \(thai)pt")
    #expect(english < sentence)
  }
}
