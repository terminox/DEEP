#if DEBUG
import SwiftUI

// PROTOTYPE — throwaway.
// Variant B, "Growth Journal": one long diary scroll, oldest first, under a
// pinned oak that regrows into whichever form stood on the day being read.

/// The diary itself. A pinned tree stage sits over a scrolling column of dated
/// entries; reading down the page scrubs the oak through its forms, and the
/// diary ends on today with the member's figures and the export.
struct GrowthJournalPrototypeView: View {
  let sample: PassportSample

  @State private var scroll = GrowthJournalScrollState()
  /// Drives the demo-recording auto-scroll only; a finger scroll ignores it.
  @State private var position = ScrollPosition(edge: .top)
  @Environment(\.exportPassport) private var exportPassport

  var body: some View {
    GeometryReader { proxy in
      let safeTop = proxy.safeAreaInsets.top
      ZStack(alignment: .top) {
        AtmosphereBackground()

        ScrollView {
          GrowthJournalDiary(sample: sample, scroll: scroll, topInset: safeTop + GrowthJournalMetrics.expanded) {
            exportPassport()
          }
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .task { await demoAutoScroll() }
        .onScrollGeometryChange(for: GrowthJournalScrollMetrics.self) { geometry in
          GrowthJournalScrollMetrics(
            scrolled: geometry.contentOffset.y + geometry.contentInsets.top,
            viewport: geometry.containerSize.height,
            insetTop: geometry.contentInsets.top
          )
        } action: { _, metrics in
          scroll.scrolled = metrics.scrolled
          scroll.viewport = metrics.viewport
          scroll.insetTop = metrics.insetTop
        }
        // Entries dissolve into the atmosphere as they pass under the tree, so
        // the stage needs no backdrop of its own and the orbs stay untouched.
        .mask { GrowthJournalScrollMask(scroll: scroll, safeTop: safeTop) }
        .ignoresSafeArea(edges: .top)

        GrowthJournalStageHeader(sample: sample, scroll: scroll)
          .padding(.horizontal, .edge)
          .allowsHitTesting(false)
      }
    }
  }

  /// `-demoAutoScroll` reads the diary top to bottom in slow, even steps, for
  /// screen recordings (synthetic simulator swipes stick and jump back). The
  /// real scroll moves, so the tree and the blooms behave as under a finger.
  private func demoAutoScroll() async {
    guard ProcessInfo.processInfo.arguments.contains("-demoAutoScroll") else { return }
    try? await Task.sleep(for: .seconds(2.5))
    var y: CGFloat = 0
    for _ in 0..<16 {
      y += 230
      withAnimation(.easeInOut(duration: 1.4)) { position.scrollTo(y: y) }
      try? await Task.sleep(for: .seconds(2.3))
      if Task.isCancelled { return }
    }
  }
}

// MARK: - Scroll state

/// Scroll geometry and where each entry sits in the diary. Kept in an
/// observable box so only the pinned stage and the mask redraw per frame; the
/// diary column itself never reads it.
@Observable
private final class GrowthJournalScrollState {
  /// Upward scroll distance, 0 at the resting top.
  var scrolled: CGFloat = 0
  var viewport: CGFloat = 0
  var insetTop: CGFloat = 0
  /// Top of each entry in diary content space, keyed by moment index. The
  /// Today card is keyed one past the last moment.
  var entryTops: [Int: CGFloat] = [:]
}

private struct GrowthJournalScrollMetrics: Equatable {
  let scrolled: CGFloat
  let viewport: CGFloat
  let insetTop: CGFloat
}

/// The stage's fixed measurements. The diary's top spacer equals the expanded
/// stage, and the collapse distance equals what the stage loses, so the first
/// entry rides exactly under the stage's lower edge while it shrinks.
private enum GrowthJournalMetrics {
  static let topPadding: CGFloat = 8
  static let bottomPadding: CGFloat = 14
  static let header: CGFloat = 66
  static let treeMax: CGFloat = 204
  static let treeMin: CGFloat = 96
  static let expanded = topPadding + header + treeMax + bottomPadding
  static let collapsed = topPadding + treeMin + bottomPadding
  static let collapseDistance = expanded - collapsed
  /// Where the "now reading" line sits, as a share of the visible height.
  static let readingLine: CGFloat = 0.42
  static let contentSpace = "growthJournal.content"

  static func collapse(_ scrolled: CGFloat) -> CGFloat {
    min(1, max(0, scrolled / collapseDistance))
  }

  static func lerp(_ from: CGFloat, _ to: CGFloat, _ t: CGFloat) -> CGFloat {
    from + (to - from) * t
  }
}

/// Fades the scroll content out just above the stage's lower edge.
private struct GrowthJournalScrollMask: View {
  let scroll: GrowthJournalScrollState
  let safeTop: CGFloat

  var body: some View {
    let stage = GrowthJournalMetrics.lerp(
      GrowthJournalMetrics.expanded,
      GrowthJournalMetrics.collapsed,
      GrowthJournalMetrics.collapse(scroll.scrolled)
    )
    VStack(spacing: 0) {
      Color.clear.frame(height: max(0, safeTop + stage - 38))
      LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
        .frame(height: 38)
      Color.black
    }
  }
}

// MARK: - Pinned stage

/// The growing tree, its form's name, the member's start date and the month
/// under the reading line. Collapses from a tall stage to a compact row as the
/// diary scrolls, and swaps the oak's form when the entry being read does.
private struct GrowthJournalStageHeader: View {
  let sample: PassportSample
  let scroll: GrowthJournalScrollState

  private typealias Metrics = GrowthJournalMetrics

  private var todayKey: Int { sample.moments.count }

  /// The diary position of the reading line, in content space.
  private var readingY: CGFloat {
    scroll.viewport * Metrics.readingLine + scroll.scrolled - scroll.insetTop
  }

  /// The last entry the reading line has passed; nil above the first one.
  private var readKey: Int? {
    let line = readingY
    return scroll.entryTops.filter { $0.value <= line }.map(\.key).max()
  }

  private var shownStage: Int {
    guard let key = readKey else { return sample.moments.first?.stageIndex ?? 0 }
    return key >= todayKey ? sample.currentStageIndex : sample.moments[key].stageIndex
  }

  private var monthLabel: String {
    guard let key = readKey else {
      return sample.moments.first.map { GrowthJournalDates.month($0.date) } ?? "TODAY"
    }
    return key >= todayKey ? "TODAY" : GrowthJournalDates.month(sample.moments[key].date)
  }

  /// 0...1 through the stretch of diary the shown form stood for. The current
  /// form only grows as far as its real sunlight has taken it.
  private var growth: CGFloat {
    let stage = shownStage
    let moments = sample.moments
    let startKey = moments.firstIndex { $0.stageIndex == stage } ?? 0
    let endKey = moments.firstIndex { $0.stageIndex > stage } ?? todayKey
    guard let start = scroll.entryTops[startKey], let end = scroll.entryTops[endKey], end > start else {
      return 0
    }
    let through = min(1, max(0, (readingY - start) / (end - start)))
    return stage == sample.currentStageIndex ? through * sample.growthProgress : through
  }

  var body: some View {
    let collapse = Metrics.collapse(scroll.scrolled)
    let treeSize = Metrics.lerp(Metrics.treeMax, Metrics.treeMin, collapse)
    let stage = shownStage

    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 6) {
        Text("GROWTH JOURNAL")
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)
        Text("Your story with DEEP")
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .frame(height: Metrics.header * (1 - collapse), alignment: .top)
      .clipped()
      .opacity(Double(max(0, 1 - collapse * 1.8)))

      HStack(alignment: .center, spacing: 14) {
        GrowthJournalTree(stage: stage, growth: growth, size: treeSize)

        VStack(alignment: .leading, spacing: 6) {
          Text(sample.stages[stage].name)
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
            .contentTransition(.opacity)
            .animation(.exhale, value: stage)
          Text("Since \(GrowthJournalDates.long(sample.memberSince))")
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .opacity(Double(max(0, 1 - collapse * 1.6)))
          Text(monthLabel)
            .font(DeepType.micro)
            .tracking(.microTracking)
            .foregroundStyle(.deepPlum.opacity(0.7))
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.exhale, value: monthLabel)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.42), in: Capsule())
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(.top, Metrics.topPadding)
    .padding(.bottom, Metrics.bottomPadding)
    .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.45), trigger: stage)
  }
}

/// The oak, multiplied over a soft meadow glow so its white square vanishes.
/// A new form blooms in (0.94 → 1 and opacity, slow); within one form the art
/// swells very slightly with the reading position, scrubbed rather than animated.
private struct GrowthJournalTree: View {
  let stage: Int
  let growth: CGFloat
  let size: CGFloat

  var body: some View {
    ZStack {
      Circle()
        .fill(
          RadialGradient(
            colors: [
              GardenColor.meadow.opacity(0.85),
              Color.softLilac.opacity(0.35),
              Color.softLilac.opacity(0),
            ],
            center: .center,
            startRadius: 0,
            endRadius: size * 0.56
          )
        )
        .frame(width: size * 1.12, height: size * 1.12)

      ZStack {
        PassportArt.oak(stage: stage)
          .resizable()
          .scaledToFit()
          .blendMode(.multiply)
          .id(stage)
          .transition(
            .asymmetric(
              insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .bottom)),
              removal: .opacity
            )
          )
      }
      .animation(.bloom.speed(0.8), value: stage)
      .scaleEffect(0.92 + 0.08 * growth, anchor: .bottom)
      .frame(width: size, height: size)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

// MARK: - Diary

/// The scrolling column: month groups of entries, the Today card, and (for a
/// first week) the pages still ahead.
private struct GrowthJournalDiary: View {
  let sample: PassportSample
  let scroll: GrowthJournalScrollState
  let topInset: CGFloat
  let onExport: () -> Void

  private var months: [GrowthJournalMonth] { GrowthJournalMonth.group(sample.moments) }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Color.clear.frame(height: topInset)

      VStack(alignment: .leading, spacing: 34) {
        ForEach(months) { month in
          VStack(alignment: .leading, spacing: 14) {
            GrowthJournalMonthHeader(title: month.title)
            ForEach(month.entries, id: \.index) { entry in
              GrowthJournalEntryRow(
                sample: sample,
                moment: entry.moment,
                showsDate: entry.showsDate
              )
              .modifier(GrowthJournalMeasured(key: entry.index, scroll: scroll))
              .modifier(GrowthJournalBloom())
            }
          }
        }

        GrowthJournalTodayCard(sample: sample, onExport: onExport)
          .modifier(GrowthJournalMeasured(key: sample.moments.count, scroll: scroll))
          .modifier(GrowthJournalBloom())

        if sample.journey == .firstWeek {
          GrowthJournalAhead(sample: sample)
        }
      }
    }
    .coordinateSpace(.named(GrowthJournalMetrics.contentSpace))
    .padding(.horizontal, .edge)
    .padding(.bottom, 120)
  }
}

/// Records an entry's top in diary content space. Content-space frames hold
/// still while scrolling, so this only fires on layout.
private struct GrowthJournalMeasured: ViewModifier {
  let key: Int
  let scroll: GrowthJournalScrollState

  func body(content: Content) -> some View {
    content.onGeometryChange(for: CGFloat.self) { proxy in
      proxy.frame(in: .named(GrowthJournalMetrics.contentSpace)).minY
    } action: { top in
      scroll.entryTops[key] = top
    }
  }
}

/// Entries bloom in from below as they enter: scale 0.92 → 1, opacity, a
/// small rise, slow. Leaving at the top they stay put and the mask dissolves them.
private struct GrowthJournalBloom: ViewModifier {
  func body(content: Content) -> some View {
    content.scrollTransition(
      topLeading: .identity,
      bottomTrailing: .animated(.bloom).threshold(.visible(0.25))
    ) { view, phase in
      view
        .opacity(phase.isIdentity ? 1 : 0)
        .scaleEffect(phase.isIdentity ? 1 : 0.92)
        .offset(y: phase.isIdentity ? 0 : 14)
    }
  }
}

/// One month of the diary.
private struct GrowthJournalMonth: Identifiable {
  struct Entry {
    let index: Int
    let moment: PassportMoment
    /// False for a second entry on the same day, so the date reads once.
    let showsDate: Bool
  }

  let title: String
  let entries: [Entry]

  var id: String { title }

  static func group(_ moments: [PassportMoment]) -> [GrowthJournalMonth] {
    let calendar = GrowthJournalDates.calendar
    var months: [GrowthJournalMonth] = []
    var current: [Entry] = []
    var currentTitle: String?
    var lastDay: Date?

    for (index, moment) in moments.enumerated() {
      let title = GrowthJournalDates.month(moment.date)
      if title != currentTitle {
        if let currentTitle { months.append(GrowthJournalMonth(title: currentTitle, entries: current)) }
        current = []
        currentTitle = title
        lastDay = nil
      }
      let sameDay = lastDay.map { calendar.isDate($0, inSameDayAs: moment.date) } ?? false
      current.append(Entry(index: index, moment: moment, showsDate: !sameDay))
      lastDay = moment.date
    }
    if let currentTitle { months.append(GrowthJournalMonth(title: currentTitle, entries: current)) }
    return months
  }
}

private struct GrowthJournalMonthHeader: View {
  let title: String

  var body: some View {
    Text(title)
      .font(DeepType.micro)
      .tracking(.microTracking)
      .foregroundStyle(.driftGrey)
      .accessibilityAddTraits(.isHeader)
  }
}

// MARK: - Entries

/// A dated diary line: the day in a left column, the moment in a frosted card.
private struct GrowthJournalEntryRow: View {
  let sample: PassportSample
  let moment: PassportMoment
  let showsDate: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(spacing: 2) {
        Text(GrowthJournalDates.day(moment.date))
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
          .monospacedDigit()
        Text(GrowthJournalDates.weekday(moment.date))
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)
      }
      .frame(width: 40)
      .padding(.top, 12)
      .opacity(showsDate ? 1 : 0)
      .accessibilityHidden(!showsDate)

      card
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private var card: some View {
    switch moment.kind {
    case .stage: GrowthJournalStageCard(sample: sample, moment: moment)
    case .message: GrowthJournalNoteCard(moment: moment)
    default: GrowthJournalMomentCard(sample: sample, moment: moment)
    }
  }
}

/// The everyday entry: glyph in its bubble, one serif title, a caption.
private struct GrowthJournalMomentCard: View {
  let sample: PassportSample
  let moment: PassportMoment

  private var symbol: String {
    if moment.kind == .challenge,
       let challenge = sample.challenges.first(where: { $0.title == moment.title }) {
      return challenge.symbol
    }
    return moment.symbol
  }

  /// The causes a hearts entry speaks of: named in its detail, all of them for
  /// the "every cause" entry, or else whichever was first reached that day.
  private var causes: [PassportCauseGift] {
    guard moment.kind == .hearts else { return [] }
    if moment.title.hasPrefix("Every cause") { return sample.gifts }
    let named = sample.gifts.filter { moment.detail.contains($0.category.name) }
    if !named.isEmpty { return named }
    return sample.gifts.filter { GrowthJournalDates.calendar.isDate($0.firstGivenOn, inSameDayAs: moment.date) }
  }

  var body: some View {
    let style = GrowthJournalGlyphStyle(kind: moment.kind)
    HStack(alignment: .top, spacing: 14) {
      GrowthJournalGlyph(symbol: symbol, style: style)

      VStack(alignment: .leading, spacing: 5) {
        Text(moment.title)
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
          .fixedSize(horizontal: false, vertical: true)
        Text(moment.detail)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .fixedSize(horizontal: false, vertical: true)
        if !causes.isEmpty {
          GrowthJournalCauseDots(causes: causes)
            .padding(.top, 4)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(16)
    .frostedCard()
  }
}

/// A cause's palette dot, named when it is the only one.
private struct GrowthJournalCauseDots: View {
  let causes: [PassportCauseGift]

  var body: some View {
    HStack(spacing: 6) {
      ForEach(causes) { gift in
        Circle()
          .fill(LinearGradient(colors: gift.category.palette.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
          .frame(width: 10, height: 10)
          .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 0.5))
      }
      if causes.count == 1, let gift = causes.first {
        Text(gift.category.name)
          .font(DeepType.caption.weight(.medium))
          .foregroundStyle(.deepPlum.opacity(0.75))
      }
    }
  }
}

/// A new form: the portrait on a soft green bloom, the form's name as an
/// eyebrow, one serif line.
private struct GrowthJournalStageCard: View {
  let sample: PassportSample
  let moment: PassportMoment

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      PassportStagePortrait(stageIndex: moment.stageIndex, diameter: 76)
        .background {
          Circle()
            .fill(
              RadialGradient(
                colors: [GardenColor.meadow.opacity(0.9), GardenColor.meadow.opacity(0)],
                center: .center,
                startRadius: 20,
                endRadius: 76
              )
            )
            .frame(width: 152, height: 152)
        }

      VStack(alignment: .leading, spacing: 6) {
        Text(sample.stages[moment.stageIndex].name.uppercased())
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(GardenColor.fern)
        Text(moment.title)
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
          .fixedSize(horizontal: false, vertical: true)
        Text(moment.detail)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 22)
    .padding(.horizontal, 16)
    .frostedCard(tint: GardenColor.meadow)
    .background {
      Ellipse()
        .fill(
          RadialGradient(
            colors: [GardenColor.meadow.opacity(0.55), GardenColor.meadow.opacity(0)],
            center: .center,
            startRadius: 0,
            endRadius: 180
          )
        )
        .scaleEffect(x: 1.25, y: 1.5)
        .allowsHitTesting(false)
    }
  }
}

/// A peace message, kept like a handwritten note: serif italic.
private struct GrowthJournalNoteCard: View {
  let moment: PassportMoment

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        GrowthJournalGlyph(symbol: moment.symbol, style: GrowthJournalGlyphStyle(kind: .message), size: 30)
        Text(moment.title.uppercased())
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.irisDusk)
      }
      Text(moment.detail)
        .font(DeepType.revealTitle)
        .foregroundStyle(.deepPlum)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .frostedCard(tint: .softLilac)
  }
}

/// A glyph seated in its own soft tinted bubble.
private struct GrowthJournalGlyph: View {
  let symbol: String
  let style: GrowthJournalGlyphStyle
  var size: CGFloat = 40

  var body: some View {
    Image(systemName: symbol)
      .font(.system(size: size * 0.42, weight: .semibold))
      .foregroundStyle(style.ink)
      .frame(width: size, height: size)
      .background(style.bubble.opacity(0.34), in: Circle())
      .accessibilityHidden(true)
  }
}

/// Each kind of moment's colour: leaf greens for the plant, lavender for
/// practice, sky for the Global Pause, blush for hearts, iris for messages,
/// sunbeam for challenges.
private struct GrowthJournalGlyphStyle {
  let bubble: Color
  let ink: Color

  init(kind: PassportMoment.Kind) {
    switch kind {
    case .seed, .stage:
      bubble = GardenColor.meadow
      ink = GardenColor.fern
    case .practice:
      bubble = .lavenderMist
      ink = Color.lavenderMist.mix(with: .deepPlum, by: 0.12)
    case .pause:
      bubble = .skyWash
      ink = Color.skyWash.mix(with: .deepPlum, by: 0.38)
    case .hearts:
      bubble = .blushPowder
      ink = Color.blushPowder.mix(with: .deepPlum, by: 0.28)
    case .message:
      bubble = .irisDusk
      ink = .irisDusk
    case .challenge:
      bubble = GardenColor.sunbeam.opacity(0.7)
      ink = GardenColor.sunbeam
    }
  }
}

// MARK: - Today

/// The diary's last page: the form standing now in its growth halo, how far
/// the next form is, the member's practice in pebbles, and the export.
private struct GrowthJournalTodayCard: View {
  let sample: PassportSample
  let onExport: () -> Void

  private var stats: [ImpactStat] {
    [
      ImpactStat(label: "DEEP Sessions", value: sample.sessions.formatted(), symbol: "wind"),
      ImpactStat(label: "Minutes", value: sample.minutes.formatted(), symbol: "clock.fill"),
      ImpactStat(label: "Global Pauses", value: sample.pausesAttended.formatted(), symbol: "globe.asia.australia.fill"),
      ImpactStat(label: "Hearts sent", value: sample.heartsGiven.formatted(), symbol: "heart.fill"),
    ]
    .filter { $0.value != "0" }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .center, spacing: 16) {
        PassportStagePortrait(
          stageIndex: sample.currentStageIndex,
          diameter: 84,
          progress: sample.growthProgress
        )

        VStack(alignment: .leading, spacing: 6) {
          Text("TODAY")
            .font(DeepType.micro)
            .tracking(.microTracking)
            .foregroundStyle(.driftGrey)
          Text(sample.currentStage.name)
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
          growthFact
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
        ForEach(stats) { stat in
          StatPebble(stat: stat)
        }
      }

      Text(sample.note)
        .font(DeepType.body)
        .foregroundStyle(.driftGrey)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)

      RewardContinueButton(title: "Print or share passport", isFinal: true, action: onExport)
    }
    .padding(20)
    .frostedCard(tint: GardenColor.meadow)
  }

  @ViewBuilder
  private var growthFact: some View {
    if let threshold = sample.nextThreshold {
      let next = sample.stages[min(sample.currentStageIndex + 1, sample.stages.count - 1)].name
      let figure = Text(verbatim: sample.sunlight.formatted())
        .font(DeepType.caption.weight(.semibold))
        .foregroundStyle(GardenColor.sunbeam)
        .monospacedDigit()
      let words = Text(verbatim: "/\(threshold.formatted()) to \(next)")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
      SunlightFact {
        Text("\(figure)\(words)")
      }
    } else {
      HStack(spacing: 5) {
        Image(systemName: "leaf.fill")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(GardenColor.fern)
        Text("Fully grown")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      }
    }
  }
}

// MARK: - Ahead

/// A first week's diary is short, so it closes on the pages still to come:
/// the next form, named at its sunlight, and a first challenge. Dashed and
/// faint, so they read as invitation rather than as missing entries.
private struct GrowthJournalAhead: View {
  let sample: PassportSample

  private var nextForm: (name: String, threshold: Int)? {
    guard let threshold = sample.nextThreshold, sample.currentStageIndex + 1 < sample.stages.count else {
      return nil
    }
    return (sample.stages[sample.currentStageIndex + 1].name, threshold)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      GrowthJournalMonthHeader(title: "STILL AHEAD")
      if let nextForm {
        GrowthJournalGhostRow(
          symbol: "tree",
          title: nextForm.name,
          detail: "Your oak's next form, at \(nextForm.threshold.formatted()) sunlight."
        )
        .modifier(GrowthJournalBloom())
      }
      GrowthJournalGhostRow(
        symbol: "sparkles",
        title: "Your first challenge",
        detail: "A gentle practice shared with others, whenever you are ready."
      )
      .modifier(GrowthJournalBloom())
    }
  }
}

private struct GrowthJournalGhostRow: View {
  let symbol: String
  let title: String
  let detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Circle()
        .fill(.lavenderMist.opacity(0.35))
        .frame(width: 7, height: 7)
        .frame(width: 40)
        .padding(.top, 30)

      HStack(alignment: .top, spacing: 14) {
        Image(systemName: symbol)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.irisDusk.opacity(0.7))
          .frame(width: 40, height: 40)
          .overlay(
            Circle().strokeBorder(.lavenderMist.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
          )

        VStack(alignment: .leading, spacing: 5) {
          Text(title)
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum.opacity(0.6))
          Text(detail)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(16)
      .background {
        let shape = RoundedRectangle(cornerRadius: .card, style: .continuous)
        shape
          .fill(.white.opacity(0.18))
          .overlay(shape.strokeBorder(.lavenderMist.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [5, 6])))
      }
    }
  }
}

// MARK: - Dates

/// Diary dates in English, always on the Gregorian calendar (a Thai locale's
/// Buddhist calendar would shift every year by 543).
private enum GrowthJournalDates {
  static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    return calendar
  }()

  private static func formatter(_ format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_GB")
    formatter.timeZone = .current
    formatter.dateFormat = format
    return formatter
  }

  private static let monthFormatter = formatter("MMMM yyyy")
  private static let longFormatter = formatter("d MMMM yyyy")
  private static let dayFormatter = formatter("d")
  private static let weekdayFormatter = formatter("EEE")

  static func month(_ date: Date) -> String { monthFormatter.string(from: date).uppercased() }
  static func long(_ date: Date) -> String { longFormatter.string(from: date) }
  static func day(_ date: Date) -> String { dayFormatter.string(from: date) }
  static func weekday(_ date: Date) -> String { weekdayFormatter.string(from: date).uppercased() }
}

// MARK: - Previews

#Preview("First week") {
  GrowthJournalPrototypeView(sample: .firstWeek)
}

#Preview("Six months") {
  GrowthJournalPrototypeView(sample: .sixMonths)
}

#Preview("Two years") {
  GrowthJournalPrototypeView(sample: .twoYears)
}
#endif
