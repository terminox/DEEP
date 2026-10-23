#if DEBUG
import SwiftUI
import UIKit

// PROTOTYPE — throwaway.
// Variant A, "The Passport": a literal booklet. A soft leather cover that tilts
// under the finger and swings open on its hinge, then cream pages turned by
// dragging, each one inked with stamps the first time it is seen.

/// The booklet, closed cover to last page. The whole book is laid out once at
/// its open size and scaled down while closed, so page text never re-wraps
/// while the cover swings and the book grows.
struct PassportBookPrototypeView: View {
  let sample: PassportSample

  @State private var isOpen = false
  /// The page the book is settling on.
  @State private var index = 0
  /// Fractional page position, scrubbed by drag and animated on release:
  /// 1.4 means page 1 is 40% turned.
  @State private var position: Double = 0
  /// Pages already seen. A page inks its stamps once, on its first visit.
  @State private var visited: Set<Int> = []
  /// Drag-driven tilt of the closed book, in degrees (the simulator has no
  /// gyroscope).
  @State private var tilt: CGSize = .zero
  /// True while a finger is on the page. A drag the system cancels never
  /// reaches `onEnded`, so its release is caught here and the leaf settles.
  @GestureState private var isDraggingPage = false

  private let pages = BookPage.allCases
  private var lastIndex: Int { pages.count - 1 }

  /// The closed booklet's width on screen.
  private static let closedWidth: CGFloat = 300
  /// A real passport page is 88 × 125 mm.
  private static let aspect: CGFloat = 1.42
  /// The prototype switcher floats over the bottom of the screen.
  private static let switcherReserve: CGFloat = 104
  private static let barHeight: CGFloat = 36
  private static let footerHeight: CGFloat = 28
  private static let stackSpacing: CGFloat = 14

  var body: some View {
    ZStack {
      AtmosphereBackground()
      GeometryReader { proxy in
        let open = Self.openSize(in: proxy.size)
        let closedScale = min(1, Self.closedWidth / max(open.width, 1))
        // While closed the book is scaled about its centre: pull the bar and
        // the hint in by the same amount so they hug the cover.
        let inset = open.height * (1 - closedScale) / 2
        VStack(spacing: Self.stackSpacing) {
          topBar
            .offset(y: isOpen ? 0 : inset)
          book(size: open)
            .scaleEffect(isOpen ? 1 : closedScale)
          footer
            .offset(y: isOpen ? 0 : -inset)
        }
        .frame(width: proxy.size.width, height: proxy.size.height)
      }
      .padding(.bottom, Self.switcherReserve)
    }
    .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: isOpen)
    .sensoryFeedback(.selection, trigger: index)
  }

  /// The open book: near full width, capped by the height left over.
  private static func openSize(in space: CGSize) -> CGSize {
    var width = min(space.width - 32, 390)
    var height = width * aspect
    let room = space.height - barHeight - footerHeight - stackSpacing * 2
    if height > room {
      height = room
      width = height / aspect
    }
    return CGSize(width: max(width, 1), height: max(height, 1))
  }

  // MARK: Book

  private func book(size: CGSize) -> some View {
    ZStack {
      // The page block's thickness, peeking past the top leaf, and the soft
      // lavender shadow the whole object rests on.
      BookShape.page
        .fill(Color.moonCream.mix(with: .peachCloud, by: 0.35))
        .offset(x: 5, y: 4)
        .shadow(color: Color.lavenderMist.opacity(0.55), radius: 30, x: 0, y: 20)
      BookShape.page
        .fill(Color.moonCream.mix(with: .peachCloud, by: 0.18))
        .offset(x: 2.5, y: 2)

      ZStack {
        // Lower pages first so page 0 sits on top.
        ForEach(pages.reversed()) { page in
          BookLeaf(index: page.rawValue, position: position) {
            pageContent(page)
          }
          .allowsHitTesting(page.rawValue == index)
        }
      }
      .contentShape(Rectangle())
      .gesture(pageDrag(width: size.width))
      .onChange(of: isDraggingPage) { _, dragging in
        guard !dragging else { return }
        // `onEnded` already settled a normal release (it sets `position`
        // to a whole page at once); only a cancelled drag is left mid-turn.
        DispatchQueue.main.async {
          if position != Double(index) {
            turn(to: min(max(Int(position.rounded()), 0), lastIndex))
          }
        }
      }
      .onTapGesture { location in marginTap(at: location, width: size.width) }
      .allowsHitTesting(isOpen)

      BookCover(sample: sample, angle: isOpen ? -180 : 0, tilt: tilt)
        .contentShape(BookShape.cover)
        .onTapGesture(perform: open)
        .simultaneousGesture(coverTilt)
        .allowsHitTesting(!isOpen)
    }
    .frame(width: size.width, height: size.height)
    .rotation3DEffect(.degrees(tilt.width), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
    .rotation3DEffect(.degrees(-tilt.height), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
  }

  @ViewBuilder
  private func pageContent(_ page: BookPage) -> some View {
    let stamped = visited.contains(page.rawValue)
    switch page {
    case .identity: BookIdentityPage(sample: sample, isStamped: stamped)
    case .garden: BookGardenPage(sample: sample, isStamped: stamped)
    case .compassion: BookCompassionPage(sample: sample, isStamped: stamped)
    case .journeys: BookJourneysPage(sample: sample, isStamped: stamped)
    case .closing: BookClosingPage(sample: sample, isStamped: stamped)
    }
  }

  // MARK: Chrome

  private var topBar: some View {
    Button(action: close) {
      Label("Close", systemImage: "book.closed")
        .font(DeepType.caption.weight(.medium))
        .foregroundStyle(.driftGrey)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.white.opacity(0.38), in: Capsule())
    }
    .buttonStyle(.softPress)
    .frame(maxWidth: .infinity, alignment: .trailing)
    .padding(.horizontal, .edge)
    .frame(height: Self.barHeight)
    .opacity(isOpen ? 1 : 0)
    .allowsHitTesting(isOpen)
  }

  private var footer: some View {
    ZStack {
      Text("Tap to open")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .opacity(isOpen ? 0 : 1)

      HStack(spacing: 14) {
        pageArrow("chevron.left", enabled: index > 0) { turn(to: index - 1) }
        Text("\(index + 1) OF \(pages.count)")
          .font(DeepType.micro.monospacedDigit())
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)
          .contentTransition(.numericText())
        pageArrow("chevron.right", enabled: index < lastIndex) { turn(to: index + 1) }
      }
      .opacity(isOpen ? 1 : 0)
      .allowsHitTesting(isOpen)
    }
    .frame(height: Self.footerHeight)
  }

  private func pageArrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(DeepType.caption.weight(.semibold))
        .foregroundStyle(.driftGrey)
        .frame(width: 40, height: Self.footerHeight)
        .contentShape(Rectangle())
    }
    .buttonStyle(.softPress)
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.3)
  }

  // MARK: Gestures

  /// The closed book leans after the finger and settles back on release.
  private var coverTilt: some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        tilt = CGSize(
          width: min(max(value.translation.width / 14, -9), 9),
          height: min(max(value.translation.height / 18, -7), 7)
        )
      }
      .onEnded { value in
        withAnimation(.settle) { tilt = .zero }
        // A touch that barely moved is a tap: open from here too, so the
        // open never loses a race with the tilt for the same touch.
        if hypot(value.translation.width, value.translation.height) < 8 { open() }
      }
  }

  /// Scrubs the top leaf around the spine; dragging right brings the last
  /// leaf back. Past 40% (or a decent fling) the turn completes.
  private func pageDrag(width: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 10)
      .updating($isDraggingPage) { _, state, _ in state = true }
      .onChanged { value in
        let raw = Double(index) - Double(value.translation.width / width)
        let low = Double(max(index - 1, 0))
        let high = Double(min(index + 1, lastIndex))
        position = min(max(raw, low), high)
      }
      .onEnded { value in
        let travel = position - Double(index)
        let fling = -Double(value.predictedEndTranslation.width / width)
        var target = index
        if travel > 0.4 || (fling > 0.7 && travel > 0.05) {
          target = index + 1
        } else if travel < -0.4 || (fling < -0.7 && travel < -0.05) {
          target = index - 1
        }
        turn(to: min(max(target, 0), lastIndex))
      }
  }

  private func marginTap(at location: CGPoint, width: CGFloat) {
    if location.x > width * 0.7, index < lastIndex {
      turn(to: index + 1)
    } else if location.x < width * 0.3, index > 0 {
      turn(to: index - 1)
    }
  }

  // MARK: Motion

  private func open() {
    guard !isOpen else { return }
    withAnimation(.breath(over: 0.95)) {
      isOpen = true
    } completion: {
      visited.insert(0)
    }
  }

  private func close() {
    withAnimation(.breath(over: 0.95)) {
      isOpen = false
    } completion: {
      // Back to the first page, out of sight under the cover.
      var reset = Transaction()
      reset.disablesAnimations = true
      withTransaction(reset) {
        index = 0
        position = 0
      }
    }
  }

  private func turn(to target: Int) {
    withAnimation(.exhale) {
      index = target
      position = Double(target)
    } completion: {
      visited.insert(target)
    }
  }
}

// MARK: - Pages

private enum BookPage: Int, CaseIterable, Identifiable {
  case identity, garden, compassion, journeys, closing

  var id: Int { rawValue }
}

/// One leaf of cream paper hinged at its leading edge. Reads the book's
/// fractional `position` frame by frame: its own share of the turn rotates it,
/// and the leaf above lifting away thins the shadow lying on it.
private struct BookLeaf<Content: View>: View, Animatable {
  let index: Int
  var position: Double
  @ViewBuilder let content: Content

  var animatableData: Double {
    get { position }
    set { position = newValue }
  }

  var body: some View {
    let turned = min(max(position - Double(index), 0), 1)
    let uncovered = min(max(position - Double(index - 1), 0), 1)
    let lift = sin(turned * .pi)
    content
      .padding(.top, 26)
      .padding(.leading, 30)
      .padding(.trailing, 22)
      .padding(.bottom, 22)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background { BookPaper() }
      .overlay {
        // The shadow of the leaf above, fading as it lifts away.
        Color.deepPlum.opacity(index > 0 ? (1 - uncovered) * 0.16 : 0)
      }
      .overlay {
        // Light falls off toward the free edge as this leaf curls.
        LinearGradient(
          colors: [Color.deepPlum.opacity(0), Color.deepPlum.opacity(0.16 * lift)],
          startPoint: .leading,
          endPoint: .trailing
        )
      }
      .clipShape(BookShape.page)
      // Edge-on at the halfway point; past it the leaf would show its back.
      .opacity(turned < 0.5 ? 1 : 0)
      .shadow(color: Color.deepPlum.opacity(0.18 * lift), radius: lift > 0.01 ? 16 : 0, x: -6 * lift, y: 4)
      .rotation3DEffect(.degrees(-180 * turned), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.45)
  }
}

/// Passport data page: who this belongs to, and the plant they grow.
private struct BookIdentityPage: View {
  let sample: PassportSample
  let isStamped: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .firstTextBaseline) {
        BookEyebrow(title: "GROWTH PASSPORT", symbol: "leaf.fill", tint: GardenColor.fern)
          .frame(maxWidth: .infinity, alignment: .leading)
        Text("deep")
          .font(DeepType.revealTitle)
          .foregroundStyle(.irisDusk)
      }

      HStack(alignment: .top, spacing: 14) {
        PassportStagePortrait(stageIndex: sample.currentStageIndex, diameter: 100, progress: sample.growthProgress)

        VStack(alignment: .leading, spacing: 10) {
          BookField(label: "PASSPORT NO.") {
            Text(sample.verificationCode)
              .font(DeepType.sectionTitle.monospaced())
              .foregroundStyle(.deepPlum)
          }
          BookField(label: "NAME") {
            Text(sample.memberName)
              .font(DeepType.displayTitle)
              .foregroundStyle(.deepPlum)
              .lineLimit(2)
              .minimumScaleFactor(0.8)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
        GridRow {
          BookTextField(label: "MEMBER SINCE", text: sample.memberSince.formatted(.dateTime.day().month(.abbreviated).year()))
          BookTextField(label: "PLANT", text: sample.plantName)
        }
        GridRow {
          BookTextField(label: "CURRENT FORM", text: sample.currentStage.name)
          BookTextField(label: "ISSUED", text: sample.issuedOn.formatted(.dateTime.day().month(.abbreviated).year()))
        }
        GridRow {
          BookTextField(label: "CHARACTER", text: sample.plantTraits.joined(separator: ", "))
            .gridCellColumns(2)
        }
      }

      practice

      Spacer(minLength: 0)

      VStack(alignment: .leading, spacing: 2) {
        ForEach(machineZone, id: \.self) { line in
          Text(line)
            .font(DeepType.caption.monospaced())
            .tracking(1.4)
            .foregroundStyle(Color.driftGrey.opacity(0.6))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
      }
    }
    // The issue stamp lands in the open paper above the machine zone, clear
    // of the portrait and the fields.
    .overlay(alignment: .bottomTrailing) {
      BookStampPress(isStamped: isStamped, delay: 0.3, tilt: -12) {
        BookRoundStamp(
          top: "ISSUED BY DEEP",
          bottom: sample.issuedOn.formatted(.dateTime.year()),
          diameter: 86,
          ink: BookInk.issue,
          wear: 3
        ) {
          Text(sample.issuedOn.formatted(.dateTime.day().month(.abbreviated)).uppercased())
            .font(DeepType.micro.weight(.bold))
        }
      }
      .padding(.bottom, 44)
      .padding(.trailing, 6)
    }
  }

  /// Practice as plain figures; a zero is left out rather than printed.
  private var practice: some View {
    let facts: [(Int, String)] = [
      (sample.sessions, "DEEP Sessions"),
      (sample.minutes, "Minutes"),
      (sample.practiceDays, "Days of practice"),
    ].filter { $0.0 > 0 }
    return HStack(alignment: .top, spacing: 8) {
      ForEach(facts, id: \.1) { value, label in
        VStack(alignment: .leading, spacing: 2) {
          Text("\(value)")
            .font(DeepType.sectionTitle.weight(.semibold).monospacedDigit())
            .foregroundStyle(.deepPlum)
          Text(label)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(Color.softLilac.opacity(0.24), in: RoundedRectangle(cornerRadius: .tile, style: .continuous))
  }

  /// A machine-readable zone in the passport's own spirit — a playful detail,
  /// not an encoding anyone reads.
  private var machineZone: [String] {
    let names = sample.memberName.uppercased().split(separator: " ").map(String.init)
    let given = names.first ?? ""
    let family = names.dropFirst().joined(separator: "<")
    let code = sample.verificationCode.replacingOccurrences(of: "-", with: "")
    let stage = sample.currentStage.name.uppercased().replacingOccurrences(of: " ", with: "<")
    let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: sample.memberSince)
    let since = String(format: "%02d%02d%02d", (parts.year ?? 0) % 100, parts.month ?? 0, parts.day ?? 0)
    return [
      Self.pad("P<DEEP<\(family)<<\(given)"),
      Self.pad("\(code)<\(stage)<<\(since)"),
    ]
  }

  private static func pad(_ line: String) -> String {
    let width = 36
    if line.count >= width { return String(line.prefix(width)) }
    return line + String(repeating: "<", count: width - line.count)
  }
}

/// Mind Garden: one ink stamp per form of the oak reached, an open circle for
/// each form still ahead.
private struct BookGardenPage: View {
  let sample: PassportSample
  let isStamped: Bool

  private let diameter: CGFloat = 124

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      BookPageHeader(eyebrow: "MIND GARDEN", symbol: "leaf.fill", tint: GardenColor.fern, title: "Forms of your oak")

      VStack(spacing: -12) {
        ForEach(sample.stages) { stage in
          Group {
            if let reached = stage.reachedOn {
              BookStampPress(isStamped: isStamped, delay: 0.25 + Double(stage.index) * 0.2, tilt: BookJitter.angle(stage.index)) {
                BookRoundStamp(
                  top: stage.name.uppercased(),
                  bottom: "MIND GARDEN",
                  diameter: diameter,
                  ink: BookInk.garden,
                  wear: stage.index
                ) {
                  VStack(spacing: 1) {
                    Image(systemName: BookGlyph.stage(stage.index))
                      .font(DeepType.caption)
                    Text(reached.formatted(.dateTime.day().month(.abbreviated)).uppercased())
                      .font(DeepType.caption.weight(.bold).monospacedDigit())
                    Text(reached.formatted(.dateTime.year()))
                      .font(DeepType.micro.monospacedDigit())
                  }
                }
              }
            } else {
              BookEmptyRound(title: "Still growing", detail: stage.name, diameter: diameter)
                .rotationEffect(.degrees(BookJitter.angle(stage.index) / 2))
            }
          }
          .frame(maxWidth: .infinity, alignment: stage.index % 2 == 0 ? .leading : .trailing)
          .padding(.horizontal, 14)
        }
      }
      .frame(maxHeight: .infinity)

      sunlight
    }
  }

  /// One quiet line on the way to the next form.
  private var sunlight: some View {
    HStack(spacing: 8) {
      Image(systemName: "sun.max.fill")
        .foregroundStyle(GardenColor.sunbeam)
      Group {
        if let next = sample.nextThreshold, sample.currentStageIndex + 1 < sample.stages.count {
          Text("\(Text("\(sample.sunlight)/\(next)").fontWeight(.semibold).monospacedDigit()) sunlight to \(sample.stages[sample.currentStageIndex + 1].name)")
        } else {
          Text("Fully grown, with \(Text("\(sample.sunlight)").fontWeight(.semibold).monospacedDigit()) sunlight gathered")
        }
      }
      .foregroundStyle(.deepPlum)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .font(DeepType.caption)
  }
}

/// Compassion: a visa for each cause the member has sent hearts to.
private struct BookCompassionPage: View {
  let sample: PassportSample
  let isStamped: Bool

  private enum Slot {
    case gift(PassportCauseGift)
    case room
  }

  /// The causes given to, plus one open slot to keep the page even while
  /// causes remain unvisited.
  private var slots: [Slot] {
    var slots = sample.gifts.map(Slot.gift)
    if slots.count % 2 == 1, slots.count < CompassionLibrary.categories.count {
      slots.append(.room)
    }
    return slots
  }

  var body: some View {
    let slots = slots
    let rows = stride(from: 0, to: slots.count, by: 2).map { Array(slots[$0..<min($0 + 2, slots.count)]) }
    VStack(alignment: .leading, spacing: 14) {
      BookPageHeader(eyebrow: "COMPASSION", symbol: "heart.fill", tint: BookInk.heart, title: "Where your hearts went")

      HStack(spacing: 8) {
        Image(systemName: "heart.fill")
          .foregroundStyle(BookInk.heart)
        Text("\(Text("\(sample.heartsGiven)").fontWeight(.semibold).monospacedDigit()) hearts sent to \(sample.causesSupported) \(sample.causesSupported == 1 ? "cause" : "causes")")
          .foregroundStyle(.deepPlum)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .font(DeepType.caption)

      Grid(horizontalSpacing: 4, verticalSpacing: -6) {
        ForEach(rows.indices, id: \.self) { row in
          GridRow {
            ForEach(rows[row].indices, id: \.self) { column in
              cell(rows[row][column], order: row * 2 + column)
                .gridCellColumns(rows[row].count == 1 ? 2 : 1)
            }
          }
        }
      }
      .frame(maxWidth: .infinity)
      .frame(maxHeight: .infinity, alignment: .top)
      .padding(.top, 4)
    }
  }

  @ViewBuilder
  private func cell(_ slot: Slot, order: Int) -> some View {
    switch slot {
    case .gift(let gift):
      BookStampPress(isStamped: isStamped, delay: 0.25 + Double(order) * 0.2, tilt: BookJitter.angle(order + 1)) {
        BookVisaStamp(gift: gift, wear: order)
      }
      .offset(x: BookJitter.nudge(order), y: 0)
    case .room:
      BookEmptySlot(shape: AnyShape(RoundedRectangle(cornerRadius: 7, style: .continuous)), title: "Room for your next cause")
        .frame(width: 150, height: 102)
        .rotationEffect(.degrees(BookJitter.angle(order) / 2))
    }
  }
}

/// Journeys: the Global Pause and every challenge joined, each its own stamp.
private struct BookJourneysPage: View {
  let sample: PassportSample
  let isStamped: Bool

  private enum Slot {
    case pause(Int)
    case challenge(PassportChallenge, Int)
    case next
  }

  private var slots: [Slot] {
    var slots: [Slot] = []
    if sample.pausesAttended > 0 { slots.append(.pause(sample.pausesAttended)) }
    slots += sample.challenges.enumerated().map { Slot.challenge($0.element, $0.offset) }
    if sample.challenges.isEmpty {
      slots += [.next, .next]
    } else if slots.count % 2 == 1 {
      slots.append(.next)
    }
    return slots
  }

  var body: some View {
    let slots = slots
    let rows = stride(from: 0, to: slots.count, by: 2).map { Array(slots[$0..<min($0 + 2, slots.count)]) }
    VStack(alignment: .leading, spacing: 14) {
      BookPageHeader(eyebrow: "JOURNEYS", symbol: "sparkles", tint: GardenColor.sunbeam, title: "Pauses and challenges")

      Grid(horizontalSpacing: 6, verticalSpacing: 6) {
        ForEach(rows.indices, id: \.self) { row in
          GridRow {
            ForEach(rows[row].indices, id: \.self) { column in
              cell(rows[row][column], order: row * 2 + column)
                .frame(height: 116)
                .gridCellColumns(rows[row].count == 1 ? 2 : 1)
            }
          }
        }
      }
      .frame(maxWidth: .infinity)

      if sample.challenges.isEmpty {
        Text("Challenges you join are stamped here, one by one.")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Spacer(minLength: 0)
    }
  }

  @ViewBuilder
  private func cell(_ slot: Slot, order: Int) -> some View {
    switch slot {
    case .pause(let count):
      BookStampPress(isStamped: isStamped, delay: 0.25, tilt: BookJitter.angle(order + 3)) {
        BookRoundStamp(top: "PAUSED WITH THE WORLD", bottom: "GLOBAL PAUSE", diameter: 116, ink: BookInk.pause, wear: 2) {
          VStack(spacing: 0) {
            Image(systemName: "globe.asia.australia.fill")
              .font(DeepType.sectionTitle)
            Text("\(count)")
              .font(DeepType.sectionTitle.weight(.bold).monospacedDigit())
            Text(count == 1 ? "TIME" : "TIMES")
              .font(DeepType.micro)
          }
        }
      }
    case .challenge(let challenge, let number):
      BookStampPress(isStamped: isStamped, delay: 0.25 + Double(order) * 0.2, tilt: BookJitter.angle(order + 2)) {
        BookChallengeStamp(challenge: challenge, isHexagon: number % 2 == 1, wear: order)
      }
      .offset(x: BookJitter.nudge(order), y: 0)
    case .next:
      BookEmptySlot(shape: AnyShape(Ellipse()), title: "Your next stamp")
        .frame(width: 140, height: 96)
        .rotationEffect(.degrees(BookJitter.angle(order) / 2))
    }
  }
}

/// The last page: a note written back, the strengths it names, and the way out
/// to paper.
private struct BookClosingPage: View {
  let sample: PassportSample
  let isStamped: Bool

  @Environment(\.exportPassport) private var exportPassport

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      BookEyebrow(title: "A NOTE FOR YOU", symbol: "envelope.open.fill", tint: .irisDusk)

      Text(sample.note)
        .font(DeepType.revealTitle)
        .foregroundStyle(.deepPlum)
        .lineSpacing(4)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

      HStack(alignment: .bottom, spacing: 12) {
        VStack(alignment: .leading, spacing: 8) {
          Text("STRENGTHS")
            .font(DeepType.micro)
            .tracking(.microTracking)
            .foregroundStyle(.driftGrey)
          BookFlowLayout(spacing: 6) {
            ForEach(sample.strengths, id: \.self) { strength in
              Text(strength)
                .font(DeepType.caption.weight(.medium))
                .foregroundStyle(BookInk.garden)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(GardenColor.meadow.opacity(0.5), in: Capsule())
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        verification
      }

      RewardContinueButton(title: "Print or share passport") {
        exportPassport()
      }
    }
  }

  /// The QR a reader scans to check the passport, with the book's seal pressed
  /// half over it.
  private var verification: some View {
    VStack(spacing: 4) {
      Color.deepPlum.opacity(0.8)
        .mask {
          PassportQRCode(text: "https://deep.app/verify/\(sample.verificationCode)")
            .colorInvert()
            .luminanceToAlpha()
        }
        .frame(width: 58, height: 58)
      Text(sample.verificationCode)
        .font(DeepType.micro.monospaced())
        .foregroundStyle(.driftGrey)
    }
    .overlay(alignment: .topLeading) {
      BookStampPress(isStamped: isStamped, delay: 0.35, tilt: 14) {
        BookRoundStamp(top: "GROWTH PASSPORT", bottom: "WITH CARE", diameter: 84, ink: BookInk.issue, wear: 1) {
          Text("deep")
            .font(DeepType.body.italic())
            .fontDesign(.serif)
        }
      }
      .offset(x: -44, y: -40)
    }
  }
}

// MARK: - Page parts

private struct BookEyebrow: View {
  let title: String
  let symbol: String
  let tint: Color

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: symbol)
        .font(DeepType.micro)
        .foregroundStyle(tint)
      Text(title)
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.driftGrey)
    }
  }
}

/// Eyebrow plus the page's one serif headline.
private struct BookPageHeader: View {
  let eyebrow: String
  let symbol: String
  let tint: Color
  let title: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      BookEyebrow(title: eyebrow, symbol: symbol, tint: tint)
      Text(title)
        .font(DeepType.displayTitle)
        .foregroundStyle(.deepPlum)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// A passport field: micro label over its value.
private struct BookField<Value: View>: View {
  let label: String
  @ViewBuilder let value: Value

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.driftGrey)
      value
    }
  }
}

private struct BookTextField: View {
  let label: String
  let text: String

  var body: some View {
    BookField(label: label) {
      Text(text)
        .font(DeepType.body)
        .foregroundStyle(.deepPlum)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
  }
}

/// Wraps chips onto as many rows as they need.
private struct BookFlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
    let width = rows.map(\.width).max() ?? 0
    let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
    return CGSize(width: width, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var y = bounds.minY
    for row in arrange(width: bounds.width, subviews: subviews) {
      var x = bounds.minX
      for index in row.indices {
        let size = subviews[index].sizeThatFits(.unspecified)
        subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
        x += size.width + spacing
      }
      y += row.height + spacing
    }
  }

  private struct Row {
    var indices: [Int] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
    var rows: [Row] = []
    var row = Row()
    for index in subviews.indices {
      let size = subviews[index].sizeThatFits(.unspecified)
      let extra = row.indices.isEmpty ? size.width : row.width + spacing + size.width
      if !row.indices.isEmpty, extra > width {
        rows.append(row)
        row = Row()
      }
      row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
      row.height = max(row.height, size.height)
      row.indices.append(index)
    }
    if !row.indices.isEmpty { rows.append(row) }
    return rows
  }
}

// MARK: - Stamps

/// Inks a stamp onto the page the first time its page is seen: it lands from
/// a little above (scale 1.18 → 1), settles its rotation and takes ink, with a
/// light tap for each. Multiplied onto the paper like real ink.
private struct BookStampPress<Content: View>: View {
  let isStamped: Bool
  var delay: Double = 0
  /// The stamp's resting angle — no two land square.
  var tilt: Double = 0
  @ViewBuilder let content: Content

  @State private var inked = false

  var body: some View {
    content
      .rotationEffect(.degrees(tilt + (inked ? 0 : 6)))
      .scaleEffect(inked ? 1 : 1.18)
      .opacity(inked ? 0.85 : 0)
      .blendMode(.multiply)
      .sensoryFeedback(.impact(weight: .light), trigger: inked) { _, isInked in isInked }
      .task(id: isStamped) {
        guard isStamped, !inked else { return }
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return }
        withAnimation(.bloom) { inked = true }
      }
  }
}

/// A round rubber stamp: double ring, words set around the band, a mark in
/// the middle. Worn ink comes from a speckled mask.
private struct BookRoundStamp<Centre: View>: View {
  let top: String
  let bottom: String
  let diameter: CGFloat
  let ink: Color
  var wear = 0
  @ViewBuilder let centre: Centre

  var body: some View {
    let band = diameter / 2 - 11
    ZStack {
      Circle().strokeBorder(lineWidth: 2.4)
      Circle().inset(by: 21).strokeBorder(lineWidth: 1)
      BookArcText(text: top, radius: band)
      BookArcText(text: bottom, radius: band, isBottom: true)
      Image(systemName: "sparkle")
        .imageScale(.small)
        .offset(x: -band)
      Image(systemName: "sparkle")
        .imageScale(.small)
        .offset(x: band)
      centre
    }
    .font(DeepType.micro)
    .foregroundStyle(ink)
    .frame(width: diameter, height: diameter)
    .mask { BookTexture.wearImage(wear).resizable() }
  }
}

/// Letters set one by one around a circle, reading left to right along the
/// top or the bottom of the band.
private struct BookArcText: View {
  let text: String
  let radius: CGFloat
  var isBottom = false
  /// The arc a micro capital takes before squeezing to fit.
  var glyphWidth: CGFloat = 7.4
  /// The widest the word may spread, in degrees, so it clears the side marks.
  var maxSweep: Double = 140

  var body: some View {
    let glyphs = Array(text)
    let natural = Double(glyphWidth / radius) * 180 / .pi
    let step = min(natural, maxSweep / Double(max(glyphs.count - 1, 1)))
    ZStack {
      ForEach(glyphs.indices, id: \.self) { index in
        let offset = (Double(index) - Double(glyphs.count - 1) / 2) * step
        let theta = isBottom ? 90 - offset : -90 + offset
        let radians = theta * .pi / 180
        Text(String(glyphs[index]))
          .fontWeight(.semibold)
          .rotationEffect(.degrees(isBottom ? theta - 90 : theta + 90))
          .offset(x: radius * cos(radians), y: radius * sin(radians))
      }
    }
  }
}

/// A visa for one cause: name and mark, the partner, hearts sent, and since
/// when — inked in that cause's own colours.
private struct BookVisaStamp: View {
  let gift: PassportCauseGift
  var wear = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .top, spacing: 5) {
        Image(systemName: gift.category.symbol)
        Text(gift.category.name.uppercased())
          .tracking(0.6)
          .lineLimit(2)
          .minimumScaleFactor(0.75)
      }
      .font(DeepType.micro.weight(.bold))
      Text(gift.category.partner.name)
        .font(DeepType.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Spacer(minLength: 2)
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Image(systemName: "heart.fill")
          .font(DeepType.micro)
        Text("\(gift.hearts)")
          .font(DeepType.sectionTitle.weight(.bold).monospacedDigit())
        Text("HEARTS SENT")
          .font(DeepType.micro)
          .tracking(0.8)
      }
      Text("SINCE \(gift.firstGivenOn.formatted(.dateTime.day().month(.abbreviated).year()).uppercased())")
        .font(DeepType.micro.monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .padding(.horizontal, 11)
    .padding(.vertical, 9)
    .frame(width: 150, height: 102, alignment: .topLeading)
    .overlay {
      RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(lineWidth: 1.8)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 4, style: .continuous).inset(by: 4).strokeBorder(lineWidth: 0.7)
    }
    .foregroundStyle(BookInk.cause(gift.category))
    .mask { BookTexture.wearImage(wear).resizable() }
  }
}

/// A challenge, stamped as an oval or a hexagon in sunlight ink.
private struct BookChallengeStamp: View {
  let challenge: PassportChallenge
  let isHexagon: Bool
  var wear = 0

  var body: some View {
    let outline = isHexagon ? AnyShape(BookHexagon()) : AnyShape(Ellipse())
    VStack(spacing: 3) {
      Image(systemName: challenge.symbol)
        .font(DeepType.body)
      Text(challenge.title.uppercased())
        .font(DeepType.micro.weight(.bold))
        .tracking(0.5)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.8)
      Text(challenge.completedOn.formatted(.dateTime.day().month(.abbreviated).year()).uppercased())
        .font(DeepType.micro.monospacedDigit())
    }
    .padding(.horizontal, isHexagon ? 26 : 22)
    .frame(width: isHexagon ? 140 : 148, height: isHexagon ? 112 : 100)
    .background {
      ZStack {
        outline.stroke(lineWidth: 2).padding(1)
        outline.stroke(lineWidth: 0.8).padding(6)
      }
    }
    .foregroundStyle(BookInk.journey)
    .mask { BookTexture.wearImage(wear + 1).resizable() }
  }
}

/// A form of the oak still ahead: an open, dashed circle waiting for ink.
private struct BookEmptyRound: View {
  let title: String
  let detail: String
  let diameter: CGFloat

  var body: some View {
    ZStack {
      Circle()
        .strokeBorder(BookInk.empty, style: StrokeStyle(lineWidth: 1.2, dash: [3, 5]))
      VStack(spacing: 3) {
        Text(title)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
        Text(detail.uppercased())
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(Color.driftGrey.opacity(0.75))
      }
      .multilineTextAlignment(.center)
      .padding(16)
    }
    .frame(width: diameter, height: diameter)
  }
}

/// An empty stamp slot, drawn as a dashed outline of the stamp to come.
private struct BookEmptySlot: View {
  let shape: AnyShape
  let title: String

  var body: some View {
    ZStack {
      shape.stroke(BookInk.empty, style: StrokeStyle(lineWidth: 1.2, dash: [3, 5]))
      Text(title)
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 22)
    }
  }
}

private struct BookHexagon: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let inset = rect.width * 0.22
    path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
    path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
    path.closeSubpath()
    return path
  }
}

// MARK: - Cover

/// The cover on its hinge. Past edge-on it shows its lining, which fades as it
/// swings flat so the open book is left on its own.
private struct BookCover: View, Animatable {
  let sample: PassportSample
  var angle: Double
  var tilt: CGSize

  var animatableData: AnimatablePair<Double, AnimatablePair<CGFloat, CGFloat>> {
    get { AnimatablePair(angle, AnimatablePair(tilt.width, tilt.height)) }
    set {
      angle = newValue.first
      tilt = CGSize(width: newValue.second.first, height: newValue.second.second)
    }
  }

  var body: some View {
    let swing = sin(min(max(-angle, 0), 180) * .pi / 180)
    let pastEdge = angle < -90
    ZStack {
      BookCoverFront(sample: sample, tilt: tilt)
        .overlay { Color.deepPlum.opacity(0.18 * swing) }
        .opacity(pastEdge ? 0 : 1)
      BookCoverLining()
        .opacity(pastEdge ? (angle + 180) / 90 : 0)
    }
    .clipShape(BookShape.cover)
    .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.45)
  }
}

/// Soft sage leather: grain, a shaded spine, saddle stitching, and the
/// wordmark pressed in cream foil around the oak's medallion.
private struct BookCoverFront: View {
  let sample: PassportSample
  let tilt: CGSize

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [GardenColor.sage, GardenColor.sage.mix(with: GardenColor.fern, by: 0.62)],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
      )
      // A sheen that slides as the book leans.
      RadialGradient(
        colors: [Color.white.opacity(0.24), Color.white.opacity(0)],
        center: UnitPoint(x: 0.72 + tilt.width / 60, y: 0.1 + tilt.height / 60),
        startRadius: 0,
        endRadius: 380
      )
      Image(uiImage: BookTexture.leather)
        .resizable(resizingMode: .tile)

      HStack(spacing: 0) {
        LinearGradient(
          colors: [Color.deepPlum.opacity(0.28), Color.deepPlum.opacity(0.04)],
          startPoint: .leading,
          endPoint: .trailing
        )
        .frame(width: 24)
        LinearGradient(
          colors: [Color.white.opacity(0), Color.white.opacity(0.14), Color.white.opacity(0)],
          startPoint: .leading,
          endPoint: .trailing
        )
        .frame(width: 8)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      stitching

      VStack(spacing: 0) {
        Text("deep")
          .font(BookFont.coverWordmark)
          .modifier(BookFoil())
          .padding(.top, 60)
        Text("GROWTH PASSPORT")
          .font(DeepType.micro)
          .tracking(4)
          .modifier(BookFoil())
          .padding(.top, 6)

        Spacer(minLength: 0)

        BookMedallion(stageIndex: sample.currentStageIndex, diameter: 150)
        Text(sample.currentStage.name)
          .font(DeepType.revealTitle)
          .modifier(BookFoil())
          .padding(.top, 16)
        Text(sample.plantTraits.joined(separator: ", "))
          .font(DeepType.caption)
          .foregroundStyle(Color.moonCream.opacity(0.78))
          .padding(.top, 4)

        Spacer(minLength: 0)

        Text(sample.memberName.uppercased())
          .font(DeepType.micro)
          .tracking(3)
          .modifier(BookBlindEmboss())
          .padding(.bottom, 48)
      }
      .padding(.leading, 16)
    }
  }

  /// Saddle stitching, with a faint shadow so the thread sits in the leather.
  private var stitching: some View {
    let seam = UnevenRoundedRectangle(
      cornerRadii: RectangleCornerRadii(topLeading: 3, bottomLeading: 3, bottomTrailing: 10, topTrailing: 10),
      style: .continuous
    )
    let thread = StrokeStyle(lineWidth: 1.3, lineCap: .round, dash: [5, 4])
    return ZStack {
      seam.stroke(Color.deepPlum.opacity(0.16), style: thread).offset(y: 1)
      seam.stroke(Color.white.opacity(0.38), style: thread)
    }
    .padding(12)
    .padding(.leading, 20)
  }
}

/// The cover's inside: a pale meadow endpaper.
private struct BookCoverLining: View {
  var body: some View {
    ZStack {
      Color.moonCream
      GardenColor.meadow.opacity(0.45)
      BookGuilloche()
        .stroke(GardenColor.sage.opacity(0.35), lineWidth: 0.6)
        .padding(40)
      Image(uiImage: BookTexture.paper)
        .resizable(resizingMode: .tile)
    }
  }
}

/// The oak's current form, seated in a cream medallion set into the leather.
private struct BookMedallion: View {
  let stageIndex: Int
  let diameter: CGFloat

  var body: some View {
    ZStack {
      Circle().fill(Color.moonCream)
      PassportArt.oak(stage: stageIndex)
        .resizable()
        .scaledToFill()
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .blendMode(.multiply)
      Circle().fill(
        RadialGradient(
          colors: [Color.deepPlum.opacity(0), Color.deepPlum.opacity(0.14)],
          center: .center,
          startRadius: diameter * 0.36,
          endRadius: diameter / 2
        )
      )
      Circle().strokeBorder(BookFoil.gradient, lineWidth: 3)
      Circle().inset(by: 7).strokeBorder(Color.softLilac.opacity(0.5), lineWidth: 0.6)
    }
    .frame(width: diameter, height: diameter)
    .compositingGroup()
    .shadow(color: GardenColor.fern.mix(with: .deepPlum, by: 0.5).opacity(0.45), radius: 3, x: 0, y: 2)
  }
}

/// Cream foil, pressed: a dark lower edge and a lit upper one.
private struct BookFoil: ViewModifier {
  static var gradient: LinearGradient {
    LinearGradient(
      colors: [.moonCream, Color.peachCloud.mix(with: .moonCream, by: 0.35)],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  func body(content: Content) -> some View {
    content
      .foregroundStyle(Self.gradient)
      .shadow(color: GardenColor.fern.mix(with: .deepPlum, by: 0.5).opacity(0.6), radius: 0.4, x: 0, y: 1.1)
      .shadow(color: Color.white.opacity(0.4), radius: 0, x: 0, y: -0.6)
  }
}

/// Blind deboss: no foil, just leather pressed down.
private struct BookBlindEmboss: ViewModifier {
  func body(content: Content) -> some View {
    content
      .foregroundStyle(GardenColor.fern.mix(with: GardenColor.sage, by: 0.3))
      .shadow(color: Color.white.opacity(0.32), radius: 0, x: 0, y: 0.8)
      .shadow(color: Color.deepPlum.opacity(0.28), radius: 0, x: 0, y: -0.6)
  }
}

// MARK: - Materials

private enum BookShape {
  static let page = UnevenRoundedRectangle(
    cornerRadii: RectangleCornerRadii(topLeading: 4, bottomLeading: 4, bottomTrailing: 16, topTrailing: 16),
    style: .continuous
  )
  static let cover = UnevenRoundedRectangle(
    cornerRadii: RectangleCornerRadii(topLeading: 7, bottomLeading: 7, bottomTrailing: 18, topTrailing: 18),
    style: .continuous
  )
}

private enum BookFont {
  /// The cover's wordmark sits a size above `DeepType.wordmark`: it is the
  /// object's title, read from arm's length.
  static let coverWordmark = Font.system(.largeTitle, design: .serif, weight: .light).italic()
}

/// Cream paper: a warm wash, a faint guilloche rosette like a security print,
/// grain, and the gutter's shade along the spine.
private struct BookPaper: View {
  var body: some View {
    ZStack {
      Color.moonCream
      LinearGradient(
        colors: [Color.peachCloud.opacity(0.22), Color.moonCream.opacity(0), Color.blushPowder.opacity(0.12)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      BookGuilloche()
        .stroke(Color.lavenderMist.opacity(0.14), lineWidth: 0.6)
        .frame(width: 260, height: 260)
        .offset(x: 50, y: 110)
      Image(uiImage: BookTexture.paper)
        .resizable(resizingMode: .tile)
      LinearGradient(
        colors: [Color.deepPlum.opacity(0.09), Color.deepPlum.opacity(0)],
        startPoint: .leading,
        endPoint: .trailing
      )
      .frame(width: 30)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

/// A rosette of phase-shifted lobed strands, the classic banknote pattern.
private struct BookGuilloche: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let centre = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) / 2
    let steps = 480
    for strand in 0..<5 {
      let phase = Double(strand) * .pi / 30
      for step in 0...steps {
        let t = Double(step) / Double(steps) * 2 * .pi
        let r = radius * (0.62 + 0.3 * cos(12 * t + phase) * (0.8 + 0.2 * cos(3 * t)))
        let point = CGPoint(x: centre.x + r * cos(t), y: centre.y + r * sin(t))
        if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
      }
      path.closeSubpath()
    }
    return path
  }
}

/// Ink colours, each drawn from a token and deepened toward plum so it reads
/// on cream paper.
private enum BookInk {
  static var garden: Color { GardenColor.fern.mix(with: .deepPlum, by: 0.22) }
  static var issue: Color { Color.irisDusk.mix(with: .deepPlum, by: 0.18) }
  static var pause: Color { Color.skyWash.mix(with: .deepPlum, by: 0.48) }
  static var journey: Color { GardenColor.sunbeam.mix(with: .deepPlum, by: 0.12) }
  static var heart: Color { Color.blushPowder.mix(with: .deepPlum, by: 0.3) }
  static var empty: Color { Color.driftGrey.opacity(0.45) }

  /// A cause's own palette, deepened into ink.
  static func cause(_ category: CompassionCategory) -> LinearGradient {
    LinearGradient(
      colors: category.palette.colors.map { $0.mix(with: .deepPlum, by: 0.42) },
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}

private enum BookGlyph {
  static func stage(_ index: Int) -> String {
    ["leaf.fill", "tree", "tree.fill"][min(max(index, 0), 2)]
  }
}

/// Small fixed irregularities, so stamps look hand-pressed but render the same
/// every time.
private enum BookJitter {
  static func angle(_ index: Int) -> Double {
    [-7, 5, -3, 8, -5, 3, -8, 4][index % 8]
  }

  static func nudge(_ index: Int) -> CGFloat {
    [-3, 4, 2, -4, 3, -2][index % 6]
  }
}

/// Grain and ink-wear textures, drawn once from a fixed seed and tiled.
private enum BookTexture {
  static let paper = grain(
    seed: 7,
    count: 900,
    inks: [UIColor.peachCloud.withAlphaComponent(0.55), UIColor.driftGrey.withAlphaComponent(0.08)]
  )
  static let leather = grain(
    seed: 11,
    count: 1600,
    inks: [UIColor.white.withAlphaComponent(0.1), UIColor.deepPlum.withAlphaComponent(0.09)]
  )
  private static let wear: [UIImage] = (0..<4).map { wearMask(seed: UInt64(41 + $0 * 17)) }

  static func wearImage(_ index: Int) -> Image {
    Image(uiImage: wear[abs(index) % wear.count])
  }

  private static let tile: CGFloat = 160

  private static func grain(seed: UInt64, count: Int, inks: [UIColor]) -> UIImage {
    var random = BookRandom(seed: seed)
    let format = UIGraphicsImageRendererFormat.default()
    format.opaque = false
    return UIGraphicsImageRenderer(size: CGSize(width: tile, height: tile), format: format).image { context in
      for dot in 0..<count {
        let radius = CGFloat.random(in: 0.25...0.75, using: &random)
        let x = CGFloat.random(in: 0...tile, using: &random)
        let y = CGFloat.random(in: 0...tile, using: &random)
        inks[dot % inks.count].setFill()
        context.cgContext.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
      }
    }
  }

  /// Opaque where ink took, speckled clear where it skipped, with a few soft
  /// thin patches where the stamp met the page unevenly.
  private static func wearMask(seed: UInt64) -> UIImage {
    var random = BookRandom(seed: seed)
    let side: CGFloat = 220
    let format = UIGraphicsImageRendererFormat.default()
    format.opaque = false
    return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
      let cg = context.cgContext
      UIColor.black.setFill()
      cg.fill(CGRect(x: 0, y: 0, width: side, height: side))

      cg.setBlendMode(.clear)
      for _ in 0..<520 {
        let radius = CGFloat.random(in: 0.35...1.4, using: &random)
        let x = CGFloat.random(in: 0...side, using: &random)
        let y = CGFloat.random(in: 0...side, using: &random)
        cg.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
      }

      cg.setBlendMode(.destinationOut)
      let thin = [UIColor.black.withAlphaComponent(0.42).cgColor, UIColor.black.withAlphaComponent(0).cgColor] as CFArray
      guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: thin, locations: [0, 1]) else { return }
      for _ in 0..<8 {
        let radius = CGFloat.random(in: 12...34, using: &random)
        let centre = CGPoint(
          x: CGFloat.random(in: 0...side, using: &random),
          y: CGFloat.random(in: 0...side, using: &random)
        )
        cg.drawRadialGradient(gradient, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: radius, options: [])
      }
    }
  }
}

/// SplitMix64: a tiny seeded generator, so textures come out identical on
/// every launch.
private struct BookRandom: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) { state = seed }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

#Preview("First week") { PassportBookPrototypeView(sample: .firstWeek) }
#Preview("Six months") { PassportBookPrototypeView(sample: .sixMonths) }
#Preview("Two years") { PassportBookPrototypeView(sample: .twoYears) }
#endif
