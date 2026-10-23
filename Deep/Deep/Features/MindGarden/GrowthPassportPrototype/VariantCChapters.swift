#if DEBUG
import SwiftUI
import UIKit

// PROTOTYPE — throwaway.
// Variant C, "Chapters": the passport as a calm full-screen story recap (a
// DEEP-quiet "Wrapped") that auto-advances chapter by chapter and ends on a
// shareable 9:16 keepsake card.

// MARK: - Root

/// A periodic reflection told in chapters. A segmented strip at the top fills
/// over each chapter; tap the right two thirds for the next, the left third for
/// the previous, and hold anywhere to pause. Auto-advance stops on the keepsake.
struct ChaptersPrototypeView: View {
  let sample: PassportSample

  @State private var current = 0
  /// The chapter just left, drawn settled and fading up and out above nothing
  /// else, then unmounted. A real removal transition would pop any chapter
  /// that runs a repeating animation, so the exit is a state animation instead.
  @State private var outgoing: ChaptersOutgoing?

  /// Seconds of the current chapter already played before the last pause.
  @State private var banked: TimeInterval = 0
  /// When the current run of the current chapter started (or resumed).
  @State private var runStart = Date.now
  @State private var isHolding = false
  /// The last chapter has filled its segment; the clock is done.
  @State private var finished = false

  @State private var isPressing = false
  @State private var holdTask: Task<Void, Never>?

  private var chapters: [ChaptersChapter] {
    var list: [ChaptersChapter] = [.seed, .growth, .time]
    if !sample.gifts.isEmpty { list.append(.hearts) }
    if !sample.challenges.isEmpty || !sample.peaceMessages.isEmpty { list.append(.joined) }
    list += [.note, .keepsake]
    return list
  }

  private var isLast: Bool { current == chapters.count - 1 }

  var body: some View {
    ZStack {
      ChaptersBackdrop(tone: chapters[current].tone)

      // The whole screen is the tap surface; content above it ignores touches
      // except the keepsake's two actions.
      GeometryReader { proxy in
        Color.clear
          .contentShape(Rectangle())
          .gesture(pressGesture(width: proxy.size.width))
      }
      .ignoresSafeArea()

      VStack(spacing: 0) {
        header
          .allowsHitTesting(false)

        ZStack {
          if let outgoing {
            ChaptersLeaving {
              chapterView(outgoing.index, settled: true)
            }
            .id(outgoing.token)
            .allowsHitTesting(false)
          }
          chapterView(current, settled: false)
            .id(current)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(isHolding ? 0.95 : 1)
        .animation(.exhale, value: isHolding)

        // The prototype switcher floats here.
        Color.clear
          .frame(height: 110)
          .allowsHitTesting(false)
      }
    }
    .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.45), trigger: current)
    .onAppear { runStart = .now }
    .task(id: ChaptersClockKey(current: current, isHolding: isHolding)) {
      await runClock()
    }
  }

  // MARK: Header

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      TimelineView(.animation(minimumInterval: nil, paused: isHolding || finished)) { context in
        let fill = fill(at: context.date)
        HStack(spacing: 5) {
          ForEach(chapters.indices, id: \.self) { index in
            ChaptersSegment(fill: index < current ? 1 : index == current ? fill : 0)
          }
        }
      }

      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text("deep")
          .font(DeepType.revealTitle)
          .foregroundStyle(.irisDusk)
        Text("YOUR GROWTH PASSPORT")
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)
      }
    }
    .padding(.horizontal, .edge)
    .padding(.top, 8)
  }

  // MARK: Chapters

  @ViewBuilder
  private func chapterView(_ index: Int, settled: Bool) -> some View {
    ChaptersPage(settled: settled) { shown in
      switch chapters[index] {
      case .seed: ChaptersSeedChapter(sample: sample, shown: shown, settled: settled)
      case .growth: ChaptersGrowthChapter(sample: sample, shown: shown, settled: settled)
      case .time: ChaptersTimeChapter(sample: sample, shown: shown, settled: settled)
      case .hearts: ChaptersHeartsChapter(sample: sample, shown: shown, settled: settled)
      case .joined: ChaptersJoinedChapter(sample: sample, shown: shown)
      case .note: ChaptersNoteChapter(sample: sample, shown: shown)
      case .keepsake: ChaptersKeepsakeChapter(sample: sample, shown: shown, settled: settled)
      }
    }
    // Only the keepsake has anything to press.
    .allowsHitTesting(chapters[index] == .keepsake)
  }

  // MARK: Clock

  private func fill(at date: Date) -> Double {
    if finished { return 1 }
    let running = isHolding ? 0 : date.timeIntervalSince(runStart)
    return min(1, max(0, (banked + running) / chapters[current].duration))
  }

  /// Sleeps out the rest of the current chapter, then moves on. Restarted by
  /// `.task(id:)` on every chapter change and every hold or release.
  private func runClock() async {
    guard !isHolding, !finished else { return }
    let remaining = max(0, chapters[current].duration - banked)
    try? await Task.sleep(for: .seconds(remaining))
    guard !Task.isCancelled else { return }
    if isLast {
      finished = true
    } else {
      go(to: current + 1)
    }
  }

  private func go(to index: Int) {
    guard chapters.indices.contains(index), index != current else { return }
    let token = UUID()
    outgoing = ChaptersOutgoing(index: current, token: token)
    current = index
    banked = 0
    runStart = .now
    finished = false
    Task {
      try? await Task.sleep(for: .seconds(0.9))
      if outgoing?.token == token { outgoing = nil }
    }
  }

  private func beginHold() {
    guard !isHolding else { return }
    if !finished { banked += Date.now.timeIntervalSince(runStart) }
    isHolding = true
  }

  private func endHold() {
    runStart = .now
    isHolding = false
  }

  // MARK: Gesture

  /// One gesture for tap and hold: a touch held past 0.3s pauses until it
  /// lifts; a short, still touch is a tap whose side picks the direction.
  private func pressGesture(width: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .local)
      .onChanged { _ in
        guard !isPressing else { return }
        isPressing = true
        holdTask = Task {
          try? await Task.sleep(for: .seconds(0.3))
          guard !Task.isCancelled, isPressing else { return }
          beginHold()
        }
      }
      .onEnded { value in
        isPressing = false
        holdTask?.cancel()
        holdTask = nil
        if isHolding {
          endHold()
          return
        }
        guard abs(value.translation.width) < 24, abs(value.translation.height) < 24 else { return }
        if value.location.x < width / 3 {
          go(to: current - 1)
        } else if !isLast {
          go(to: current + 1)
        }
      }
  }
}

// MARK: - Model

private enum ChaptersChapter: Hashable {
  case seed, growth, time, hearts, joined, note, keepsake

  var tone: ChaptersTone {
    switch self {
    case .seed, .growth: .garden
    case .time: .time
    case .hearts: .hearts
    case .joined: .challenges
    case .note: .note
    case .keepsake: .keepsake
    }
  }

  /// How long the chapter holds before the strip moves on. The note is read,
  /// not glanced at, so it stays a little longer.
  var duration: TimeInterval {
    switch self {
    case .note: 9
    case .growth: 7.5
    default: 7
    }
  }
}

private struct ChaptersOutgoing: Equatable {
  let index: Int
  let token: UUID
}

private struct ChaptersClockKey: Hashable {
  let current: Int
  let isHolding: Bool
}

// MARK: - Backdrop

/// Each chapter's colour of air, washed over the atmosphere.
private enum ChaptersTone: CaseIterable {
  case garden, time, hearts, challenges, note, keepsake

  /// The bloom behind the chapter's figure.
  var glow: Color {
    switch self {
    case .garden: GardenColor.meadow
    case .time: .skyWash
    case .hearts: .blushPowder
    case .challenges: Color.peachCloud.mix(with: GardenColor.sunbeam, by: 0.18)
    case .note: .softLilac
    case .keepsake: .moonCream
    }
  }

  /// The wash rising from the bottom of the screen.
  var floor: Color {
    switch self {
    case .garden: GardenColor.sage
    case .time: .lavenderMist
    case .hearts: .peachCloud
    case .challenges: .peachCloud
    case .note: .lavenderMist
    case .keepsake: .softLilac
    }
  }
}

/// The atmosphere plus every chapter wash stacked; only the current one is
/// visible, so a chapter change is a pure crossfade (no blur ever animates).
private struct ChaptersBackdrop: View {
  let tone: ChaptersTone

  var body: some View {
    ZStack {
      AtmosphereBackground()
      ZStack {
        ForEach(ChaptersTone.allCases, id: \.self) { candidate in
          ChaptersWash(tone: candidate)
            .opacity(candidate == tone ? 1 : 0)
        }
      }
      .animation(.hush, value: tone)
    }
  }
}

private struct ChaptersWash: View {
  let tone: ChaptersTone

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [tone.floor.opacity(0), tone.floor.opacity(0.32)],
        startPoint: .center,
        endPoint: .bottom
      )
      RadialGradient(
        colors: [tone.glow.opacity(0.55), tone.glow.opacity(0)],
        center: UnitPoint(x: 0.5, y: 0.36),
        startRadius: 0,
        endRadius: 380
      )
    }
    .ignoresSafeArea()
  }
}

// MARK: - Progress strip

private struct ChaptersSegment: View {
  let fill: Double

  var body: some View {
    Capsule()
      .fill(.white.opacity(0.55))
      .overlay {
        Rectangle()
          .fill(Color.deepPlum.opacity(0.5))
          .scaleEffect(x: fill, y: 1, anchor: .leading)
      }
      .clipShape(Capsule())
      .frame(height: 3)
  }
}

// MARK: - Motion scaffolding

/// Blooms a chapter in (0.94 → 1 with opacity) and hands its lines a `shown`
/// flag to stagger on. A settled page starts already shown, with no motion.
private struct ChaptersPage<Content: View>: View {
  @ViewBuilder let content: (Bool) -> Content
  @State private var shown: Bool

  init(settled: Bool, @ViewBuilder content: @escaping (Bool) -> Content) {
    self.content = content
    _shown = State(initialValue: settled)
  }

  var body: some View {
    content(shown)
      .scaleEffect(shown ? 1 : 0.94)
      .opacity(shown ? 1 : 0)
      .onAppear {
        guard !shown else { return }
        withAnimation(.bloom) { shown = true }
      }
  }
}

/// The exit: fades and drifts up 16pt, then the root unmounts it.
private struct ChaptersLeaving<Content: View>: View {
  @ViewBuilder let content: () -> Content
  @State var gone = false

  var body: some View {
    content()
      .opacity(gone ? 0 : 1)
      .offset(y: gone ? -16 : 0)
      .onAppear { withAnimation(.exhale) { gone = true } }
  }
}

private extension View {
  /// One line of a chapter arriving ~0.15s after the one before it.
  func chaptersLine(_ order: Int, _ shown: Bool) -> some View {
    self
      .opacity(shown ? 1 : 0)
      .offset(y: shown ? 0 : 10)
      .animation(.bloom.delay(0.15 * Double(order)), value: shown)
  }
}

// MARK: - Shared pieces

/// Story headlines sit above the app's card scale: a recap chapter has the
/// whole screen to itself. Still anchored to a Dynamic Type style.
private enum ChaptersType {
  static let headline = Font.system(.title, design: .serif, weight: .light)
}

private struct ChaptersEyebrow: View {
  let text: String

  var body: some View {
    Text(text)
      .font(DeepType.micro)
      .tracking(.microTracking)
      .foregroundStyle(.driftGrey)
  }
}

private struct ChaptersHeadline: View {
  let text: String

  var body: some View {
    Text(text)
      .font(ChaptersType.headline)
      .foregroundStyle(.deepPlum)
      .fixedSize(horizontal: false, vertical: true)
  }
}

/// The oak's forms over a soft glow. The art ships on white squares, so it is
/// multiplied over the glow inside its own compositing group (the white takes
/// the glow's colour) and its corners are feathered away; the glow stays
/// opaque wherever art is drawn, so the white never shows through a fade.
/// Forms crossfade when `stage` changes.
private struct ChaptersOakArt: View {
  let stage: Int
  var size: CGFloat = 220
  var tint: Color = GardenColor.meadow

  var body: some View {
    let seat = Color.moonCream.mix(with: tint, by: 0.3)
    ZStack {
      Circle()
        .fill(
          RadialGradient(
            stops: [
              .init(color: seat, location: 0),
              .init(color: seat, location: 0.8),
              .init(color: seat.opacity(0), location: 1),
            ],
            center: .center,
            startRadius: 0,
            endRadius: size * 0.75
          )
        )
        .frame(width: size * 1.5, height: size * 1.5)

      ForEach(0..<3, id: \.self) { index in
        PassportArt.oak(stage: index)
          .resizable()
          .scaledToFit()
          .frame(width: size, height: size)
          .mask(
            RadialGradient(
              stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: 0.78),
                .init(color: .white.opacity(0), location: 1),
              ],
              center: .center,
              startRadius: 0,
              endRadius: size * 0.6
            )
          )
          .blendMode(.multiply)
          .opacity(index == stage ? 1 : 0)
      }
    }
    .compositingGroup()
    .frame(width: size * 1.5, height: size * 1.5)
    .accessibilityHidden(true)
  }
}

private extension Date {
  /// "12 April 2026", the order the copy is written in.
  var chaptersLong: String {
    formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "en_GB")))
  }

  var chaptersMonthYear: String {
    formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "en_GB")))
  }
}

/// "three" for small counts, digits beyond ten.
private func chaptersSpelled(_ value: Int) -> String {
  guard value <= 10 else { return value.formatted() }
  let formatter = NumberFormatter()
  formatter.numberStyle = .spellOut
  formatter.locale = Locale(identifier: "en_GB")
  return formatter.string(from: value as NSNumber) ?? value.formatted()
}

private func chaptersCount(_ value: Int, _ singular: String, _ plural: String) -> String {
  value == 1 ? singular : plural
}

// MARK: - 1. Your seed

private struct ChaptersSeedChapter: View {
  let sample: PassportSample
  let shown: Bool
  let settled: Bool

  @State var drifting = false

  private var daysGrowing: Int {
    Calendar(identifier: .gregorian).dateComponents([.day], from: sample.memberSince, to: sample.issuedOn).day ?? 0
  }

  private var traits: String {
    let words = sample.plantTraits.map { $0.lowercased() }
    guard words.count > 1 else { return words.first ?? "" }
    return words.dropLast().joined(separator: ", ") + " and " + (words.last ?? "")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Spacer(minLength: 0)

      ChaptersOakArt(stage: 0, size: 200)
        .scaleEffect(drifting ? 1.04 : 1)
        .offset(y: drifting ? -8 : 0)
        .frame(maxWidth: .infinity)
        .chaptersLine(0, shown)

      ChaptersEyebrow(text: "YOUR SEED")
        .padding(.top, 8)
        .chaptersLine(1, shown)
      ChaptersHeadline(text: "It began on \(sample.memberSince.chaptersLong).")
        .padding(.top, 10)
        .chaptersLine(2, shown)
      Text("You planted an \(sample.plantName.lowercased()), a tree that grows \(traits).")
        .font(DeepType.body)
        .foregroundStyle(.deepPlum)
        .padding(.top, 12)
        .chaptersLine(3, shown)
      Text("\(chaptersSpelled(daysGrowing).capitalizedFirst) days of growing so far.")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .padding(.top, 6)
        .chaptersLine(4, shown)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, .edge + 8)
    .onAppear {
      guard !settled else { return }
      withAnimation(.drift) { drifting = true }
    }
  }
}

private extension String {
  var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

// MARK: - 2. How you grew

private struct ChaptersGrowthChapter: View {
  let sample: PassportSample
  let shown: Bool
  let settled: Bool

  @State private var form: Int

  init(sample: PassportSample, shown: Bool, settled: Bool) {
    self.sample = sample
    self.shown = shown
    self.settled = settled
    _form = State(initialValue: settled ? sample.currentStageIndex : 0)
  }

  private var reached: [PassportStage] { sample.stages.filter(\.isReached) }
  private var next: PassportStage? { sample.stages.first { !$0.isReached } }
  private var isFirstForm: Bool { reached.count == 1 }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Spacer(minLength: 0)

      VStack(spacing: 4) {
        ChaptersOakArt(stage: form, size: 210)
          .animation(.hush, value: form)

        // Each form's name and date, crossfading with its art.
        ZStack {
          ForEach(reached) { stage in
            VStack(spacing: 2) {
              Text(stage.name)
                .font(DeepType.sectionTitle)
                .foregroundStyle(.deepPlum)
              if let date = stage.reachedOn {
                Text(stage.index == 0 ? "Planted \(date.chaptersLong)" : "Reached \(date.chaptersLong)")
                  .font(DeepType.caption)
                  .foregroundStyle(.driftGrey)
              }
            }
            .opacity(stage.index == form ? 1 : 0)
          }
        }
        .animation(.hush, value: form)
      }
      .frame(maxWidth: .infinity)
      .chaptersLine(0, shown)

      ChaptersEyebrow(text: "HOW YOU GREW")
        .padding(.top, 28)
        .chaptersLine(1, shown)

      if isFirstForm {
        ChaptersHeadline(text: "Your \(sample.plantName.lowercased()) is still a seedling. Roots come first.")
          .padding(.top, 10)
          .chaptersLine(2, shown)
      } else {
        ChaptersHeadline(text: "From a seedling to a \(sample.currentStage.name).")
          .padding(.top, 10)
          .chaptersLine(2, shown)
      }

      Group {
        if let next {
          Text("Next, the \(next.name).")
        } else {
          Text("Fully grown, and still deepening its roots.")
        }
      }
      .font(DeepType.body)
      .foregroundStyle(.driftGrey)
      .padding(.top, 12)
      .chaptersLine(3, shown)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, .edge + 8)
    .task {
      guard !settled, reached.count > 1 else { return }
      for index in reached.indices.dropFirst() {
        try? await Task.sleep(for: .seconds(index == 1 ? 1.6 : 1.2))
        guard !Task.isCancelled else { return }
        form = reached[index].index
      }
    }
  }
}

// MARK: - 3. Time you gave yourself

private struct ChaptersTimeChapter: View {
  let sample: PassportSample
  let shown: Bool
  let settled: Bool

  @State private var counted: Int

  init(sample: PassportSample, shown: Bool, settled: Bool) {
    self.sample = sample
    self.shown = shown
    self.settled = settled
    _counted = State(initialValue: settled ? sample.minutes : 0)
  }

  /// The minutes, said the way a person would.
  private var human: String {
    let minutes = sample.minutes
    let hours = minutes / 60
    switch minutes {
    case 120...:
      return minutes % 60 == 0
        ? "\(hours) hours, given back to you."
        : "More than \(hours) hours, given back to you."
    case 60..<120: return "More than an hour, given back to you."
    case 30..<60: return "Your first quiet hour is nearly here."
    default: return "A quiet start, all your own."
    }
  }

  private var facts: [(value: Int, label: String)] {
    [
      (sample.sessions, chaptersCount(sample.sessions, "DEEP Session", "DEEP Sessions")),
      (sample.practiceDays, chaptersCount(sample.practiceDays, "day of practice", "days of practice")),
      (sample.pausesAttended, chaptersCount(sample.pausesAttended, "Global Pause", "Global Pauses")),
    ]
    .filter { $0.value > 0 }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Spacer(minLength: 0)

      ChaptersEyebrow(text: "TIME YOU GAVE YOURSELF")
        .chaptersLine(0, shown)

      VStack(alignment: .leading, spacing: 0) {
        Text(counted.formatted())
          .font(DeepType.heroNumber)
          .foregroundStyle(.deepPlum)
          .monospacedDigit()
          .contentTransition(.numericText(value: Double(counted)))
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Text("minutes")
          .font(DeepType.sectionTitle)
          .foregroundStyle(.driftGrey)
      }
      .padding(.top, 6)
      .chaptersLine(1, shown)

      ChaptersHeadline(text: human)
        .padding(.top, 18)
        .chaptersLine(2, shown)

      VStack(alignment: .leading, spacing: 10) {
        ForEach(Array(facts.enumerated()), id: \.offset) { offset, fact in
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(fact.value.formatted())
              .font(DeepType.counter)
              .foregroundStyle(.deepPlum)
              .monospacedDigit()
            Text(fact.label)
              .font(DeepType.body)
              .foregroundStyle(.driftGrey)
          }
          .chaptersLine(3 + offset, shown)
        }
      }
      .padding(.top, 26)

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, .edge + 8)
    .task {
      guard !settled else { return }
      try? await Task.sleep(for: .seconds(0.35))
      let steps = 34
      for step in 1...steps {
        guard !Task.isCancelled else { return }
        let t = Double(step) / Double(steps)
        let eased = 1 - pow(1 - t, 3)
        withAnimation(.linear(duration: 0.06)) {
          counted = Int((Double(sample.minutes) * eased).rounded())
        }
        try? await Task.sleep(for: .milliseconds(48))
      }
    }
  }
}

// MARK: - 4. Hearts you sent

private struct ChaptersHeartsChapter: View {
  let sample: PassportSample
  let shown: Bool
  let settled: Bool

  @State private var drawn: Double

  init(sample: PassportSample, shown: Bool, settled: Bool) {
    self.sample = sample
    self.shown = shown
    self.settled = settled
    _drawn = State(initialValue: settled ? 1 : 0)
  }

  private var headline: String {
    if sample.gifts.count == 1, let gift = sample.gifts.first {
      return "Your first hearts went to \(gift.category.name)."
    }
    return "Your hearts reached \(chaptersSpelled(sample.gifts.count)) causes."
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Spacer(minLength: 0)

      ZStack {
        CompassionRing(segments: sample.giftSegments, lineWidth: 14)
          .mask {
            Circle()
              .trim(from: 0, to: drawn)
              .stroke(.white, lineWidth: 60)
              .rotationEffect(.degrees(-90))
          }
        VStack(spacing: 2) {
          Text(sample.heartsGiven.formatted())
            .font(DeepType.bigNumber)
            .foregroundStyle(.deepPlum)
            .monospacedDigit()
          Text("HEARTS SENT")
            .font(DeepType.micro)
            .tracking(.microTracking)
            .foregroundStyle(.driftGrey)
        }
      }
      .frame(width: 172, height: 172)
      .frame(maxWidth: .infinity)
      .chaptersLine(0, shown)

      ChaptersEyebrow(text: "HEARTS YOU SENT")
        .padding(.top, 26)
        .chaptersLine(1, shown)
      ChaptersHeadline(text: headline)
        .padding(.top, 10)
        .chaptersLine(2, shown)

      VStack(alignment: .leading, spacing: 12) {
        ForEach(Array(sample.gifts.enumerated()), id: \.element.id) { offset, gift in
          HStack(spacing: 12) {
            Circle()
              .fill(LinearGradient(colors: gift.category.palette.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
              .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 1) {
              Text(gift.category.name)
                .font(DeepType.body.weight(.semibold))
                .foregroundStyle(.deepPlum)
              Text("with \(gift.category.partner.name)")
                .font(DeepType.caption)
                .foregroundStyle(.driftGrey)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(gift.hearts.formatted())
              .font(DeepType.body.weight(.semibold))
              .foregroundStyle(.deepPlum)
              .monospacedDigit()
          }
          .chaptersLine(3 + offset, shown)
        }
      }
      .padding(.top, 20)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, .edge + 8)
    .task {
      guard !settled else { return }
      try? await Task.sleep(for: .seconds(0.3))
      withAnimation(.breath(over: 1.8)) { drawn = 1 }
    }
  }
}

// MARK: - 5. What you joined

private struct ChaptersJoinedChapter: View {
  let sample: PassportSample
  let shown: Bool

  private var message: PassportPeaceMessage? { sample.peaceMessages.last }
  private var hasChallenges: Bool { !sample.challenges.isEmpty }

  private var headline: String {
    switch sample.challenges.count {
    case 0: "You wrote to the world."
    case 1: "You joined your first challenge."
    default: "You joined \(chaptersSpelled(sample.challenges.count)) challenges and events."
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Spacer(minLength: 0)

      ChaptersEyebrow(text: "WHAT YOU JOINED")
        .chaptersLine(0, shown)
      ChaptersHeadline(text: headline)
        .padding(.top, 10)
        .chaptersLine(1, shown)

      if hasChallenges {
        LazyVGrid(
          columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
          alignment: .leading,
          spacing: 10
        ) {
          ForEach(Array(sample.challenges.enumerated()), id: \.element.id) { offset, challenge in
            ChaptersChallengeTile(challenge: challenge)
              .chaptersLine(2 + offset, shown)
          }
        }
        .padding(.top, 20)
      }

      if let message {
        VStack(alignment: .leading, spacing: 8) {
          if hasChallenges {
            ChaptersEyebrow(text: "YOU WROTE TO THE WORLD")
          }
          Text("\u{201C}\(message.text)\u{201D}")
            .font(DeepType.revealTitle)
            .foregroundStyle(.deepPlum)
            .fixedSize(horizontal: false, vertical: true)
          Text(message.writtenOn.chaptersLong)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
        }
        .padding(.top, hasChallenges ? 26 : 20)
        .chaptersLine(2 + sample.challenges.count, shown)
      }

      if !hasChallenges {
        Text("When you join a challenge or a world event, it will be kept here, beside your words.")
          .font(DeepType.body)
          .foregroundStyle(.driftGrey)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 22)
          .chaptersLine(3, shown)
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, .edge + 8)
  }
}

private struct ChaptersChallengeTile: View {
  let challenge: PassportChallenge

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: challenge.symbol)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(GardenColor.sunbeam)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(challenge.title)
          .font(DeepType.caption.weight(.semibold))
          .foregroundStyle(.deepPlum)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
        Text(challenge.completedOn.chaptersMonthYear)
          .font(DeepType.micro)
          .foregroundStyle(.driftGrey)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(12)
    .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
    .frostedCard(cornerRadius: .tile, tint: .peachCloud)
  }
}

// MARK: - 6. A note to you

private struct ChaptersNoteChapter: View {
  let sample: PassportSample
  let shown: Bool

  /// The note, one sentence per line, so it arrives the way it would be read.
  private var sentences: [String] {
    var result: [String] = []
    sample.note.enumerateSubstrings(in: sample.note.startIndex..., options: .bySentences) { sentence, _, _, _ in
      if let sentence { result.append(sentence.trimmingCharacters(in: .whitespaces)) }
    }
    return result
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Spacer(minLength: 0)

      ChaptersEyebrow(text: "A NOTE TO YOU")
        .chaptersLine(0, shown)

      VStack(alignment: .leading, spacing: 10) {
        ForEach(Array(sentences.enumerated()), id: \.offset) { offset, sentence in
          Text(sentence)
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .chaptersLine(1 + offset, shown)
        }
      }
      .padding(.top, 14)

      ChaptersEyebrow(text: "STRENGTHS WE SEE IN YOU")
        .padding(.top, 30)
        .chaptersLine(1 + sentences.count, shown)

      ChaptersFlowLayout(spacing: 8) {
        ForEach(Array(sample.strengths.enumerated()), id: \.offset) { offset, strength in
          Text(strength)
            .font(DeepType.body.weight(.medium))
            .foregroundStyle(.deepPlum)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
              Color.softLilac.opacity(0.45),
              in: RoundedRectangle(cornerRadius: .tile, style: .continuous)
            )
            .chaptersLine(2 + sentences.count + offset, shown)
        }
      }
      .padding(.top, 12)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, .edge + 8)
  }
}

/// Wraps chips onto as many rows as they need, left-aligned.
private struct ChaptersFlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
    let height = rows.last.map { $0.y + $0.height } ?? 0
    let width = rows.map(\.width).max() ?? 0
    return CGSize(width: width, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let rows = arrange(width: bounds.width, subviews: subviews)
    for row in rows {
      var x = bounds.minX
      for index in row.indices {
        let size = subviews[index].sizeThatFits(.unspecified)
        subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
        x += size.width + spacing
      }
    }
  }

  private struct Row {
    var indices: [Int] = []
    var y: CGFloat = 0
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
    var rows: [Row] = [Row()]
    for index in subviews.indices {
      let size = subviews[index].sizeThatFits(.unspecified)
      var row = rows[rows.count - 1]
      if !row.indices.isEmpty, row.width + spacing + size.width > width {
        let y = row.y + row.height + spacing
        rows.append(Row(y: y))
        row = rows[rows.count - 1]
      }
      row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
      row.height = max(row.height, size.height)
      row.indices.append(index)
      rows[rows.count - 1] = row
    }
    return rows
  }
}

// MARK: - 7. Keepsake

private struct ChaptersKeepsakeChapter: View {
  let sample: PassportSample
  let shown: Bool
  let settled: Bool

  @Environment(\.exportPassport) var exportPassport
  @State var shareImage: Image?

  var body: some View {
    VStack(spacing: 18) {
      GeometryReader { proxy in
        let size = ChaptersKeepsakeCard.size
        let scale = min(proxy.size.height / size.height, proxy.size.width / size.width)
        ChaptersKeepsakeCard(sample: sample)
          .scaleEffect(scale)
          .frame(width: size.width * scale, height: size.height * scale)
          .shadow(color: Color.lavenderMist.opacity(0.4), radius: 28, x: 0, y: 16)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .allowsHitTesting(false)
      .chaptersLine(0, shown)

      HStack(spacing: 12) {
        shareButton
        RewardContinueButton(title: "Print passport") { exportPassport() }
      }
      .chaptersLine(2, shown)
    }
    .padding(.horizontal, .edge)
    .padding(.top, 14)
    .task {
      guard !settled, shareImage == nil else { return }
      let renderer = ImageRenderer(
        content: ChaptersKeepsakeCard(sample: sample).environment(\.colorScheme, .light)
      )
      renderer.scale = 3
      if let image = renderer.uiImage { shareImage = Image(uiImage: image) }
    }
  }

  @ViewBuilder
  private var shareButton: some View {
    if let shareImage {
      ShareLink(
        item: shareImage,
        preview: SharePreview("My DEEP Growth Passport", image: shareImage)
      ) {
        shareLabel
      }
      .buttonStyle(.softPress)
    } else {
      shareLabel.opacity(0.6)
    }
  }

  private var shareLabel: some View {
    Label("Share card", systemImage: "square.and.arrow.up")
      .font(DeepType.body.weight(.semibold))
      .foregroundStyle(.deepPlum)
      .frame(maxWidth: .infinity)
      .frame(minHeight: 56)
      .frostedCard(cornerRadius: .chip)
  }
}

/// The 9:16 keepsake, drawn once at a fixed size: the screen scales it to fit
/// and `ImageRenderer` paints the very same view at 3x for sharing. No
/// materials, so the render matches what is on screen.
private struct ChaptersKeepsakeCard: View {
  let sample: PassportSample

  static let size = CGSize(width: 270, height: 480)

  private var figures: [(value: String, label: String)] {
    [
      (sample.minutes.formatted(), "minutes of practice"),
      (sample.sessions.formatted(), chaptersCount(sample.sessions, "DEEP Session", "DEEP Sessions")),
      (sample.heartsGiven.formatted(), "hearts sent"),
    ]
    .filter { $0.value != "0" }
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: .card, style: .continuous)
    VStack(spacing: 0) {
      Text("deep")
        .font(DeepType.wordmark)
        .foregroundStyle(.irisDusk)
      Text("GROWTH PASSPORT")
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.driftGrey)
        .padding(.top, 2)

      Spacer(minLength: 4)

      ChaptersOakArt(stage: sample.currentStageIndex, size: 132, tint: .softLilac)
        .frame(height: 150)

      Spacer(minLength: 4)

      Text(sample.memberName)
        .font(DeepType.displayTitle)
        .foregroundStyle(.deepPlum)
      Text(sample.currentStage.name)
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .padding(.top, 2)

      HStack(alignment: .top, spacing: 6) {
        ForEach(Array(figures.enumerated()), id: \.offset) { _, figure in
          VStack(spacing: 2) {
            Text(figure.value)
              .font(DeepType.sectionTitle.weight(.semibold))
              .foregroundStyle(.deepPlum)
              .monospacedDigit()
            Text(figure.label)
              .font(DeepType.caption)
              .foregroundStyle(.driftGrey)
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .padding(.vertical, 10)
          .padding(.horizontal, 4)
          .background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
      }
      .fixedSize(horizontal: false, vertical: true)
      .padding(.top, 16)

      Text("Growing with DEEP since \(sample.memberSince.chaptersMonthYear)")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .multilineTextAlignment(.center)
        .padding(.top, 14)
    }
    .padding(.top, 24)
    .padding(.bottom, 20)
    .padding(.horizontal, 16)
    .frame(width: Self.size.width, height: Self.size.height)
    .background {
      ZStack {
        LinearGradient(
          colors: [.moonCream, Color.softLilac.opacity(0.45), GardenColor.meadow.opacity(0.6)],
          startPoint: .top,
          endPoint: .bottom
        )
        .background(.moonCream)
        RadialGradient(
          colors: [Color.blushPowder.opacity(0.45), .clear],
          center: UnitPoint(x: 0.5, y: 0.1),
          startRadius: 0,
          endRadius: 220
        )
      }
    }
    .clipShape(shape)
    .overlay(shape.strokeBorder(.white.opacity(0.6), lineWidth: 0.5))
  }
}

// MARK: - Previews

#Preview("Chapters, first week") {
  ChaptersPrototypeView(sample: .firstWeek)
    .environment(\.exportPassport, {})
}

#Preview("Chapters, six months") {
  ChaptersPrototypeView(sample: .sixMonths)
    .environment(\.exportPassport, {})
}

#Preview("Chapters, two years") {
  ChaptersPrototypeView(sample: .twoYears)
    .environment(\.exportPassport, {})
}

#Preview("Keepsake card") {
  ZStack {
    AtmosphereBackground()
    ChaptersKeepsakeCard(sample: .sixMonths)
  }
}
#endif
