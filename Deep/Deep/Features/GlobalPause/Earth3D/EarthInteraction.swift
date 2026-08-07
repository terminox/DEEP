import UIKit
import simd

/// Owns the orb's orientation state: drag-driven yaw/pitch, momentum decay,
/// idle Lissajous drift, and tap raycast → country resolution.
///
/// The renderer asks for `orientationMatrix(time:)` each frame; touch events
/// arrive from EarthMTKView.
@MainActor
final class EarthInteraction {

  // MARK: - Configuration

  /// Damping applied per render frame. ~0.92 ≈ "globe on bearings" friction.
  var damping: Float = 0.92
  /// Sensitivity (radians per point of drag).
  var dragSensitivity: Float = 0.006
  /// Seconds of no input before idle drift takes over.
  var idleAfterSeconds: TimeInterval = 2.0
  /// Idle drift base angular speed (radians/sec). Slow — design system mandate.
  var idleDriftSpeed: Float = 0.05

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
  private var orientAnimation: (from: simd_quatf, to: simd_quatf, startTime: TimeInterval?, duration: TimeInterval)?

  /// Gently rotates the globe so the given lat/lon faces the camera, north
  /// kept up. Used when the session lands: the world turns to *you*.
  ///
  /// Target derivation: yaw −lon brings the point's meridian to the front,
  /// then pitch +lat lifts it to dead center — `T·p = (0,0,1)`. The axial
  /// tilt composed at render time is a Z-rotation, which leaves the front
  /// axis fixed, so the point stays centered after tilt.
  func orient(toLatDeg lat: Float, lonDeg lon: Float, over duration: TimeInterval = 2.5) {
    let latR = lat * .pi / 180
    let lonR = lon * .pi / 180
    let target = simd_quatf(angle: latR, axis: SIMD3<Float>(1, 0, 0))
      * simd_quatf(angle: -lonR, axis: SIMD3<Float>(0, 1, 0))
    orientAnimation = (from: orientation, to: target, startTime: nil, duration: duration)
  }

  // MARK: - State

  /// Current orientation (sphere-local rotation), composed with axial tilt at render time.
  private var orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
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

    // Turn-to-place animation: slerp on the same smoothstep ease as the gate.
    if var anim = orientAnimation {
      let start = anim.startTime ?? time
      if anim.startTime == nil {
        anim.startTime = start
        orientAnimation = anim
      }
      if anim.duration <= 0 {
        orientation = anim.to
        orientAnimation = nil
      } else {
        let t = Float(min(1, max(0, (time - start) / anim.duration)))
        let eased = t * t * (3 - 2 * t)
        orientation = simd_normalize(simd_slerp(anim.from, anim.to, eased))
        if t >= 1 { orientAnimation = nil }
      }
    }

    // Apply momentum, gated.
    if simd_length(momentum) > 0.0001 {
      let yaw = momentum.x * dt * driveGate
      let pitch = momentum.y * dt * driveGate
      applyAngularDelta(yaw: yaw, pitch: pitch)
      // Frame-rate-independent damping: convert per-frame 0.92 → per-second.
      let perSecondDamping = powf(damping, 60.0)
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
    // original `sin(t · 0.097) · 0.04` sweep. Gated: while held the gate is 0,
    // so drift cannot restart regardless of how long the globe idles.
    let idleFor = time - lastInteractionTime
    if idleFor > idleAfterSeconds, dt > 0, driveGate > 0 {
      let strength = min(1.0, Float(idleFor - idleAfterSeconds) / 1.5)
      let yaw = idleDriftSpeed * dt * strength * driveGate
      let pitch = cos(Float(time) * 0.097) * 0.04 * 0.097 * dt * strength * driveGate
      applyAngularDelta(yaw: yaw, pitch: pitch)
    }
  }

  private func applyAngularDelta(yaw: Float, pitch: Float) {
    let qYaw = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
    let qPitch = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
    orientation = simd_normalize(qYaw * orientation * qPitch)
  }

  // MARK: - Touch handling (called by EarthMTKView)

  func touchBegan(at point: CGPoint, viewSize: CGSize) {
    lastTouchPoint = point
    momentum = .zero
    // A grabbing finger cancels any in-flight turn-to-place.
    orientAnimation = nil
    lastInteractionTime = lastFrameTime ?? 0
  }

  func touchMoved(to point: CGPoint, viewSize: CGSize) {
    guard let prev = lastTouchPoint else { return }
    let dx = Float(point.x - prev.x)
    let dy = Float(point.y - prev.y)
    lastTouchPoint = point

    let yaw = dx * dragSensitivity
    let pitch = dy * dragSensitivity
    applyAngularDelta(yaw: yaw, pitch: pitch)

    // Track instantaneous velocity for post-release momentum.
    // Convert drag/frame → radians/sec assuming ~120Hz touch sampling.
    dragVelocity = SIMD2<Float>(yaw, pitch) * 60.0
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
