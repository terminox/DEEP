import SwiftUI

/// The player chrome's word about a listen's heart — "+1 heart", or that
/// today's track hearts are all in. Paired exactly as `HeartBalanceChip`
/// pairs its icon and figure: a small semibold blush heart beside deepPlum
/// text, so a heart reads the same wherever the app shows one. The caller
/// picks the type token so the label sits in the line it replaces.
struct ListenNoticeLabel: View {
  let notice: ListenNotice
  var font: Font = DeepType.micro
  /// The mini player's tight line: today's hearts read as a count ("3/3
  /// hearts today") rather than the sentence Now Playing has room for. The
  /// full sentence is still what VoiceOver hears (`ListenReporter`).
  var isCompact = false
  /// The catalog the copy resolves in. Resolved here rather than by `Text`'s
  /// key lookup because the accessory and Now Playing hosts sit outside the
  /// tree that carries the picked language; previews pin one through these.
  var bundle: Bundle = .app
  var locale: Locale = .app

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "heart.fill")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.blushPowder)
      Text(message)
        .font(font)
        .foregroundStyle(.deepPlum)
        .lineLimit(1)
    }
  }

  var message: String {
    switch notice.kind {
    case .earned:
      String(localized: "+1 heart", bundle: bundle, locale: locale)
    case .dayComplete(let perDay) where isCompact:
      String(localized: "\(perDay)/\(perDay) hearts today", bundle: bundle, locale: locale)
    case .dayComplete(let perDay):
      String(localized: "Today's \(perDay) sound hearts are in", bundle: bundle, locale: locale)
    }
  }
}

/// A newly earned listen heart: the `HeartBurst` bloom out of the anchor
/// (when `blooms`), and its light haptic — claimed through the reporter, so
/// the heart is felt once even while Now Playing and the mini player are
/// both mounted.
private struct ListenHeartModifier: ViewModifier {
  let notice: ListenNotice?
  let blooms: Bool
  @Environment(\.listenReporter) private var listenReporter
  @State private var bloom = 0
  @State private var felt = 0

  func body(content: Content) -> some View {
    Group {
      if blooms {
        content.heartBurst(trigger: bloom, haptic: false)
      } else {
        content
      }
    }
    .heartBurstHaptic(trigger: felt)
    .onChange(of: notice?.id) {
      guard let notice, notice.kind == .earned else { return }
      if blooms { bloom += 1 }
      if listenReporter.claimHaptic(for: notice) { felt += 1 }
    }
  }
}

extension View {
  /// Blooms a heart out of this view whenever `notice` turns to a newly
  /// earned heart, and feels it — once across every surface showing it.
  func heartBurst(for notice: ListenNotice?) -> some View {
    modifier(ListenHeartModifier(notice: notice, blooms: true))
  }

  /// Feels a newly earned heart without the bloom — for the mini player,
  /// whose capsule clips anything rising out of it.
  func heartHaptic(for notice: ListenNotice?) -> some View {
    modifier(ListenHeartModifier(notice: notice, blooms: false))
  }
}

#if DEBUG
/// The Thai catalog, so a preview can show the longer copy without touching
/// the app's language setting.
private let thaiBundle = Bundle.main.path(forResource: "th", ofType: "lproj")
  .flatMap(Bundle.init(path:)) ?? .main

#Preview("Listen notice") {
  let dayComplete = ListenNotice(id: UUID(), kind: .dayComplete(perDay: RewardRules.trackDailyLimit))
  VStack(alignment: .leading, spacing: 16) {
    ListenNoticeLabel(notice: ListenNotice(id: UUID(), kind: .earned))
    ListenNoticeLabel(notice: dayComplete)
    ListenNoticeLabel(notice: dayComplete, isCompact: true)
    ListenNoticeLabel(notice: ListenNotice(id: UUID(), kind: .earned), font: DeepType.body)
  }
  .padding(.edge)
  .background(.moonCream)
}

#Preview("Listen notice — Thai") {
  let dayComplete = ListenNotice(id: UUID(), kind: .dayComplete(perDay: RewardRules.trackDailyLimit))
  VStack(alignment: .leading, spacing: 16) {
    ListenNoticeLabel(notice: ListenNotice(id: UUID(), kind: .earned), bundle: thaiBundle, locale: Locale(identifier: "th"))
    ListenNoticeLabel(notice: dayComplete, bundle: thaiBundle, locale: Locale(identifier: "th"))
    ListenNoticeLabel(notice: dayComplete, isCompact: true, bundle: thaiBundle, locale: Locale(identifier: "th"))
  }
  .padding(.edge)
  .background(.moonCream)
}
#endif
