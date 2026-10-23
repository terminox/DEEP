#if DEBUG
import SwiftUI
import UIKit

// PROTOTYPE — throwaway.
// Variant D, "Keepsake & Portfolio": export first. A holographic credential
// card you tilt and turn, then a portfolio builder with a live A4 preview.

/// The credential card's fixed proportions. A keepsake is a fixed object, so it
/// does not reflow; Dynamic Type is capped on it instead.
private enum KeepsakeCard {
  static let size = CGSize(width: 300, height: 440)
  static let radius: CGFloat = 28
  /// The furthest a drag can lean the card, in degrees.
  static let maxTilt: Double = 14
  static let perspective: CGFloat = 0.5
}

/// "1 cause", "3 causes".
private func keepsakeCount(_ value: Int, _ one: String, _ many: String) -> String {
  value == 1 ? one : many
}

// MARK: - Screen

/// Export-first Growth Passport: the card is the hero, the printable portfolio
/// is the job. One scroll, top to bottom: the card, what goes on paper, the
/// paper itself, and the export.
struct KeepsakePrototypeView: View {
  let sample: PassportSample

  @State private var sections = PassportSections()
  @State private var isExporting = false
  @State private var isReading = false
  @State private var hasArrived = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        header

        KeepsakeCredential(sample: sample)
          .frame(maxWidth: .infinity)
          .padding(.top, 28)
          .scaleEffect(hasArrived ? 1 : 0.92)
          .opacity(hasArrived ? 1 : 0)
          .animation(.bloom, value: hasArrived)

        Group {
          KeepsakePortfolioCard(sample: sample, sections: $sections)
            .padding(.top, 40)

          documentPreview
            .padding(.top, .rhythm)

          exportAction
            .padding(.top, 28)
        }
        .opacity(hasArrived ? 1 : 0)
        .animation(.bloom.delay(0.25), value: hasArrived)
      }
      .padding(.horizontal, .edge)
      .padding(.top, 12)
      // The prototype switcher floats over the bottom of the screen.
      .padding(.bottom, 120)
    }
    .scrollIndicators(.hidden)
    .background { AtmosphereBackground().ignoresSafeArea() }
    .onAppear { hasArrived = true }
    .sheet(isPresented: $isExporting) {
      PassportExportSheet(sample: sample, sections: sections)
    }
    .sheet(isPresented: $isReading) {
      KeepsakeDocumentSheet(sample: sample, sections: sections)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("GROWTH PASSPORT")
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.driftGrey)
      Text("Your growth, ready to share")
        .font(DeepType.displayTitle)
        .foregroundStyle(.deepPlum)
      Text("A keepsake card for you, and a printable record for the people who ask.")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var documentPreview: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text("YOUR DOCUMENT")
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)
        Text("Two A4 pages. Tap to look closer.")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      }

      Button {
        isReading = true
      } label: {
        KeepsakeDocumentFan(sample: sample, sections: sections)
      }
      .buttonStyle(.softPress)
      .accessibilityLabel("Preview of your printable passport")
      .accessibilityHint("Opens the pages larger")
    }
  }

  private var exportAction: some View {
    VStack(spacing: 12) {
      RewardContinueButton(title: "Export PDF") {
        isExporting = true
      }
      Text("Every copy carries a QR code, so a reader can check it is genuine.")
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

// MARK: - Credential card

/// The card, its hint and its share action. Owns the tilt and the flip: a drag
/// leans the card toward the finger (rubber-banded to `maxTilt`), release
/// settles it flat, and a touch that barely moves turns it over.
private struct KeepsakeCredential: View {
  let sample: PassportSample

  /// Degrees: `width` leans around the vertical axis, `height` around the
  /// horizontal one.
  @State private var tilt = CGSize.zero
  /// Half-turns so far. Always counts up, so the card keeps turning the same
  /// way instead of spinning back.
  @State private var flips = 0
  @State private var shareImage: Image?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var showsBack: Bool { flips % 2 == 1 }

  var body: some View {
    VStack(spacing: 20) {
      KeepsakeCardStage(
        sample: sample,
        angle: Double(flips) * 180,
        tilt: tilt,
        drifts: !reduceMotion
      )
      .frame(width: KeepsakeCard.size.width, height: KeepsakeCard.size.height)
      .contentShape(Rectangle())
      .gesture(drag)
      .dynamicTypeSize(.large)
      .sensoryFeedback(.impact(weight: .light), trigger: flips)
      .accessibilityElement(children: .contain)
      .accessibilityLabel(showsBack ? "Growth Passport card, Compassion side" : "Growth Passport card, front")
      .accessibilityAction(named: "Turn card") { turn() }

      VStack(spacing: 10) {
        Text("Tilt or tap to turn")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)

        Group {
          if let shareImage {
            ShareLink(
              item: shareImage,
              preview: SharePreview("My DEEP Growth Passport", image: shareImage)
            ) {
              shareLabel
            }
            .buttonStyle(.softPress)
          } else {
            shareLabel.hidden()
          }
        }
      }
    }
    .task { shareImage = renderFront() }
  }

  private var shareLabel: some View {
    Label("Share card", systemImage: "square.and.arrow.up")
      .font(DeepType.body.weight(.semibold))
      .foregroundStyle(.irisDusk)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .contentShape(Capsule())
  }

  private var drag: some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        guard !reduceMotion else { return }
        let lean = CGSize(
          width: CGFloat(KeepsakeCard.maxTilt * tanh(Double(value.translation.width) / 120)),
          height: CGFloat(KeepsakeCard.maxTilt * tanh(Double(-value.translation.height) / 120))
        )
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.86)) {
          tilt = lean
        }
      }
      .onEnded { value in
        let travel = hypot(value.translation.width, value.translation.height)
        if travel < 8 {
          turn()
        } else {
          withAnimation(.settle) { tilt = .zero }
        }
      }
  }

  private func turn() {
    withAnimation(.exhale) {
      tilt = .zero
      flips += 1
    }
  }

  /// The front, flat and at rest, as a picture for the share sheet.
  @MainActor
  private func renderFront() -> Image? {
    let renderer = ImageRenderer(
      content: KeepsakeCardFront(sample: sample, drifts: false)
        .dynamicTypeSize(.large)
        .environment(\.colorScheme, .light)
    )
    renderer.scale = 3
    guard let image = renderer.uiImage else { return nil }
    return Image(uiImage: image)
  }
}

/// Draws the card at a flip angle. Animatable on the angle alone, so the face
/// swap happens exactly at 90° while the flip is in flight; the tilt reaches
/// the card through ordinary modifiers, which animate on their own.
private struct KeepsakeCardStage: View, Animatable {
  let sample: PassportSample
  var angle: Double
  let tilt: CGSize
  let drifts: Bool

  var animatableData: Double {
    get { angle }
    set { angle = newValue }
  }

  var body: some View {
    let turned = angle.truncatingRemainder(dividingBy: 360)
    let showsBack = turned > 90 && turned < 270
    // How square-on the card is to the viewer: 1 flat, 0 edge-on.
    let facing = abs(cos(angle * .pi / 180))

    ZStack {
      // A flat caster that never tilts, so the soft lavender shadow stays on
      // the ground and slides away from the lean instead of riding the card.
      RoundedRectangle(cornerRadius: KeepsakeCard.radius, style: .continuous)
        .fill(Color.moonCream)
        .frame(
          width: KeepsakeCard.size.width * 0.84 * max(facing, 0.2),
          height: KeepsakeCard.size.height * 0.86
        )
        .shadow(color: Color.lavenderMist.opacity(0.5), radius: 30, x: 0, y: 24)
        .offset(x: -tilt.width * 1.6, y: tilt.height * 1.2)

      ZStack {
        KeepsakeCardFront(sample: sample, tilt: tilt, drifts: drifts)
          .opacity(showsBack ? 0 : 1)
        // Pre-mirrored, so once the card has turned 180° the back reads true.
        KeepsakeCardBack(sample: sample, tilt: tilt, drifts: drifts)
          .scaleEffect(x: -1, y: 1)
          .opacity(showsBack ? 1 : 0)
      }
      .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: KeepsakeCard.perspective)
      .rotation3DEffect(.degrees(tilt.height), axis: (x: 1, y: 0, z: 0), perspective: KeepsakeCard.perspective)
      .rotation3DEffect(.degrees(tilt.width), axis: (x: 0, y: 1, z: 0), perspective: KeepsakeCard.perspective)
    }
  }
}

// MARK: - Card faces

/// The front: who holds the passport, what has grown, and three figures.
private struct KeepsakeCardFront: View {
  let sample: PassportSample
  var tilt: CGSize = .zero
  var drifts = true

  var body: some View {
    ZStack {
      KeepsakePearl(tilt: tilt)
      KeepsakeWaves()
        .offset(x: tilt.width * 0.4, y: -tilt.height * 0.4)
      content
      KeepsakeSheen(tilt: tilt, drifts: drifts)
    }
    .keepsakeSurface()
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 0) {
          Text(verbatim: "deep")
            .font(DeepType.wordmark)
            .foregroundStyle(.irisDusk)
          Text("GROWTH PASSPORT")
            .font(DeepType.micro)
            .tracking(.microTracking)
            .foregroundStyle(.deepPlum)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        VStack(alignment: .trailing, spacing: 2) {
          Text("NO.")
            .font(DeepType.micro)
            .tracking(.microTracking)
            .foregroundStyle(.driftGrey)
          Text(sample.verificationCode)
            .font(DeepType.caption.monospaced())
            .foregroundStyle(.deepPlum)
        }
        .padding(.top, 8)
      }

      portrait
        .frame(maxWidth: .infinity)
        .padding(.top, 6)

      VStack(alignment: .leading, spacing: 3) {
        Text(sample.currentStage.name)
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
        Text(sample.plantTraits.joined(separator: ", "))
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      }
      .padding(.top, 10)

      VStack(alignment: .leading, spacing: 2) {
        Text(sample.memberName)
          .font(DeepType.sectionTitle)
          .foregroundStyle(.deepPlum)
        Text("Member since \(sample.memberSince.formatted(.dateTime.month(.wide).year()))")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      }
      .padding(.top, 12)

      Spacer(minLength: 10)

      VStack(alignment: .leading, spacing: 5) {
        ForEach(facts) { KeepsakeFactLine(fact: $0) }
      }
    }
    .lineLimit(1)
    .padding(22)
  }

  /// The current form inside its growth halo, framed by a guilloché rosette
  /// that drifts against it as the card leans.
  private var portrait: some View {
    PassportStagePortrait(
      stageIndex: sample.currentStageIndex,
      diameter: 112,
      progress: sample.isFullyGrown ? nil : sample.growthProgress
    )
    .background {
      ZStack {
        RadialGradient(colors: [.white.opacity(0.7), .clear], center: .center, startRadius: 40, endRadius: 100)
        KeepsakeRosette()
      }
      .frame(width: 232, height: 232)
      .offset(x: tilt.width * 0.75, y: -tilt.height * 0.75)
    }
    .offset(x: -tilt.width * 0.4, y: tilt.height * 0.4)
  }

  private var facts: [KeepsakeFact] {
    [
      KeepsakeFact(
        value: sample.sessions,
        label: keepsakeCount(sample.sessions, "DEEP Session", "DEEP Sessions"),
        symbol: "wind",
        tint: .lavenderMist
      ),
      KeepsakeFact(
        value: sample.pausesAttended,
        label: keepsakeCount(sample.pausesAttended, "Global Pause", "Global Pauses"),
        symbol: "globe.asia.australia.fill",
        tint: .lavenderMist
      ),
      KeepsakeFact(
        value: sample.heartsGiven,
        label: keepsakeCount(sample.heartsGiven, "heart sent", "hearts sent"),
        symbol: "heart.fill",
        tint: .blushPowder
      ),
    ]
    .filter { $0.value > 0 }
  }
}

/// The back: the Compassion side, where the hearts went and who received them,
/// with the verification code a reader can check.
private struct KeepsakeCardBack: View {
  let sample: PassportSample
  var tilt: CGSize = .zero
  var drifts = true

  var body: some View {
    ZStack {
      KeepsakePearl(tilt: tilt, isWarm: true)
      KeepsakeWaves()
        .offset(x: tilt.width * 0.4, y: -tilt.height * 0.4)
      content
      KeepsakeSheen(tilt: tilt, drifts: drifts)
    }
    .keepsakeSurface()
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 3) {
        Text("COMPASSION PORTFOLIO")
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.deepPlum)
        Text("Kindness sent")
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
      }

      HStack(spacing: 16) {
        ZStack {
          CompassionRing(segments: sample.giftSegments, lineWidth: 8)
          VStack(spacing: 0) {
            Text(sample.heartsGiven.formatted())
              .font(DeepType.counter)
              .foregroundStyle(.deepPlum)
              .monospacedDigit()
            Text("HEARTS")
              .font(DeepType.micro)
              .tracking(.microTracking)
              .foregroundStyle(.driftGrey)
          }
        }
        .frame(width: 84, height: 84)
        .offset(x: -tilt.width * 0.3, y: tilt.height * 0.3)

        VStack(alignment: .leading, spacing: 5) {
          ForEach(facts) { KeepsakeFactLine(fact: $0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.top, 12)

      VStack(alignment: .leading, spacing: 6) {
        ForEach(sample.gifts) { gift in
          causeRow(gift)
        }
      }
      .padding(.top, 14)

      extra
        .padding(.top, 12)

      Spacer(minLength: 8)

      verification
    }
    .lineLimit(1)
    .padding(22)
  }

  private func causeRow(_ gift: PassportCauseGift) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Circle()
        .fill(LinearGradient(colors: gift.category.palette.colors, startPoint: .top, endPoint: .bottom))
        .frame(width: 8, height: 8)
        .padding(.top, 5)
      VStack(alignment: .leading, spacing: 0) {
        Text(gift.category.name)
          .font(DeepType.caption.weight(.semibold))
          .foregroundStyle(.deepPlum)
        Text(gift.category.partner.name.uppercased())
          .font(DeepType.micro)
          .tracking(0.8)
          .foregroundStyle(.driftGrey)
          .minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Text(gift.hearts.formatted())
        .font(DeepType.caption.weight(.semibold))
        .foregroundStyle(.deepPlum)
        .monospacedDigit()
    }
  }

  /// What fills the space the causes leave: the challenges when there are a
  /// few, or the member's own words when the journey is young.
  @ViewBuilder
  private var extra: some View {
    if !sample.challenges.isEmpty, sample.gifts.count <= 3 {
      VStack(alignment: .leading, spacing: 5) {
        Text("CHALLENGES & EVENTS")
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)
        ForEach(sample.challenges.prefix(2)) { challenge in
          HStack(spacing: 7) {
            Image(systemName: challenge.symbol)
              .font(.system(size: 10, weight: .semibold))
              .foregroundStyle(.lavenderMist)
              .frame(width: 14)
            Text(challenge.title)
              .font(DeepType.caption)
              .foregroundStyle(.deepPlum)
          }
        }
      }
    } else if sample.challenges.isEmpty, sample.gifts.count <= 2, let message = sample.peaceMessages.first {
      Text("\u{201C}\(message.text)\u{201D}")
        .font(DeepType.caption.italic())
        .foregroundStyle(.deepPlum)
        .lineLimit(3)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pebble(cornerRadius: 14)
    }
  }

  private var verification: some View {
    HStack(spacing: 12) {
      // Plum modules on a white seat: scannable, and never black.
      Color.deepPlum
        .mask {
          PassportQRCode(text: "https://deep.app/verify/\(sample.verificationCode)")
            .colorInvert()
            .luminanceToAlpha()
        }
        .frame(width: 50, height: 50)
        .padding(5)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

      VStack(alignment: .leading, spacing: 2) {
        Text("ISSUED \(sample.issuedOn.formatted(.dateTime.day().month(.abbreviated).year()).uppercased())")
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)
        Text(verbatim: "Verify at deep.app/verify/\(sample.verificationCode)")
          .font(DeepType.caption)
          .foregroundStyle(.deepPlum)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var facts: [KeepsakeFact] {
    [
      KeepsakeFact(
        value: sample.causesSupported,
        label: keepsakeCount(sample.causesSupported, "cause", "causes"),
        symbol: "heart.circle.fill",
        tint: .blushPowder
      ),
      KeepsakeFact(
        value: sample.peaceMessages.count,
        label: keepsakeCount(sample.peaceMessages.count, "peace message", "peace messages"),
        symbol: "envelope.fill",
        tint: .lavenderMist
      ),
      KeepsakeFact(
        value: sample.challenges.count,
        label: keepsakeCount(sample.challenges.count, "challenge joined", "challenges joined"),
        symbol: "sparkles",
        tint: .lavenderMist
      ),
    ]
    .filter { $0.value > 0 }
  }
}

/// One card-grammar figure: semibold plum numeral, grey label, a small glyph.
private struct KeepsakeFact: Identifiable {
  let value: Int
  let label: String
  let symbol: String
  let tint: Color

  var id: String { symbol }
}

private struct KeepsakeFactLine: View {
  let fact: KeepsakeFact

  var body: some View {
    HStack(spacing: 7) {
      Image(systemName: fact.symbol)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(fact.tint)
        .frame(width: 14)
      let value = Text(fact.value.formatted())
        .fontWeight(.semibold)
        .foregroundStyle(.deepPlum)
      let label = Text(fact.label)
        .foregroundStyle(.driftGrey)
      Text("\(value) \(label)")
        .font(DeepType.caption)
        .monospacedDigit()
        .contentTransition(.numericText())
    }
  }
}

// MARK: - Card materials

private extension View {
  /// Cuts a face to the card and gives it a glossy rim, brighter at the corner
  /// the light comes from.
  func keepsakeSurface() -> some View {
    let shape = RoundedRectangle(cornerRadius: KeepsakeCard.radius, style: .continuous)
    return self
      .frame(width: KeepsakeCard.size.width, height: KeepsakeCard.size.height)
      .clipShape(shape)
      .overlay {
        shape.strokeBorder(
          LinearGradient(
            colors: [.white.opacity(0.95), .white.opacity(0.25), .white.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1
        )
      }
  }
}

/// The pearlescent base: a pastel mesh over moonCream, plus a faint
/// iridescent wash that turns as the card leans.
private struct KeepsakePearl: View {
  var tilt: CGSize = .zero
  /// The back leans blush, so the two faces read as two sides of one object.
  var isWarm = false

  var body: some View {
    ZStack {
      Color.moonCream
      MeshGradient(
        width: 3,
        height: 3,
        points: [
          [0, 0], [0.5, 0], [1, 0],
          [0, 0.5], [0.55, 0.42], [1, 0.5],
          [0, 1], [0.5, 1], [1, 1],
        ],
        colors: isWarm ? warmColors : coolColors
      )
      AngularGradient(
        colors: [.skyWash, .softLilac, .blushPowder, .peachCloud, GardenColor.meadow, .skyWash],
        center: .center
      )
      .scaleEffect(1.8)
      .rotationEffect(.degrees(tilt.width * 5 - tilt.height * 3))
      .opacity(0.2)
      .blendMode(.overlay)
    }
  }

  private var coolColors: [Color] {
    [
      Color.softLilac.opacity(0.6), .moonCream, Color.skyWash.opacity(0.55),
      Color.blushPowder.opacity(0.4), .moonCream, Color.softLilac.opacity(0.35),
      GardenColor.meadow.opacity(0.6), Color.skyWash.opacity(0.4), Color.blushPowder.opacity(0.45),
    ]
  }

  private var warmColors: [Color] {
    [
      Color.blushPowder.opacity(0.55), .moonCream, Color.softLilac.opacity(0.5),
      Color.peachCloud.opacity(0.4), .moonCream, Color.skyWash.opacity(0.4),
      Color.softLilac.opacity(0.45), Color.blushPowder.opacity(0.4), GardenColor.meadow.opacity(0.45),
    ]
  }
}

/// The holographic band: a soft diagonal of white edged in sky and blush,
/// screened over the card. Leaning slides it across; untouched, it drifts on
/// its own, slowly, so the card is never quite still.
private struct KeepsakeSheen: View {
  let tilt: CGSize
  let drifts: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let isDrifting = drifts && !reduceMotion
      TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isDrifting)) { timeline in
        let seconds = timeline.date.timeIntervalSinceReferenceDate
        let idle = isDrifting ? sin(seconds * 2 * .pi / 12) * 0.3 : -0.12
        band(size)
          .offset(x: idle * size.width, y: idle * size.height * 0.5)
      }
      // The lean rides a separate offset, so a drag animates against the
      // drift instead of fighting it frame by frame.
      .offset(
        x: tilt.width / KeepsakeCard.maxTilt * size.width * 0.5,
        y: -tilt.height / KeepsakeCard.maxTilt * size.height * 0.3
      )
    }
    .blendMode(.screen)
    .allowsHitTesting(false)
  }

  private func band(_ size: CGSize) -> some View {
    LinearGradient(
      stops: [
        .init(color: .clear, location: 0.38),
        .init(color: Color.skyWash.opacity(0.18), location: 0.45),
        .init(color: .white.opacity(0.3), location: 0.5),
        .init(color: Color.blushPowder.opacity(0.18), location: 0.55),
        .init(color: .clear, location: 0.62),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .frame(width: size.width * 2.2, height: size.height * 2.2)
    .position(x: size.width / 2, y: size.height / 2)
  }
}

/// A guilloché rosette: rings of fine waves, the security-document texture
/// that frames the portrait. Texture, not a rule.
private struct KeepsakeRosette: View {
  var body: some View {
    Canvas { context, size in
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      let base = min(size.width, size.height) / 2
      for ring in 0..<18 {
        let radius = base * (0.6 + Double(ring) * 0.021)
        var path = Path()
        for step in 0...360 {
          let theta = Double(step) / 360 * 2 * .pi
          let r = radius + base * 0.035 * sin(14 * theta + Double(ring) * 0.35)
          let point = CGPoint(x: center.x + r * cos(theta), y: center.y + r * sin(theta))
          if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        context.stroke(path, with: .color(Color.irisDusk.opacity(0.1)), lineWidth: 0.6)
      }
    }
    .allowsHitTesting(false)
  }
}

/// Fine interfering waves across the lower card, under the figures.
private struct KeepsakeWaves: View {
  var body: some View {
    Canvas { context, size in
      for line in 0..<18 {
        let rowY = size.height * 0.58 + Double(line) * 8
        var path = Path()
        var x: Double = -10
        path.move(to: CGPoint(x: x, y: rowY))
        while x <= size.width + 10 {
          let y = rowY + 3.5 * sin(x / 18 + Double(line) * 0.45) + 1.6 * sin(x / 7 - Double(line) * 0.3)
          path.addLine(to: CGPoint(x: x, y: y))
          x += 3
        }
        context.stroke(path, with: .color(Color.irisDusk.opacity(0.07)), lineWidth: 0.5)
      }
    }
    .allowsHitTesting(false)
  }
}

// MARK: - Portfolio builder

/// What goes on paper. Each switch reshapes the live preview below it.
private struct KeepsakePortfolioCard: View {
  let sample: PassportSample
  @Binding var sections: PassportSections

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("FOR APPLICATIONS")
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.driftGrey)
      Text("Prepare your portfolio")
        .font(DeepType.displayTitle)
        .foregroundStyle(.deepPlum)
        .padding(.top, 5)
      Text("A printable record of your practice and kindness, for volunteer programmes, scholarships and applications.")
        .font(DeepType.body)
        .foregroundStyle(.driftGrey)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 6)

      VStack(spacing: 14) {
        KeepsakeSectionToggle(
          title: "Mind Garden",
          symbol: "leaf.fill",
          bubble: GardenColor.meadow,
          glyph: GardenColor.fern,
          isOn: $sections.garden
        )
        KeepsakeSectionToggle(
          title: "Practice",
          symbol: "wind",
          bubble: .softLilac,
          glyph: .irisDusk,
          isOn: $sections.practice
        )
        if !sample.gifts.isEmpty {
          KeepsakeSectionToggle(
            title: "Compassion Portfolio",
            symbol: "heart.fill",
            bubble: .blushPowder,
            glyph: .duskRose,
            isOn: $sections.compassion
          )
        }
        if !sample.challenges.isEmpty {
          KeepsakeSectionToggle(
            title: "Challenges & events",
            symbol: "sparkles",
            bubble: .peachCloud,
            glyph: GardenColor.sunbeam,
            isOn: $sections.challenges
          )
        }
        KeepsakeSectionToggle(
          title: "A note to you",
          symbol: "envelope.fill",
          bubble: .skyWash,
          glyph: .irisDusk,
          isOn: $sections.note
        )
      }
      .padding(.top, 20)
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frostedCard()
  }
}

/// A switch row: glyph bubble, label, toggle. Rows are kept apart by space.
private struct KeepsakeSectionToggle: View {
  let title: String
  let symbol: String
  let bubble: Color
  let glyph: Color
  @Binding var isOn: Bool

  var body: some View {
    Toggle(isOn: $isOn) {
      HStack(spacing: 14) {
        Image(systemName: symbol)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(glyph)
          .frame(width: 36, height: 36)
          .background(bubble.opacity(0.45), in: Circle())
        Text(title)
          .font(DeepType.body.weight(.medium))
          .foregroundStyle(.deepPlum)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .tint(.lavenderMist)
    .sensoryFeedback(.selection, trigger: isOn)
  }
}

// MARK: - Document preview

/// An A4 page scaled to a given width, on paper with a soft shadow.
private struct KeepsakePaper<Page: View>: View {
  let width: CGFloat
  @ViewBuilder let page: Page

  var body: some View {
    let scale = width / PassportPaper.size.width
    page
      .frame(width: PassportPaper.size.width, height: PassportPaper.size.height)
      .environment(\.colorScheme, .light)
      .scaleEffect(scale, anchor: .topLeading)
      .frame(width: width, height: PassportPaper.size.height * scale, alignment: .topLeading)
      .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
      .shadow(color: Color.deepPlum.opacity(0.08), radius: 2, x: 0, y: 1)
      .shadow(color: Color.lavenderMist.opacity(0.35), radius: 18, x: 0, y: 10)
  }
}

/// The two pages fanned like sheets laid on a desk: cover behind, portfolio in
/// front. The portfolio exhales into its new shape as sections switch.
private struct KeepsakeDocumentFan: View {
  let sample: PassportSample
  let sections: PassportSections

  private let width: CGFloat = 200

  var body: some View {
    ZStack {
      KeepsakePaper(width: width) {
        PassportDocumentCover(sample: sample)
      }
      .rotationEffect(.degrees(-6), anchor: .bottom)
      .offset(x: -44, y: 4)

      KeepsakePaper(width: width) {
        PassportDocumentPortfolio(sample: sample, sections: sections)
      }
      .rotationEffect(.degrees(2.5), anchor: .bottom)
      .offset(x: 30)
    }
    .animation(.exhale, value: sections)
    .frame(maxWidth: .infinity)
    .frame(height: width * PassportPaper.size.height / PassportPaper.size.width + 24)
    .contentShape(Rectangle())
  }
}

/// The pages at reading size. Double tap to look closer still.
private struct KeepsakeDocumentSheet: View {
  let sample: PassportSample
  let sections: PassportSections

  @State private var isZoomed = false

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 6) {
        Text("YOUR DOCUMENT")
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)
        Text("Your printable passport")
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
        Text("Double tap to look closer.")
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      }
      .padding(.horizontal, .edge)
      .padding(.top, 28)

      GeometryReader { proxy in
        let fit = proxy.size.width - 2 * .edge
        let width = fit * (isZoomed ? 1.8 : 1)
        ScrollView([.vertical, .horizontal]) {
          VStack(spacing: .rhythm) {
            KeepsakePaper(width: width) {
              PassportDocumentCover(sample: sample)
            }
            KeepsakePaper(width: width) {
              PassportDocumentPortfolio(sample: sample, sections: sections)
            }
          }
          .padding(.edge)
          .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .onTapGesture(count: 2) {
          withAnimation(.exhale) { isZoomed.toggle() }
        }
      }
    }
    .background { AtmosphereBackground().ignoresSafeArea() }
    .presentationDragIndicator(.visible)
  }
}

// MARK: - Previews

#Preview("First week") {
  KeepsakePrototypeView(sample: .firstWeek)
}

#Preview("Six months") {
  KeepsakePrototypeView(sample: .sixMonths)
}

#Preview("Two years") {
  KeepsakePrototypeView(sample: .twoYears)
}

#Preview("Card back, two years") {
  ZStack {
    AtmosphereBackground()
    KeepsakeCardBack(sample: .twoYears, drifts: false)
  }
}
#endif
