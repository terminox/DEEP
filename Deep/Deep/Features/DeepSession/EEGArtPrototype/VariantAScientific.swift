#if DEBUG
import SwiftUI

// PROTOTYPE — throwaway, DEBUG only.
// Variant A, "Scientific Waveform": the real data, explained by the science.
// Live shows what the headband actually streams (raw µV traces per sensor,
// electrode fit, relative band power, PPG heart rate); After reads the whole
// recording back as a band-power history, a spectrogram and a plain-language
// summary grounded in `EEGSessionSummary`. Calm and precise, pale DEEP
// atmosphere and frosted cards, never a hospital monitor.

struct EEGScientificView: View {
  let player: EEGSessionPlayer
  let stage: EEGArtStage

  var body: some View {
    ZStack {
      Color.moonCream.ignoresSafeArea()
      AtmosphereBackground()

      ScrollView {
        Group {
          switch stage {
          case .live: ScienceLiveContent(player: player)
          case .after: ScienceAfterContent(recording: player.recording)
          }
        }
        .padding(.horizontal, .edge)
        .padding(.top, 8)
        // Clear of the prototype's floating switcher.
        .padding(.bottom, 190)
      }
      .scrollIndicators(.hidden)
    }
  }
}

// MARK: - Shared vocabulary

private extension HorseshoeFit {
  var tint: Color {
    switch self {
    case .good: EEGBand.alpha.tint
    case .ok: EEGBand.gamma.tint
    case .bad: .duskRose
    }
  }
}

private extension MeditationPhase {
  var tint: Color {
    switch self {
    // Relaxing wears alpha's green and wandering beta's rose, the rhythms that
    // define them.
    case .settling: .lavenderMist
    case .drifting: EEGBand.alpha.tint
    case .wandering: EEGBand.beta.tint
    case .deep: .irisDusk
    case .returning: .peachCloud
    }
  }
}

private extension EEGArtifactKind {
  /// A blink floods delta, a clench floods gamma, so each wears that band.
  var tint: Color {
    switch self {
    case .blink: EEGBand.delta.tint
    case .jawClench: EEGBand.gamma.tint
    }
  }
}

private func clock(_ seconds: Double) -> String {
  let whole = max(Int(seconds.rounded(.down)), 0)
  return "\(whole / 60):\(String(format: "%02d", whole % 60))"
}

private func hertzLabel(_ band: EEGBand) -> String {
  let format: (Double) -> String = { $0.rounded() == $0 ? "\(Int($0))" : String(format: "%.1f", $0) }
  return "\(format(band.hertz.lowerBound))–\(format(band.hertz.upperBound)) Hz"
}

/// Page header: an eyebrow and one serif line.
private struct ScienceHeader: View {
  let eyebrow: String
  let title: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(eyebrow.uppercased())
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.driftGrey)
      Text(title)
        .font(DeepType.wordmark)
        .foregroundStyle(.deepPlum)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 4)
    .padding(.top, 12)
    .padding(.bottom, 4)
  }
}

/// A card's eyebrow plus its one serif headline.
private struct CardTitle: View {
  let eyebrow: String
  let title: String

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(eyebrow.uppercased())
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.driftGrey)
      Text(title)
        .font(DeepType.displayTitle)
        .foregroundStyle(.deepPlum)
    }
  }
}

/// A bold numeral and its plain label: "68 bpm heart rate".
private struct Fact: View {
  let value: String
  let label: String
  var dot: Color? = nil

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      if let dot {
        Circle().fill(dot).frame(width: 7, height: 7)
      }
      Text("\(Text(value).font(DeepType.caption.weight(.semibold)).foregroundStyle(.deepPlum)) \(Text(label).font(DeepType.caption).foregroundStyle(.driftGrey))")
        .monospacedDigit()
        .contentTransition(.numericText())
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

private struct Explainer: View {
  let text: String

  init(_ text: String) { self.text = text }

  var body: some View {
    Text(text)
      .font(DeepType.caption)
      .foregroundStyle(.driftGrey)
      .lineSpacing(2)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// A small chip legend: dot + label.
private struct LegendChip: View {
  let color: Color
  let label: String

  var body: some View {
    HStack(spacing: 5) {
      Circle().fill(color).frame(width: 7, height: 7)
      Text(label)
        .font(DeepType.micro)
        .foregroundStyle(.driftGrey)
    }
  }
}

/// Wraps chips onto as many lines as they need.
private struct WrapLayout: Layout {
  var spacing: CGFloat = 12
  var lineSpacing: CGFloat = 6

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
    let height = rows.last.map { $0.y + $0.height } ?? 0
    let width = rows.map(\.width).max() ?? 0
    return CGSize(width: min(width, proposal.width ?? width), height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let rows = arrange(width: bounds.width, subviews: subviews)
    for row in rows {
      var x = bounds.minX
      for index in row.indices {
        let size = subviews[index].sizeThatFits(.unspecified)
        subviews[index].place(
          at: CGPoint(x: x, y: bounds.minY + row.y + (row.height - size.height) / 2),
          proposal: ProposedViewSize(size)
        )
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
      let last = rows[rows.count - 1]
      if !last.indices.isEmpty, last.width + spacing + size.width > width {
        rows.append(Row(y: last.y + last.height + lineSpacing))
      }
      var row = rows[rows.count - 1]
      row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
      row.height = max(row.height, size.height)
      row.indices.append(index)
      rows[rows.count - 1] = row
    }
    return rows
  }
}

/// Coloured spans along a capsule track: which phase the sitter was in.
private func drawPhaseRibbon(
  _ context: GraphicsContext,
  in rect: CGRect,
  spans: [ScienceDigest.PhaseSpan]
) {
  for span in spans {
    let x0 = rect.minX + rect.width * span.start / EEGSessionRecording.duration
    let x1 = rect.minX + rect.width * span.end / EEGSessionRecording.duration
    let piece = CGRect(x: x0 + 0.75, y: rect.minY, width: max(x1 - x0 - 1.5, 1.5), height: rect.height)
    context.fill(Path(roundedRect: piece, cornerRadius: rect.height / 2), with: .color(span.phase.tint))
  }
}

// MARK: - Live

private struct ScienceLiveContent: View {
  let player: EEGSessionPlayer

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      ScienceHeader(eyebrow: "Live · Muse 2 · 4 sensors · 256 Hz", title: "Your brain, right now")
      RawSignalCard(player: player)
      LiveStateCard(player: player)
      LiveBandCard(player: player)
      SensorFitCard(player: player)
    }
  }
}

/// Four scrolling raw traces, one per electrode, newest on the right.
private struct RawSignalCard: View {
  let player: EEGSessionPlayer

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      CardTitle(eyebrow: "Raw EEG · microvolts", title: "Four sensors")

      VStack(spacing: 12) {
        ForEach(MuseChannel.allCases) { channel in
          RawTraceRow(player: player, channel: channel)
        }
      }

      HStack {
        Text("4 seconds ago")
        Spacer()
        Text("±220 µV per row")
        Spacer()
        Text("now")
      }
      .font(DeepType.micro)
      .foregroundStyle(.driftGrey)

      Explainer("Tall slow bumps on the forehead sensors are blinks. Fuzzy bursts, strongest by the ears, are your jaw. Both are muscle, not mind.")
    }
    .padding(20)
    .frostedCard()
  }
}

private struct RawTraceRow: View {
  let player: EEGSessionPlayer
  let channel: MuseChannel

  static let window: Double = 4
  /// Half the row's height, in µV.
  static let fullScale: Double = 220
  /// The band powers driving the synthesis change slowly; one frame per
  /// quarter second of wall time is plenty, and anchoring buckets to wall time
  /// keeps the past from shimmering as it scrolls.
  static let bucket: Double = 0.25

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(channel.name)
          .font(DeepType.micro.weight(.semibold))
          .tracking(.microTracking)
          .foregroundStyle(.deepPlum)
        Text(channel.place)
          .font(DeepType.micro)
          .foregroundStyle(.driftGrey)
          .frame(maxWidth: .infinity, alignment: .leading)
        let fit = player.current.fit[channel.rawValue]
        LegendChip(color: fit.tint, label: fit.label)
      }

      TimelineView(.animation) { timeline in
        let now = timeline.date.timeIntervalSinceReferenceDate
        let frames = bucketFrames(now: now)
        let artifacts = player.liveArtifacts
        let fit = frames.last?.1.fit[channel.rawValue] ?? .good
        Canvas { context, size in
          drawArtifacts(context, size: size, now: now, artifacts: artifacts)
          drawTrace(context, size: size, now: now, frames: frames, artifacts: artifacts, fit: fit)
        }
      }
      .frame(height: 58)
    }
  }

  private func bucketFrames(now: Double) -> [(Double, EEGFrame)] {
    let first = ((now - Self.window) / Self.bucket).rounded(.down)
    let last = (now / Self.bucket).rounded(.down)
    return stride(from: first, through: last, by: 1).map { index in
      let time = index * Self.bucket
      return (time, player.frame(at: Date(timeIntervalSinceReferenceDate: time)))
    }
  }

  private func drawTrace(
    _ context: GraphicsContext,
    size: CGSize,
    now: Double,
    frames: [(Double, EEGFrame)],
    artifacts: [LiveArtifact],
    fit: HorseshoeFit
  ) {
    guard let firstBucket = frames.first?.0 else { return }
    let rate = MuseRawSignal.sampleRate
    let count = Int(Self.window * rate)
    let newest = (now * rate).rounded(.down)
    let start = now - Self.window
    let mid = size.height / 2
    let scale = mid / Self.fullScale
    var path = Path()
    for step in 0..<count {
      let time = (newest - Double(count - 1 - step)) / rate
      let bucket = min(max(Int(((time - firstBucket) / Self.bucket).rounded(.down)), 0), frames.count - 1)
      let value = MuseRawSignal.sample(channel: channel, wallTime: time, frame: frames[bucket].1, artifacts: artifacts)
      let point = CGPoint(
        x: (time - start) / Self.window * size.width,
        y: mid - min(max(value * scale, -mid), mid)
      )
      if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    let ink: Color = fit == .bad ? .duskRose : .deepPlum
    context.stroke(path, with: .color(ink.opacity(0.78)), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
  }

  /// A soft wash where an artifact hits, and a small label on the sensors it
  /// shows on most (forehead for blinks, ears for clenches).
  private func drawArtifacts(_ context: GraphicsContext, size: CGSize, now: Double, artifacts: [LiveArtifact]) {
    let start = now - Self.window
    for artifact in artifacts {
      let (from, to): (Double, Double) = artifact.kind == .blink ? (0.0, 0.34) : (0.0, 0.9)
      if artifact.kind == .blink, !channel.isFrontal { continue }
      let x0 = (artifact.wallTime + from - start) / Self.window * size.width
      let x1 = (artifact.wallTime + to - start) / Self.window * size.width
      guard x1 > 0, x0 < size.width else { continue }
      let wash = CGRect(x: x0, y: 0, width: x1 - x0, height: size.height)
      context.fill(Path(roundedRect: wash, cornerRadius: 6), with: .color(artifact.kind.tint.opacity(0.16)))

      let labelled = artifact.kind == .blink ? channel == .af7 || channel == .af8 : !channel.isFrontal
      guard labelled else { continue }
      let label = context.resolve(
        Text(artifact.kind == .blink ? "blink" : "jaw")
          .font(DeepType.micro)
          .foregroundStyle(.deepPlum.opacity(0.8))
      )
      let labelSize = label.measure(in: size)
      let chip = CGRect(
        x: min(max(x0, 0), size.width - labelSize.width - 10),
        y: size.height - labelSize.height - 2,
        width: labelSize.width + 10,
        height: labelSize.height + 2
      )
      context.fill(Path(roundedRect: chip, cornerRadius: chip.height / 2), with: .color(.white.opacity(0.85)))
      context.draw(label, at: CGPoint(x: chip.midX, y: chip.midY), anchor: .center)
    }
  }
}

/// Where the sitter is: elapsed time in a halo, the phase, the body.
private struct LiveStateCard: View {
  let player: EEGSessionPlayer

  var body: some View {
    let frame = player.current
    HStack(spacing: 16) {
      ZStack {
        CompassionRing(
          segments: [RingSegment(share: max(player.progress, 0.001), colors: [.lavenderMist, .irisDusk])],
          lineWidth: 8,
          gap: 0
        )
        VStack(spacing: 0) {
          Text(clock(player.sessionTime))
            .font(DeepType.counter)
            .foregroundStyle(.deepPlum)
            .monospacedDigit()
          Text("of 10:00")
            .font(DeepType.micro)
            .foregroundStyle(.driftGrey)
        }
      }
      .frame(width: 96, height: 96)

      VStack(alignment: .leading, spacing: 5) {
        Text("Phase, from EEG".uppercased())
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)
        Text(frame.phase.label)
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
          .contentTransition(.opacity)
          .animation(.exhale, value: frame.phase)
        Fact(value: "\(Int(frame.heartRate.rounded())) bpm", label: "heart rate, from PPG")
        Fact(value: "\(Int((frame.stillness * 100).rounded()))%", label: "still, from motion")
        Fact(value: String(format: "%.2f", frame.calm), label: "DEEP's calm index (from α/β)")
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(20)
    .frostedCard()
  }
}

/// Relative δ θ α β γ power, the share each rhythm holds right now.
private struct LiveBandCard: View {
  let player: EEGSessionPlayer

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      CardTitle(eyebrow: "Relative band power · all sensors", title: "Rhythms")

      TimelineView(.animation) { timeline in
        let frame = player.frame(at: timeline.date)
        VStack(spacing: 11) {
          ForEach(EEGBand.allCases) { band in
            BandRow(band: band, share: frame.relative[band])
          }
        }
      }

      Explainer("Each bar is that rhythm's share of all brain activity, so together they make 100%. As you settle, alpha and theta usually grow and beta, the busy-mind rhythm, shrinks.")
    }
    .padding(20)
    .frostedCard()
  }
}

private struct BandRow: View {
  let band: EEGBand
  let share: Double

  var body: some View {
    HStack(spacing: 12) {
      Text(band.symbol)
        .font(DeepType.sectionTitle)
        .foregroundStyle(band.tint)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 5) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(band.name)
            .font(DeepType.caption.weight(.semibold))
            .foregroundStyle(.deepPlum)
          Text(hertzLabel(band))
            .font(DeepType.micro)
            .foregroundStyle(.driftGrey)
            .frame(maxWidth: .infinity, alignment: .leading)
          Text("\(Int((share * 100).rounded()))%")
            .font(DeepType.caption.weight(.semibold))
            .foregroundStyle(.deepPlum)
            .monospacedDigit()
        }
        GeometryReader { proxy in
          ZStack(alignment: .leading) {
            Capsule().fill(.lavenderMist.opacity(0.16))
            Capsule()
              .fill(band.tint)
              .frame(width: max(proxy.size.width * share, 6))
          }
        }
        .frame(height: 6)
      }
    }
  }
}

/// Top view of the head with the four sensors coloured by fit.
private struct SensorFitCard: View {
  let player: EEGSessionPlayer

  var body: some View {
    let fit = player.current.fit
    let good = fit.filter { $0 == .good }.count
    HStack(spacing: 16) {
      HeadDiagram(fit: fit)
        .frame(width: 112, height: 124)

      VStack(alignment: .leading, spacing: 5) {
        Text("Electrode fit".uppercased())
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)
        Text("Contact")
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
        Fact(value: "\(good) of 4", label: "sensors reading cleanly")
        WrapLayout(spacing: 10, lineSpacing: 4) {
          LegendChip(color: HorseshoeFit.good.tint, label: "Good")
          LegendChip(color: HorseshoeFit.ok.tint, label: "OK")
          LegendChip(color: HorseshoeFit.bad.tint, label: "No contact")
        }
        .padding(.top, 2)
        if good < 4 {
          Explainer("Sensors settle as skin warms. Tuck hair away from the ear sensors if a dot stays gold.")
            .padding(.top, 2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(20)
    .frostedCard()
    .animation(.exhale, value: good)
  }
}

private struct HeadDiagram: View {
  let fit: [HorseshoeFit]

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let centre = CGPoint(x: size.width / 2, y: size.height / 2 + 4)
      let radius = min(size.width, size.height - 8) / 2 - 8
      ZStack {
        Canvas { context, _ in
          // Ears.
          for side in [-1.0, 1.0] {
            let ear = CGRect(x: centre.x + side * radius - 5, y: centre.y - 12, width: 10, height: 24)
            context.fill(Path(ellipseIn: ear), with: .color(.lavenderMist.opacity(0.35)))
          }
          // Nose, pointing up.
          var nose = Path()
          nose.move(to: CGPoint(x: centre.x - 8, y: centre.y - radius + 2))
          nose.addLine(to: CGPoint(x: centre.x, y: centre.y - radius - 9))
          nose.addLine(to: CGPoint(x: centre.x + 8, y: centre.y - radius + 2))
          nose.closeSubpath()
          context.fill(nose, with: .color(.lavenderMist.opacity(0.35)))
          // Scalp.
          let head = Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
          context.fill(head, with: .color(.white.opacity(0.6)))
          context.stroke(head, with: .color(.lavenderMist.opacity(0.7)), lineWidth: 1.5)
        }

        ForEach(MuseChannel.allCases) { channel in
          let point = position(of: channel, centre: centre, radius: radius)
          let tint = fit[channel.rawValue].tint
          ZStack {
            Circle().fill(tint.opacity(0.35)).frame(width: 20, height: 20).blur(radius: 3)
            Circle().fill(tint).frame(width: 11, height: 11)
          }
          .position(point)
          Text(channel.name)
            .font(DeepType.micro)
            .foregroundStyle(.driftGrey)
            .fixedSize()
            .position(x: point.x + (channel.isFrontal ? 0 : (channel == .tp9 ? 10 : -10)), y: point.y + 15)
        }
      }
    }
    .accessibilityElement()
    .accessibilityLabel("Sensor fit: " + MuseChannel.allCases.map { "\($0.name) \(fit[$0.rawValue].label)" }.joined(separator: ", "))
  }

  /// Angles from the nose, clockwise: AF7/AF8 on the forehead, TP9/TP10
  /// just behind the ears.
  private func position(of channel: MuseChannel, centre: CGPoint, radius: CGFloat) -> CGPoint {
    let (degrees, reach): (Double, Double) = switch channel {
    case .af7: (-38, 0.78)
    case .af8: (38, 0.78)
    case .tp9: (-112, 0.86)
    case .tp10: (112, 0.86)
    }
    let angle = degrees * .pi / 180
    let distance = Double(radius) * reach
    return CGPoint(
      x: Double(centre.x) + distance * sin(angle),
      y: Double(centre.y) - distance * cos(angle)
    )
  }
}

// MARK: - After: the digest, computed once per recording

/// Everything the After screen draws, derived once from the recording and
/// cached, so scrolling never recomputes a spectrogram.
private struct ScienceDigest {
  struct PhaseSpan {
    let phase: MeditationPhase
    let start: Double
    let end: Double
  }

  let summary: EEGSessionSummary
  /// Session seconds of each stacked sample.
  let times: [Double]
  /// Per sample, the cumulative boundaries δ, δ+θ, … up to 1 (six values).
  let stacks: [[Double]]
  let phases: [PhaseSpan]
  let spectrogram: CGImage?
  let heartRate: [Double]
  let events: [EEGEvent]
  let blinksPerMinuteStart: Double
  let blinksPerMinuteEnd: Double

  @MainActor private static var cache: [String: ScienceDigest] = [:]

  @MainActor static func of(_ recording: EEGSessionRecording) -> ScienceDigest {
    let key = recording.person?.rawValue ?? "seed-\(recording.profile.seed)"
    if let cached = cache[key] { return cached }
    let digest = ScienceDigest(recording)
    cache[key] = digest
    return digest
  }

  private init(_ recording: EEGSessionRecording) {
    let seconds = recording.seconds
    summary = recording.summary
    events = recording.events

    // Band shares, smoothed over 12 s and sampled every 4 s.
    let step = 4
    let half = 6
    var times: [Double] = []
    var stacks: [[Double]] = []
    for index in stride(from: 0, to: seconds.count, by: step) {
      let window = seconds[max(index - half, 0)..<min(index + half + 1, seconds.count)]
      var mean = BandPowers.zero
      for frame in window { mean = mean + frame.relative }
      mean = mean / Double(window.count)
      var running = 0.0
      var boundaries = [0.0]
      for band in EEGBand.allCases {
        running += mean[band]
        boundaries.append(running)
      }
      times.append(seconds[index].time)
      stacks.append(boundaries.map { $0 / max(running, 0.0001) })
    }
    self.times = times
    self.stacks = stacks

    var spans: [PhaseSpan] = []
    var spanStart = 0.0
    var current = seconds.first?.phase ?? .settling
    for frame in seconds where frame.phase != current {
      spans.append(PhaseSpan(phase: current, start: spanStart, end: frame.time))
      spanStart = frame.time
      current = frame.phase
    }
    spans.append(PhaseSpan(phase: current, start: spanStart, end: EEGSessionRecording.duration))
    phases = spans

    heartRate = stride(from: 0, to: seconds.count, by: 5).map { seconds[$0].heartRate }

    let blinks = recording.events.filter { $0.kind == .blink }
    blinksPerMinuteStart = Double(blinks.filter { $0.time < 120 }.count) / 2
    blinksPerMinuteEnd = Double(blinks.filter { $0.time >= 480 }.count) / 2

    spectrogram = Self.spectrogramImage(seconds)
  }

  /// Rows in the spectrogram image, on a log-frequency axis from 1 to 44 Hz
  /// so the slow bands get room.
  static let spectrogramRows = 96
  static let topHertz: Double = 44

  /// Where a frequency sits on the spectrogram, 0 at the bottom (1 Hz), 1 at
  /// the top (44 Hz).
  static func logPosition(of hertz: Double) -> Double {
    log(max(hertz, 1)) / log(topHertz)
  }

  /// Time × 1–44 Hz heatmap. Log power, tilted by frequency to undo the
  /// natural 1/f fall-off, so every band is readable on one scale.
  private static func spectrogramImage(_ seconds: [EEGFrame]) -> CGImage? {
    let bins = Int(topHertz)
    let rows = spectrogramRows
    let columns = seconds.count
    guard columns > 0 else { return nil }
    // Each row's frequency, sampled between the 1 Hz bins.
    let rowHertz = (0..<rows).map { exp(log(topHertz) * (Double($0) + 0.5) / Double(rows)) }
    var values: [Double] = []
    values.reserveCapacity(columns * rows)
    for frame in seconds {
      let spectrum = EEGSessionRecording.spectrum(of: frame, bins: bins)
      for hertz in rowHertz {
        let position = min(max(hertz - 1, 0), Double(bins - 1))
        let lower = min(Int(position), bins - 2)
        let mix = position - Double(lower)
        let power = spectrum[lower] + (spectrum[lower + 1] - spectrum[lower]) * mix
        values.append(log10(max(power * hertz, 0.0001)))
      }
    }
    let sorted = values.sorted()
    let low = sorted[sorted.count * 3 / 100]
    let high = sorted[sorted.count * 995 / 1000]

    let environment = EnvironmentValues()
    let ramp = [Color.moonCream, .softLilac, .lavenderMist, .irisDusk, .deepPlum].map { $0.resolve(in: environment) }
    func colour(_ unit: Double) -> (UInt8, UInt8, UInt8) {
      let position = min(max(unit, 0), 1) * Double(ramp.count - 1)
      let index = min(Int(position), ramp.count - 2)
      let mix = Float(position - Double(index))
      let a = ramp[index]
      let b = ramp[index + 1]
      func channel(_ x: Float, _ y: Float) -> UInt8 { UInt8(min(max((x + (y - x) * mix) * 255, 0), 255)) }
      return (channel(a.red, b.red), channel(a.green, b.green), channel(a.blue, b.blue))
    }

    var pixels = [UInt8](repeating: 255, count: columns * rows * 4)
    for column in 0..<columns {
      for row in 0..<rows {
        let unit = (values[column * rows + row] - low) / max(high - low, 0.0001)
        let (red, green, blue) = colour(unit)
        // Low frequencies at the bottom.
        let offset = ((rows - 1 - row) * columns + column) * 4
        pixels[offset] = red
        pixels[offset + 1] = green
        pixels[offset + 2] = blue
      }
    }
    guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
    return CGImage(
      width: columns,
      height: rows,
      bitsPerComponent: 8,
      bitsPerPixel: 32,
      bytesPerRow: columns * 4,
      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
      provider: provider,
      decode: nil,
      shouldInterpolate: true,
      intent: .defaultIntent
    )
  }
}

// MARK: - After

private struct ScienceAfterContent: View {
  let recording: EEGSessionRecording

  var body: some View {
    let digest = ScienceDigest.of(recording)
    VStack(alignment: .leading, spacing: 16) {
      ScienceHeader(eyebrow: "After · 10-minute sit · Muse 2", title: "What your brain did")
      SummaryCard(digest: digest)
      BandHistoryCard(digest: digest)
      SpectrogramCard(digest: digest)
      PhasesCard(digest: digest)
      BodyCard(digest: digest)
      MuscleCard(digest: digest)
      HonestNoteCard()
    }
  }
}

private struct SummaryCard: View {
  let digest: ScienceDigest

  private var summary: EEGSessionSummary { digest.summary }

  var body: some View {
    let from = Int(summary.peakAlphaStart / 60)
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 16) {
        ZStack {
          CompassionRing(
            segments: [RingSegment(share: max(summary.averageCalm, 0.001), colors: [EEGBand.alpha.tint, .irisDusk])],
            lineWidth: 8,
            gap: 0
          )
          VStack(spacing: 0) {
            Text(String(format: "%.2f", summary.averageCalm))
              .font(DeepType.counter)
              .foregroundStyle(.deepPlum)
              .monospacedDigit()
            Text("calm index")
              .font(DeepType.micro)
              .foregroundStyle(.driftGrey)
          }
        }
        .frame(width: 96, height: 96)

        VStack(alignment: .leading, spacing: 5) {
          Text("The short version".uppercased())
            .font(DeepType.micro)
            .tracking(.microTracking)
            .foregroundStyle(.driftGrey)
          Text("Alpha rose \(summary.alphaRisePercent)%")
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
          Fact(value: "min \(from)–\(from + 3)", label: "peak alpha")
          Fact(value: String(format: "%.2f", summary.averageCalm), label: "average DEEP's calm index (from α/β)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      VStack(alignment: .leading, spacing: 10) {
        Text("Compared with your first two minutes, alpha was \(summary.alphaRisePercent)% higher from minute \(from) to \(from + 3), a pattern linked with relaxed, wakeful attention.")
        Text(thetaSentence)
        if let wanderSentence {
          Text(wanderSentence)
        }
      }
      .font(DeepType.body)
      .foregroundStyle(.deepPlum)
      .lineSpacing(3)
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(20)
    .frostedCard()
  }

  private var thetaSentence: String {
    if summary.thetaRisePercent >= 15 {
      return "Theta rose \(summary.thetaRisePercent)% between minutes 5 and 8, a slower rhythm often seen as attention turns inward in deeper meditation."
    }
    return "Theta stayed close to where it started (\(summary.thetaRisePercent >= 0 ? "+" : "")\(summary.thetaRisePercent)%), so this sit stayed light and awake rather than deeply absorbed."
  }

  private var wanderSentence: String? {
    switch summary.wanderEpisodes {
    case 0: nil
    case 1: "Your mind wandered once. Beta, the busy-mind rhythm, climbed while it did, then eased as you came back."
    default: "Your mind wandered \(summary.wanderEpisodes) times. Each time beta, the busy-mind rhythm, climbed, then eased as you came back."
    }
  }
}

/// Stacked relative band power across the whole sit, with phases beneath.
private struct BandHistoryCard: View {
  let digest: ScienceDigest

  var body: some View {
    let summary = digest.summary
    VStack(alignment: .leading, spacing: 14) {
      CardTitle(eyebrow: "Relative band power · 10 minutes", title: "Rhythms over time")

      Canvas { context, size in
        let top: CGFloat = 22
        let ribbonHeight: CGFloat = 8
        let plot = CGRect(x: 0, y: top, width: size.width, height: size.height - top - ribbonHeight - 8)
        let xOf = { (time: Double) in plot.minX + plot.width * time / EEGSessionRecording.duration }

        // Stacked bands, delta at the floor.
        for band in EEGBand.allCases {
          let lower = band.rawValue
          var area = Path()
          for (index, time) in digest.times.enumerated() {
            let point = CGPoint(x: xOf(time), y: plot.maxY - plot.height * digest.stacks[index][lower + 1])
            if index == 0 { area.move(to: point) } else { area.addLine(to: point) }
          }
          for (index, time) in digest.times.enumerated().reversed() {
            area.addLine(to: CGPoint(x: xOf(time), y: plot.maxY - plot.height * digest.stacks[index][lower]))
          }
          area.closeSubpath()
          context.fill(area, with: .color(band.tint.opacity(0.88)))
        }

        // The strongest alpha stretch, bracketed above the plot.
        let x0 = xOf(summary.peakAlphaStart)
        let x1 = xOf(summary.peakAlphaStart + 180)
        context.fill(
          Path(roundedRect: CGRect(x: x0, y: top - 6, width: x1 - x0, height: 3), cornerRadius: 1.5),
          with: .color(EEGBand.alpha.tint)
        )
        let label = context.resolve(
          Text("α peak +\(summary.alphaRisePercent)%")
            .font(DeepType.micro.weight(.semibold))
            .foregroundStyle(.deepPlum)
        )
        let width = label.measure(in: size).width
        context.draw(label, at: CGPoint(x: min(max((x0 + x1) / 2, width / 2), size.width - width / 2), y: 4), anchor: .center)

        drawPhaseRibbon(
          context,
          in: CGRect(x: plot.minX, y: plot.maxY + 8, width: plot.width, height: ribbonHeight),
          spans: digest.phases
        )
      }
      .frame(height: 178)
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

      MinuteAxis()

      WrapLayout(spacing: 12, lineSpacing: 6) {
        ForEach(EEGBand.allCases) { band in
          LegendChip(color: band.tint, label: "\(band.symbol) \(band.name)")
        }
      }

      PhaseLegend(digest: digest)

      Explainer("Each colour's height is that rhythm's share of the whole. Watch the green alpha layer thicken as you settle and the rose beta layer swell when your mind wanders.")
    }
    .padding(20)
    .frostedCard()
  }
}

private struct MinuteAxis: View {
  var body: some View {
    HStack {
      Text("0")
      Spacer()
      Text("5 min")
      Spacer()
      Text("10")
    }
    .font(DeepType.micro)
    .foregroundStyle(.driftGrey)
  }
}

private struct PhaseLegend: View {
  let digest: ScienceDigest

  var body: some View {
    let present = Set(digest.phases.map(\.phase))
    WrapLayout(spacing: 12, lineSpacing: 6) {
      ForEach(MeditationPhase.allCases.filter { present.contains($0) }) { phase in
        LegendChip(color: phase.tint, label: phase.label)
      }
    }
  }
}

/// Time × frequency heatmap: where in the spectrum the power sat, minute by
/// minute.
private struct SpectrogramCard: View {
  let digest: ScienceDigest

  private let height: CGFloat = 150
  private let gutter: CGFloat = 22

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      CardTitle(eyebrow: "Spectrogram · 1–44 Hz", title: "Frequencies")

      HStack(alignment: .top, spacing: 6) {
        // Band symbols at each band's centre, low at the bottom.
        ZStack(alignment: .topLeading) {
          ForEach(EEGBand.allCases) { band in
            let centre = (band.hertz.lowerBound * band.hertz.upperBound).squareRoot()
            Text(band.symbol)
              .font(DeepType.caption.weight(.semibold))
              .foregroundStyle(band.tint)
              .position(x: gutter / 2, y: yOf(hertz: centre))
          }
        }
        .frame(width: gutter, height: height)

        VStack(spacing: 8) {
          ZStack {
            if let image = digest.spectrogram {
              Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.high)
            }
          }
          .frame(height: height)
          .frame(maxWidth: .infinity)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

          Canvas { context, size in
            drawPhaseRibbon(context, in: CGRect(origin: .zero, size: size), spans: digest.phases)
          }
          .frame(height: 8)

          MinuteAxis()
        }

        // Band edges in Hz.
        ZStack(alignment: .topLeading) {
          ForEach([4.0, 8.0, 13.0, 30.0], id: \.self) { hertz in
            Text("\(Int(hertz))")
              .font(DeepType.micro)
              .foregroundStyle(.driftGrey)
              .monospacedDigit()
              .position(x: 10, y: yOf(hertz: hertz))
          }
        }
        .frame(width: 20, height: height)
      }

      Explainer("Time runs left to right, frequency bottom to top on a log scale, darker is more power (tilted to undo the natural fall-off at higher frequencies). Look for the alpha band, 8 to 13 Hz, darkening as you settle. Thin vertical streaks up high are jaw clenches.")
    }
    .padding(20)
    .frostedCard()
  }

  private func yOf(hertz: Double) -> CGFloat {
    height * (1 - ScienceDigest.logPosition(of: hertz))
  }
}

/// Time in each phase, as a halo of shares.
private struct PhasesCard: View {
  let digest: ScienceDigest

  var body: some View {
    let summary = digest.summary
    let phases = MeditationPhase.allCases.filter { (summary.timeInPhase[$0] ?? 0) > 0 }
    let total = max(summary.timeInPhase.values.reduce(0, +), 1)
    HStack(alignment: .top, spacing: 16) {
      ZStack {
        CompassionRing(
          segments: phases.map { RingSegment(share: (summary.timeInPhase[$0] ?? 0) / total, colors: [$0.tint, $0.tint]) },
          lineWidth: 10
        )
        VStack(spacing: 0) {
          Text("\(summary.wanderEpisodes)")
            .font(DeepType.counter)
            .foregroundStyle(.deepPlum)
            .monospacedDigit()
          Text(summary.wanderEpisodes == 1 ? "wander" : "wanders")
            .font(DeepType.micro)
            .foregroundStyle(.driftGrey)
        }
      }
      .frame(width: 96, height: 96)

      VStack(alignment: .leading, spacing: 5) {
        Text("Time in each phase".uppercased())
          .font(DeepType.micro)
          .tracking(.microTracking)
          .foregroundStyle(.driftGrey)
        Text("Phases")
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
        ForEach(phases) { phase in
          Fact(value: clock(summary.timeInPhase[phase] ?? 0), label: phase.label.lowercased(), dot: phase.tint)
        }
        Explainer("Read from your EEG, not the clock: deep calm is high alpha with rising theta, wandering is when beta takes over.")
          .padding(.top, 4)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(20)
    .frostedCard()
  }
}

/// Heart rate from PPG and stillness from the accelerometer.
private struct BodyCard: View {
  let digest: ScienceDigest

  var body: some View {
    let summary = digest.summary
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 5) {
        CardTitle(eyebrow: "Heart and stillness · PPG + motion", title: "Your body")
        Fact(
          value: "\(Int(summary.heartRateStart.rounded())) → \(Int(summary.heartRateEnd.rounded())) bpm",
          label: "heart rate, first minute to last"
        )
        Fact(value: "\(Int((summary.averageStillness * 100).rounded()))%", label: "still on average")
      }

      Canvas { context, size in
        let values = digest.heartRate
        guard let low = values.min(), let high = values.max(), values.count > 1 else { return }
        let span = max(high - low, 1)
        var line = Path()
        for (index, value) in values.enumerated() {
          let point = CGPoint(
            x: size.width * Double(index) / Double(values.count - 1),
            y: 4 + (size.height - 8) * (1 - (value - low) / span)
          )
          if index == 0 { line.move(to: point) } else { line.addLine(to: point) }
        }
        var fill = line
        fill.addLine(to: CGPoint(x: size.width, y: size.height))
        fill.addLine(to: CGPoint(x: 0, y: size.height))
        fill.closeSubpath()
        context.fill(fill, with: .linearGradient(
          Gradient(colors: [Color.blushPowder.opacity(0.55), Color.blushPowder.opacity(0)]),
          startPoint: .zero,
          endPoint: CGPoint(x: 0, y: size.height)
        ))
        context.stroke(line, with: .color(.duskRose.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
      }
      .frame(height: 48)

      MinuteAxis()

      Explainer("A slowing heart and a stiller body usually travel with the brain settling. Bumps line up with the moments your mind wandered.")
    }
    .padding(20)
    .frostedCard()
  }
}

/// Blinks and clenches: real signals, but from muscle, not the brain.
private struct MuscleCard: View {
  let digest: ScienceDigest

  var body: some View {
    let summary = digest.summary
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 5) {
        CardTitle(eyebrow: "Artifacts · eyes and jaw", title: "Muscle, not mind")
        Fact(value: "\(summary.blinks)", label: "blinks", dot: EEGArtifactKind.blink.tint)
        Fact(
          value: "\(formatRate(digest.blinksPerMinuteStart)) → \(formatRate(digest.blinksPerMinuteEnd))",
          label: "blinks a minute, start to end"
        )
        if summary.jawClenches > 0 {
          Fact(
            value: "\(summary.jawClenches)",
            label: summary.jawClenches == 1 ? "jaw clench" : "jaw clenches",
            dot: EEGArtifactKind.jawClench.tint
          )
        }
      }

      Canvas { context, size in
        for event in digest.events {
          let x: CGFloat = size.width * event.time / EEGSessionRecording.duration
          switch event.kind {
          case .blink:
            context.fill(
              Path(ellipseIn: CGRect(x: x - 2, y: size.height * 0.3 - 2, width: 4, height: 4)),
              with: .color(EEGArtifactKind.blink.tint.opacity(0.75))
            )
          case .jawClench:
            context.fill(
              Path(ellipseIn: CGRect(x: x - 4, y: size.height * 0.75 - 4, width: 8, height: 8)),
              with: .color(EEGArtifactKind.jawClench.tint)
            )
          }
        }
      }
      .frame(height: 26)

      MinuteAxis()

      Explainer("The headband hears your eyelids and jaw far louder than your brain. A blink swells delta and a clench swells gamma and beta for a moment, so a spike right after one is muscle, not mind. Fewer as the sit goes on is your body settling too.")
    }
    .padding(20)
    .frostedCard()
  }

  private func formatRate(_ value: Double) -> String {
    value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
  }
}

private struct HonestNoteCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      CardTitle(eyebrow: "What this is, and isn't", title: "An honest note")
      Explainer("Muse 2 is a consumer headband with four dry sensors, two on the forehead and two behind the ears. It reads broad rhythms well, fine detail poorly, and can't see deeper parts of the brain.")
      Explainer("These numbers describe this one sit, not your health or how good you are at meditating. DEEP's calm index is our own measure from alpha and beta, not Muse's score. This is not a medical device and it doesn't diagnose anything.")
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frostedCard()
  }
}

// MARK: - Previews

#Preview("Live") {
  let player = EEGSessionPlayer(recording: .fixture(.regular), startAt: 200)
  EEGScientificView(player: player, stage: .live)
    .onAppear { player.start() }
}

#Preview("After") {
  EEGScientificView(player: EEGSessionPlayer(recording: .fixture(.regular)), stage: .after)
}

#Preview("After · first time") {
  EEGScientificView(player: EEGSessionPlayer(recording: .fixture(.firstTime)), stage: .after)
}
#endif
