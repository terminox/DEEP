import UIKit
import simd

/// Owns the orb's orientation state: drag-driven yaw/pitch, momentum decay,
/// idle Lissajous drift, and tap raycast → country resolution.
///
/// North-up model: orientation is *derived* from two scalars — `pitch` about
/// the world/camera X axis, then `yaw` about the globe's polar Y axis. Two
/// degrees of freedom means roll is structurally impossible: vertical drag
/// always tilts toward/away from a pole, horizontal drag always spins, and
/// no drag sequence can tumble the globe sideways. Pitch is clamped short of
/// ±90° so the composition never gimbal-flips.
///
/// The renderer asks for `orientationMatrix(time:)` each frame; touch events
/// arrive from EarthMTKView.
@MainActor
final class EarthInteraction {

  // MARK: - Configuration

  /// Feel parameters, grouped so the DEBUG panel gets uniform reset/export.
  struct Tuning: Codable, Equatable {
    /// Damping applied per render frame. ~0.92 ≈ "globe on bearings" friction.
    var damping: Float = 0.92
    /// Dimensionless drag gain. 1.0 = arc-length-correct: the surface point
    /// under the finger tracks the finger (at orb center) regardless of the
    /// view's size, because deltas are normalized by the orb's pixel radius.
    var dragGain: Float = 1.0
    /// Max tilt toward either pole, in degrees. Keeps a sliver of
    /// over-the-pole context and prevents gimbal flip at exactly 90°.
    var pitchLimitDegrees: Float = 85
    /// Seconds of no input before idle drift takes over.
    var idleAfterSeconds: TimeInterval = 2.0
    /// Idle drift base angular speed (radians/sec). Slow — design system mandate.
    var idleDriftSpeed: Float = 0.05
  }

  var tuning = Tuning()

  // MARK: - Spin state (decelerate / hold / resume)

  /// Whether the globe is allowed to drive itself. `.held` from the moment a
  /// deceleration is *requested* — the gate may still be easing shut, but the
  /// intent is held, and callers branch on intent (a session phase asking to
  /// still the globe should read `.held` immediately, not after 5 seconds).
  enum SpinState { case free, held }
  private(set) var spinState: SpinState = .free

  /// 0…1 multiplier on self-driven motion (idle drift + post-flick momentum).
  /// 1 = free spin, 0 = held. Finger drags always pass through — holding
  /// stills the globe, it doesn't lock it under the user's touch.
  private var driveGate: Float = 1
  /// In-flight gate ease. `startTime` stays nil until the first `advance`
  /// after the request anchors it: the renderer's frame clock is the only
  /// clock this class may consult (no Date()/CACurrentMediaTime() here), and
  /// that clock is only observable inside `advance`.
  private var gateAnimation: (from: Float, to: Float, startTime: TimeInterval?, duration: TimeInterval)?

  /// Eases self-driven motion to a stop and holds it there. While held, idle
  /// drift never restarts no matter how long the globe sits untouched, and a
  /// flick's momentum dies with the gate. Idempotent: re-requesting while
  /// already decelerating or held is a no-op (no retarget glitch).
  func decelerateToRest(over duration: TimeInterval = 5) {
    spinState = .held
    if let anim = gateAnimation, anim.to == 0 { return }
    if gateAnimation == nil, driveGate == 0 { return }
    gateAnimation = (from: driveGate, to: 0, startTime: nil, duration: duration)
  }

  /// Eases the gate back open and returns to free spin (drift + momentum).
  /// Idempotent, mirroring `decelerateToRest`; retargets from the current
  /// gate value if called mid-deceleration, so the reversal is seamless.
  func resumeSpin(over duration: TimeInterval = 3) {
    spinState = .free
    if let anim = gateAnimation, anim.to == 1 { return }
    if gateAnimation == nil, driveGate == 1 { return }
    gateAnimation = (from: driveGate, to: 1, startTime: nil, duration: duration)
  }

  // MARK: - Programmatic orientation (turn the globe to a place)

  /// In-flight turn-to-place animation, eased in `advance` on the frame clock
  /// like `gateAnimation`. A grabbing finger cancels it — the user always wins.
  private var orientAnimation:
    (fromYaw: Float, fromPitch: Float, toYaw: Float, toPitch: Float,
     startTime: TimeInterval?, duration: TimeInterval)?

  /// Gently rotates the globe so the given lat/lon faces the camera, north
  /// kept up. Used when the session lands: the world turns to *you*.
  ///
  /// Target derivation: yaw −lon brings the point's meridian to the front,
  /// then pitch +lat lifts it to dead center — `T·p = (0,0,1)`. The axial
  /// tilt composed at render time is a Z-rotation, which leaves the front
  /// axis fixed, so the point stays centered after tilt. Yaw lands on the
  /// equivalent angle nearest the current one (shortest path — never a
  /// multi-revolution spin to a neighboring longitude).
  func orient(toLatDeg lat: Float, lonDeg lon: Float, over duration: TimeInterval = 2.5) {
    let targetPitch = clampPitch(lat * .pi / 180)
    let yawDelta = (-lon * .pi / 180 - yaw).remainder(dividingBy: 2 * .pi)
    orientAnimation = (fromYaw: yaw, fromPitch: pitch,
                       toYaw: yaw + yawDelta, toPitch: targetPitch,
                       startTime: nil, duration: duration)
    // The turn owns the view: a leftover flick must not sit out the animation
    // undamped and replay against the target when it completes.
    momentum = .zero
  }

  // MARK: - State

  /// North-up view state (sphere-local, composed with axial tilt at render
  /// time). Pitch tilts about the world X axis, yaw spins about the polar Y
  /// axis; the quaternion is derived, never stored, so the two scalars are
  /// the whole truth about where the user is looking.
  private var yaw: Float = 0            // radians; wrapped to (-π, π] when free
  private var pitch: Float = 0          // radians; clamped to ±pitchLimit

  private var orientation: simd_quatf {
    simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
      * simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
  }

  private var pitchLimit: Float { tuning.pitchLimitDegrees * .pi / 180 }

  private func clampPitch(_ value: Float) -> Float {
    min(max(value, -pitchLimit), pitchLimit)
  }

  /// The orb's on-screen radius in points — the normalization that makes
  /// `dragGain 1.0` mean "the surface tracks the finger" at every view size.
  private func orbPixelRadius(viewSize: CGSize) -> Float {
    max(1, EarthRendererConstants.orbScreenRadiusFractionOfHeight * Float(viewSize.height))
  }
  /// Active drag delta (cleared on touch end).
  private var dragVelocity = SIMD2<Float>(0, 0)
  /// Continuing post-release momentum (radians/sec in yaw, pitch).
  private var momentum = SIMD2<Float>(0, 0)
  /// Last frame timestamp for dt computation.
  private var lastFrameTime: TimeInterval?
  /// Last interaction timestamp (for idle detection).
  private var lastInteractionTime: TimeInterval = 0
  /// Last touch point (in view coordinates) — for delta tracking during drag.
  private var lastTouchPoint: CGPoint?

  // MARK: - Tap callback

  /// Called when a tap resolves to a country. Surfaces the name to SwiftUI for display.
  var onCountryTap: ((CountryLookup.Country) -> Void)?
  private let lookup = CountryLookup.shared

  // MARK: - Public API used by EarthRenderer

  /// Composed rotation matrix: axial tilt × user orientation.
  ///
  /// Idle drift is integrated INTO `orientation` (see `advance`), never
  /// composed on top of it. Two bugs live in the composed-on-top design: the
  /// tap raycast inverts an orientation the renderer never showed (so after a
  /// minute of drift, taps resolve continents away), and touching the globe
  /// snaps the accumulated drift to zero (the globe teleports under the
  /// finger).
  func orientationMatrix(time: Float) -> simd_float4x4 {
    advance(time: TimeInterval(time))
    let tilt = simd_float4x4(rotationAroundZ: EarthRendererConstants.axialTiltRadians)
    return tilt * simd_float4x4(orientation)
  }

  /// The composed rotation as last advanced — WITHOUT stepping the simulation.
  /// Overlays (ripple projection) that sample orientation outside the
  /// renderer's frame callback must use this: calling `orientationMatrix` from
  /// a second call site would feed `advance` a second clock and corrupt dt.
  var currentOrientationMatrix: simd_float4x4 {
    let tilt = simd_float4x4(rotationAroundZ: EarthRendererConstants.axialTiltRadians)
    return tilt * simd_float4x4(orientation)
  }

  // MARK: - Per-frame integration

  private func advance(time: TimeInterval) {
    let dt: Float
    if let prev = lastFrameTime {
      dt = Float(time - prev)
    } else {
      dt = 0
    }
    lastFrameTime = time

    // Ease the drive gate on the frame clock. The first frame after a
    // decelerate/resume request anchors the animation's start time — the
    // request itself never reads a clock.
    if var anim = gateAnimation {
      let start = anim.startTime ?? time
      if anim.startTime == nil {
        anim.startTime = start
        gateAnimation = anim
      }
      if anim.duration <= 0 {
        driveGate = anim.to
        gateAnimation = nil
      } else {
        let t = Float(min(1, max(0, (time - start) / anim.duration)))
        // Smoothstep: gentle at both ends, so the hold arrives like a breath
        // settling rather than a brake.
        let eased = t * t * (3 - 2 * t)
        driveGate = anim.from + (anim.to - anim.from) * eased
        if t >= 1 { gateAnimation = nil }
      }
    }

    // Turn-to-place animation: lerp the two scalars on the same smoothstep
    // ease as the gate. Momentum and drift are skipped while it owns the view
    // (they'd silently lose to the overwrite anyway — an explicit skip avoids
    // a last-frame pop).
    if var anim = orientAnimation {
      let start = anim.startTime ?? time
      if anim.startTime == nil {
        anim.startTime = start
        orientAnimation = anim
      }
      if anim.duration <= 0 {
        yaw = anim.toYaw
        pitch = anim.toPitch
        orientAnimation = nil
        lastInteractionTime = time
      } else {
        let t = Float(min(1, max(0, (time - start) / anim.duration)))
        let eased = t * t * (3 - 2 * t)
        yaw = anim.fromYaw + (anim.toYaw - anim.fromYaw) * eased
        pitch = anim.fromPitch + (anim.toPitch - anim.fromPitch) * eased
        if t >= 1 {
          orientAnimation = nil
          // The world just turned to the target — idle drift waits a full
          // idleAfterSeconds before wandering off it.
          lastInteractionTime = time
        }
      }
      return
    }

    // Apply momentum, gated. Clamp contact kills the pitch component so a
    // vertical flick lands at the pole and rests there instead of straining
    // against the limit.
    if simd_length(momentum) > 0.0001 {
      yaw += momentum.x * dt * driveGate
      let target = pitch + momentum.y * dt * driveGate
      let clamped = clampPitch(target)
      if clamped != target { momentum.y = 0 }
      pitch = clamped
      // Frame-rate-independent damping: convert per-frame 0.92 → per-second.
      let perSecondDamping = powf(tuning.damping, 60.0)
      momentum *= powf(perSecondDamping, dt)
      // A closing gate also bleeds the momentum *store* (frame-rate
      // independent "× gate per 60Hz frame"), so a flick thrown during
      // deceleration is dead by the time the globe holds — it must not sit
      // behind the gate waiting to replay on resume.
      if driveGate < 1, dt > 0 {
        momentum *= powf(max(driveGate, 0), dt * 60)
      }
    } else {
      momentum = .zero
    }

    // Idle Lissajous drift, integrated incrementally. Prime-ratio periods so
    // the loop never visibly repeats; the pitch term is the derivative of the
    // original `sin(t · 0.097) · 0.04` sweep, absorbed by the clamp near a
    // pole (yaw drift still orbits it). Gated: while held the gate is 0, so
    // drift cannot restart regardless of how long the globe idles.
    let idleFor = time - lastInteractionTime
    if idleFor > tuning.idleAfterSeconds, dt > 0, driveGate > 0 {
      let strength = min(1.0, Float(idleFor - tuning.idleAfterSeconds) / 1.5)
      yaw += tuning.idleDriftSpeed * dt * strength * driveGate
      pitch = clampPitch(pitch + cos(Float(time) * 0.097) * 0.04 * 0.097 * dt * strength * driveGate)
    }

    // Precision hygiene: yaw is unbounded under drift. Wrapping is safe here
    // because no orient animation owns the value (wrapping mid-animation
    // would fight its absolute from/to endpoints).
    yaw = yaw.remainder(dividingBy: 2 * .pi)
  }

  // MARK: - Touch handling (called by EarthMTKView)

  func touchBegan(at point: CGPoint, viewSize: CGSize) {
    lastTouchPoint = point
    momentum = .zero
    lastInteractionTime = lastFrameTime ?? 0
  }

  func touchMoved(to point: CGPoint, viewSize: CGSize) {
    guard let prev = lastTouchPoint else { return }
    let dx = Float(point.x - prev.x)
    let dy = Float(point.y - prev.y)
    lastTouchPoint = point
    // A *dragging* finger cancels any in-flight turn-to-place — but a mere
    // tap (touchBegan with no movement) must not, or a stray tap on the orb
    // kills the "turn to you" mid-flight.
    orientAnimation = nil

    let radiansPerPoint = tuning.dragGain / orbPixelRadius(viewSize: viewSize)
    let dYaw = dx * radiansPerPoint
    let newPitch = clampPitch(pitch + dy * radiansPerPoint)
    // The *applied* pitch delta, not the requested one — releasing while
    // pinned at the clamp must store zero vertical momentum, not a ghost
    // flick straining against the pole.
    let dPitch = newPitch - pitch
    yaw += dYaw
    pitch = newPitch

    // Track instantaneous velocity for post-release momentum.
    // Convert drag/frame → radians/sec assuming ~60Hz touch delivery.
    dragVelocity = SIMD2<Float>(dYaw, dPitch) * 60.0
    lastInteractionTime = lastFrameTime ?? 0
  }

  func touchEnded(at point: CGPoint, viewSize: CGSize) {
    momentum = dragVelocity
    dragVelocity = .zero

    // If the drag was effectively a tap (negligible movement), try to resolve a country.
    let total = lastTouchPoint.map { hypot($0.x - point.x, $0.y - point.y) } ?? 0
    if total < 6 {
      handleTap(at: point, viewSize: viewSize)
    }
    lastTouchPoint = nil
    lastInteractionTime = lastFrameTime ?? 0
  }

  func touchCancelled() {
    lastTouchPoint = nil
    dragVelocity = .zero
  }

  // MARK: - Tap → country raycast

  private func handleTap(at point: CGPoint, viewSize: CGSize) {
    guard viewSize.width > 0, viewSize.height > 0 else { return }

    // NDC: x in [-1, 1] left→right, y in [-1, 1] bottom→top.
    let ndcX = Float((point.x / viewSize.width) * 2 - 1)
    let ndcY = Float(1 - (point.y / viewSize.height) * 2)
    let aspect = Float(viewSize.width / viewSize.height)
    let tanHalfFov = tan(EarthRendererConstants.cameraFovYRadians * 0.5)

    // Build a world-space ray from the camera through the picked NDC point.
    // Camera is at (0, 0, +cameraDistance) looking down -Z.
    let rayDir = simd_normalize(SIMD3<Float>(
      ndcX * aspect * tanHalfFov,
      ndcY * tanHalfFov,
      -1
    ))
    let rayOrigin = SIMD3<Float>(0, 0, EarthRendererConstants.cameraDistance)

    // Intersect ray with the orb's sphere (centered at origin, radius R).
    let r = EarthRendererConstants.sphereRadius
    let b = simd_dot(rayDir, rayOrigin)
    let c = simd_dot(rayOrigin, rayOrigin) - r * r
    let disc = b * b - c
    guard disc >= 0 else { return }
    let t = -b - sqrt(disc)
    guard t > 0 else { return }

    let hitWorld = rayOrigin + rayDir * t
    let hitLocal = inverseOrientationMatrix() * SIMD4<Float>(hitWorld.x, hitWorld.y, hitWorld.z, 1)
    let hitNormal = simd_normalize(SIMD3<Float>(hitLocal.x, hitLocal.y, hitLocal.z))

    let (lat, lon) = latLon(from: hitNormal)
    if let country = lookup.nearestCountry(lat: lat, lon: lon, withinDegrees: 6) {
      onCountryTap?(country)
    }
  }

  private func inverseOrientationMatrix() -> simd_float4x4 {
    let tilt = simd_float4x4(rotationAroundZ: EarthRendererConstants.axialTiltRadians)
    let orient = simd_float4x4(orientation)
    return (tilt * orient).inverse
  }

  private func latLon(from normal: SIMD3<Float>) -> (lat: Float, lon: Float) {
    let lat = asin(max(-1, min(1, normal.y)))
    let lon = atan2(normal.x, normal.z)
    return (lat * 180 / .pi, lon * 180 / .pi)
  }
}
