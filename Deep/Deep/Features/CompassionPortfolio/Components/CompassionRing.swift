import SwiftUI

/// One arc of a `CompassionRing`.
struct RingSegment: Equatable {
  /// How much of the whole circle this arc covers, `0...1`. Absolute, not
  /// normalised — an allocation ring passes shares that sum to 1, a progress
  /// ring passes a single arc of `progress`.
  let share: Double
  /// The arc's gradient stops — a cause's `ArtworkPalette.colors`, so an arc
  /// and its motif read as the same thing.
  let colors: [Color]
}

/// The portfolio's signature form: soft gradient arcs riding a faint ring, with
/// a blurred copy of themselves glowing beneath — the halo language DESIGN.md
/// asks for, and the reason this feature needs no bars or rules to show a
/// proportion. Serves both the "where hearts go" allocation halo and a single
/// project's progress.
///
/// Purely a shape: anything at the centre is composed by the caller in a
/// `ZStack`, and the caller owns the accessibility description.
struct CompassionRing: View {
  let segments: [RingSegment]
  var lineWidth: CGFloat = 12
  /// Angular breathing room between arcs, as a fraction of the circle — the gap
  /// you actually see, not the gap that gets trimmed (see `arcs`). A single
  /// progress arc passes `0`.
  var gap: Double = 0.016

  var body: some View {
    ZStack {
      Circle()
        .stroke(.lavenderMist.opacity(0.16), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

      // The bloom: the same arcs, blurred and dimmed, so the ring glows into the
      // card rather than sitting on it.
      arcs
        .blur(radius: lineWidth * 0.6)
        .opacity(0.5)

      arcs
    }
    .padding(lineWidth / 2)
    .animation(.exhale, value: segments)
    .accessibilityHidden(true)
  }

  private var arcs: some View {
    // A `.round` cap overhangs the trimmed end by half the stroke width, so a gap
    // trimmed out of the path is partly drawn back in by the two caps facing across
    // it. At these proportions the caps swallow it whole — neighbouring arcs touch,
    // and five causes read as four. Measure that overhang against the circumference
    // and inset past it, so `gap` means the gap that survives at any size.
    GeometryReader { geo in
      // `body` already inset this by `lineWidth / 2`, so the box handed to us here
      // *is* the stroke's path — its half-width is the radius the arcs ride on.
      let radius = min(geo.size.width, geo.size.height) / 2
      let capBleed = radius > 0 ? (lineWidth / 2) / (2 * .pi * radius) : 0
      let inset = segments.count > 1 ? gap / 2 + capBleed : 0

      ZStack {
        ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
          let start = segments.prefix(index).reduce(0) { $0 + $1.share }
          let from = start + inset
          let to = max(from, start + segment.share - inset)

          Circle()
            .trim(from: from, to: to)
            .stroke(
              LinearGradient(
                colors: segment.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
        }
      }
      .rotationEffect(.degrees(-90))
    }
  }
}

extension Array where Element == RingSegment {
  /// The community's pooled hearts, divided across the causes they went to.
  static func allocation(of categories: [CompassionCategory]) -> [RingSegment] {
    let total = Double(categories.reduce(0) { $0 + $1.heartsShared })
    guard total > 0 else { return [] }
    return categories.map {
      RingSegment(share: Double($0.heartsShared) / total, colors: $0.palette.colors)
    }
  }
}

#if DEBUG
#Preview("Allocation halo") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: .rhythm) {
      ZStack {
        CompassionRing(segments: .allocation(of: CompassionLibrary.categories), lineWidth: 14)
        VStack(spacing: 2) {
          Text(verbatim: "73K")
            .font(DeepType.counter)
            .foregroundStyle(.deepPlum)
          Text("POOLED")
            .font(DeepType.micro)
            .tracking(1.2)
            .foregroundStyle(.driftGrey)
        }
      }
      .frame(width: 140, height: 140)

      // A single progress arc — the same primitive, one segment, no gap.
      ZStack {
        CompassionRing(
          segments: [RingSegment(share: 0.62, colors: ArtworkPalette.bloom.colors)],
          lineWidth: 5,
          gap: 0
        )
        Text(verbatim: "62%")
          .font(DeepType.micro)
          .foregroundStyle(.deepPlum)
      }
      .frame(width: 72, height: 72)
    }
    .padding(.edge)
  }
}
#endif
