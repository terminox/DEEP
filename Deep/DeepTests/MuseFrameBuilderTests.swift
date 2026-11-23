#if EXPERIMENTS
import Foundation
import Testing
@testable import Deep

/// `MuseFrameBuilder` turns the packets a real Muse 2 sends into the frames the art
/// reads. These pin the rules that decide what reaches the art: which channels count,
/// when there is no usable signal, artifacts reported once, heart rate and stillness.
struct MuseFrameBuilderTests {
  /// A builder fed one full set of relative band powers with the given fit.
  private func fed(
    alpha: [Double] = [0.30, 0.30, 0.30, 0.30],
    beta: [Double] = [0.15, 0.15, 0.15, 0.15],
    fit: [Double] = [1, 1, 1, 1],
    at time: Double = 0
  ) -> MuseFrameBuilder {
    var builder = MuseFrameBuilder()
    builder.ingestFit(fit, at: time)
    builder.ingestBand(.alpha, isRelative: true, channels: alpha, at: time)
    builder.ingestBand(.beta, isRelative: true, channels: beta, at: time)
    builder.ingestBand(.theta, isRelative: true, channels: [0.2, 0.2, 0.2, 0.2], at: time)
    builder.ingestBand(.delta, isRelative: true, channels: [0.25, 0.25, 0.25, 0.25], at: time)
    builder.ingestBand(.gamma, isRelative: true, channels: [0.1, 0.1, 0.1, 0.1], at: time)
    return builder
  }

  @Test("Relative band powers average over usable channels and sum to one")
  func averagesUsableChannels() throws {
    var builder = fed()
    let frame = try #require(builder.makeTick(at: 0.1).frame)
    let total = EEGBand.allCases.reduce(0) { $0 + frame.relative[$1] }
    #expect(abs(total - 1) < 1e-9)
    #expect(abs(frame.relative.alpha - 0.30 / 1.0) < 1e-9)
  }

  @Test("A channel reading NaN or a poor fit is left out")
  func dropsBadChannels() throws {
    var builder = fed(alpha: [0.9, .nan, 0.3, 0.3], fit: [4, 1, 1, 1])
    let frame = try #require(builder.makeTick(at: 0.1).frame)
    // TP9 (poor fit) and AF7 (NaN) are ignored: alpha comes from AF8 and TP10 only.
    let expectedAlpha = 0.3 / (0.3 + 0.15 + 0.2 + 0.25 + 0.1)
    #expect(abs(frame.relative.alpha - expectedAlpha) < 1e-9)
  }

  @Test("No usable EEG means no frame: headband off, every sensor lifted, or stale data")
  func noFrameWithoutSignal() {
    var off = fed()
    off.ingestArtifact(headbandOn: false, blink: false, jawClench: false, at: 0)
    #expect(off.makeTick(at: 1.5).frame == nil)

    var lifted = fed(fit: [4, 4, 4, 4])
    #expect(lifted.makeTick(at: 0.1).frame == nil)

    var stale = fed()
    #expect(stale.makeTick(at: 0.5).frame != nil)
    #expect(stale.makeTick(at: 1.2).frame == nil)
  }

  @Test("A blink held across packets is reported once")
  func blinkReportedOnce() {
    var builder = fed()
    builder.ingestArtifact(headbandOn: true, blink: true, jawClench: false, at: 0.05)
    builder.ingestArtifact(headbandOn: true, blink: true, jawClench: false, at: 0.08)
    #expect(builder.makeTick(at: 0.1).artifacts == [.blink])
    builder.ingestArtifact(headbandOn: true, blink: true, jawClench: false, at: 0.15)
    #expect(builder.makeTick(at: 0.2).artifacts.isEmpty)
    builder.ingestArtifact(headbandOn: true, blink: false, jawClench: false, at: 0.25)
    builder.ingestArtifact(headbandOn: true, blink: true, jawClench: false, at: 0.28)
    #expect(builder.makeTick(at: 0.3).artifacts == [.blink])
  }

  @Test("More frontal alpha against beta raises calm")
  func calmFollowsFrontalAlpha() throws {
    var relaxed = fed(alpha: [0.3, 0.45, 0.45, 0.3], beta: [0.1, 0.08, 0.08, 0.1])
    var busy = fed(alpha: [0.3, 0.15, 0.15, 0.3], beta: [0.1, 0.35, 0.35, 0.1])
    var relaxedCalm = 0.0
    var busyCalm = 0.0
    for step in 1...100 {
      let time = Double(step) / 10
      for band in [EEGBand.alpha, .beta] {
        relaxed.ingestBand(band, isRelative: true, channels: band == .alpha ? [0.3, 0.45, 0.45, 0.3] : [0.1, 0.08, 0.08, 0.1], at: time)
        busy.ingestBand(band, isRelative: true, channels: band == .alpha ? [0.3, 0.15, 0.15, 0.3] : [0.1, 0.35, 0.35, 0.1], at: time)
      }
      relaxedCalm = try #require(relaxed.makeTick(at: time).frame).calm
      busyCalm = try #require(busy.makeTick(at: time).frame).calm
    }
    #expect(relaxedCalm > 0.6)
    #expect(busyCalm < 0.1)
  }
}

struct HeartbeatDetectorTests {
  @Test("A clean 72 bpm pulse at 64 Hz locks to 72 ± 3")
  func locksOnSteadyPulse() throws {
    var heart = HeartbeatDetector()
    for sample in 0..<(64 * 20) {
      let time = Double(sample) / 64
      heart.add(1000 + 40 * sin(2 * .pi * 1.2 * time), at: time)
    }
    let bpm = try #require(heart.bpm)
    #expect(abs(bpm - 72) < 3)
  }

  @Test("Noise never locks")
  func noiseDoesNotLock() {
    var heart = HeartbeatDetector()
    var random = SeededRandom(seed: 5)
    for sample in 0..<(64 * 20) {
      heart.add(1000 + 40 * (random.unit() - 0.5), at: Double(sample) / 64)
    }
    #expect(heart.bpm == nil)
  }
}

struct MotionMeterTests {
  @Test("A still head reads still, a shaking one doesn't")
  func stillnessFollowsMotion() {
    var still = MotionMeter()
    var shaking = MotionMeter()
    for sample in 0..<(52 * 5) {
      let time = Double(sample) / 52
      still.add(x: 0, y: 0, z: 1, at: time)
      shaking.add(x: 0.1 * sin(time * 20), y: 0.08 * cos(time * 17), z: 1, at: time)
    }
    #expect(still.stillness > 0.95)
    #expect(shaking.stillness < 0.2)
  }
}

@MainActor
struct LiveSitTests {
  private func tick(_ frame: EEGFrame?) -> HeadbandTick {
    HeadbandTick(frame: frame, artifacts: [], fit: SensorFit(channels: [.good, .good, .good, .good], headbandOn: true))
  }

  @Test("The clock is the data: ten frames make a second, missing frames don't count")
  func clockFollowsFrames() {
    let sit = LiveSit(length: 180)
    let frame = EEGSessionRecording.regular.frames[100]
    for _ in 0..<25 { sit.absorb(tick(frame)) }
    for _ in 0..<10 { sit.absorb(tick(nil)) }
    #expect(sit.elapsed == 2.5)
    #expect(sit.frames.last?.time == 2.4)
  }

  @Test("A sit finishes at its length and takes nothing after")
  func finishesAtLength() {
    let sit = LiveSit.replaying(.regular, length: 180)
    #expect(sit.isFinished)
    #expect(sit.elapsed == 180)
    sit.absorb(tick(EEGSessionRecording.regular.frames[0]))
    #expect(sit.elapsed == 180)
  }

  @Test("Window means from running totals equal a direct average")
  func windowMeans() throws {
    let sit = LiveSit.replaying(.regular, length: 300, upTo: 120)
    let mean = try #require(sit.mean(from: 40, to: 44))
    let window = sit.frames[400..<440]
    let calm = window.map(\.calm).reduce(0, +) / Double(window.count)
    let alpha = window.map(\.relative.alpha).reduce(0, +) / Double(window.count)
    #expect(abs(mean.calm - calm) < 1e-9)
    #expect(abs(mean.powers.alpha - alpha) < 1e-9)
    #expect(sit.mean(from: 200, to: 204).map { _ in true } == nil)
  }
}
#endif
