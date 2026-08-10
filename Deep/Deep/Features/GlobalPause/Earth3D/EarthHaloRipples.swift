import SwiftUI
import simd

/// Per-join ring effects, rendered as SwiftUI overlays projected from the
/// orb's surface to screen space. Drawn above the MTKView (not in the shader)
/// so we can use SwiftUI's blur + opacity stack for a soft watercolor ring
/// — cheaper and easier to tune than a custom shader pass for sparse events.
@MainActor
@Observable
final class EarthHaloRipples {

  struct Ripple: Identifiable {
    let id = UUID()
    let position: SIMD3<Float>   // unit vector on sphere (sphere-local)
    /// On the `CACurrentMediaTime()` clock — the one clock every ripple
    /// timestamp shares (emit, tick, and the overlay's draw all use it; the
    /// renderer's relative frame clock must never leak in here).
    let startedAt: TimeInterval
  }

  private(set) var active: [Ripple] = []

  /// Emit + draw constants, grouped for the DEBUG panel (uniform reset/export).
  struct Tuning {
    /// Cap on simultaneous rings. The event is *ambient*, not a leaderboard —
    /// floods should not turn the orb into a fireworks display.
    var globalCap: Int = 8
    /// Spatial cooldown: a second ring within this window and angular distance
    /// of a recent one is suppressed, so a burst of same-city joins reads as
    /// one ring, not a strobe.
    var spatialCooldown: TimeInterval = 0.3
    /// Ring lifetime.
    var lifetime: TimeInterval = 1.2
    /// Angular distance (degrees) under which a repeat emit is suppressed.
    var cooldownAngleDegrees: Float = 3
    /// Ring sweep, as fractions of the orb's on-screen radius — rings are
    /// local to the join point, not orb-scale halos.
    var ringStartRadius: Float = 0.05
    var ringEndRadius: Float = 0.32
    var ringOpacity: Float = 0.7
  }

  var tuning = Tuning()

  private var recentEmits: [(position: SIMD3<Float>, at: TimeInterval)] = []

  /// Call when someone joined at these coordinates.
  func emit(lat: Float, lon: Float, at time: TimeInterval = CACurrentMediaTime()) {
    let position = sphereUnitVector(latDeg: lat, lonDeg: lon)
    let cooldownCos = cosf(tuning.cooldownAngleDegrees * .pi / 180)
    recentEmits.removeAll { time - $0.at > tuning.spatialCooldown }
    if recentEmits.contains(where: { simd_dot($0.position, position) > cooldownCos }) { return }
    if active.count >= tuning.globalCap { active.removeFirst() }
    active.append(Ripple(position: position, startedAt: time))
    recentEmits.append((position, time))
  }

  /// Remove expired ripples. Called from the host on each frame — pass
  /// `CACurrentMediaTime()`, not the renderer's relative frame time, so the
  /// cutoff compares against the same clock `startedAt` was stamped with.
  func tick(time: TimeInterval = CACurrentMediaTime()) {
    let cutoff = time - tuning.lifetime
    active.removeAll { $0.startedAt < cutoff }
  }
}

/// SwiftUI overlay that projects ripples from sphere-local space to view space
/// and draws each as a soft expanding ring.
struct EarthHaloRipplesOverlay: View {
  let ripples: EarthHaloRipples
  let orientationProvider: () -> simd_float4x4
  /// View-space half-extent of the orb (radius in points). The host computes this
  /// from the MTKView's frame so projection matches what the shader draws.
  let viewRadius: CGFloat

  var body: some View {
    TimelineView(.animation) { context in
      // The timeline only drives invalidation; ages are measured on the
      // CACurrentMediaTime clock so they line up with `Ripple.startedAt`
      // (context.date is wall time — a different epoch entirely).
      let _ = context.date
      let now = CACurrentMediaTime()
      Canvas { ctx, size in
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let orient = orientationProvider()
        let tiltAndOrient = orient   // already composed by EarthInteraction

        for ripple in ripples.active {
          let age = now - ripple.startedAt
          guard age >= 0, age <= ripples.tuning.lifetime else { continue }

          // Sphere-local → world (apply orientation), then orthographic project to XY.
          let local = SIMD4<Float>(ripple.position.x, ripple.position.y, ripple.position.z, 0)
          let world = tiltAndOrient * local
          // Cull rings on the back hemisphere — they read as ghosts otherwise.
          if world.z < -0.1 { continue }
          let visibility = smoothstepF(-0.1, 0.25, world.z)

          let progress = Float(age / ripples.tuning.lifetime)   // 0 → 1
          // Rings are local to the join point, not orb-scale halos — a person
          // joins a *place*, and the ring should read at that place.
          let radius = mixF(ripples.tuning.ringStartRadius, ripples.tuning.ringEndRadius,
                            easeOutCubic(progress)) * Float(viewRadius)
          let opacity = mixF(ripples.tuning.ringOpacity, 0.0, progress) * visibility

          let px = center.x + CGFloat(world.x) * viewRadius
          let py = center.y - CGFloat(world.y) * viewRadius

          var ring = Path()
          ring.addEllipse(in: CGRect(
            x: px - CGFloat(radius),
            y: py - CGFloat(radius),
            width: CGFloat(radius * 2),
            height: CGFloat(radius * 2)
          ))
          let color = Color.lavenderMist.opacity(Double(opacity))
          ctx.stroke(ring, with: .color(color), lineWidth: 1.4)

          // Inner softer ring for depth.
          var inner = Path()
          let innerR = radius * 0.85
          inner.addEllipse(in: CGRect(
            x: px - CGFloat(innerR),
            y: py - CGFloat(innerR),
            width: CGFloat(innerR * 2),
            height: CGFloat(innerR * 2)
          ))
          ctx.stroke(inner, with: .color(Color.blushPowder.opacity(Double(opacity) * 0.5)), lineWidth: 0.8)
        }
      }
      .blur(radius: 0.6)
      .allowsHitTesting(false)
    }
  }
}

// MARK: - Local math helpers

private func mixF(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }
private func easeOutCubic(_ t: Float) -> Float {
  let u = 1 - t
  return 1 - u * u * u
}
private func smoothstepF(_ e0: Float, _ e1: Float, _ x: Float) -> Float {
  let t = max(0, min(1, (x - e0) / (e1 - e0)))
  return t * t * (3 - 2 * t)
}
