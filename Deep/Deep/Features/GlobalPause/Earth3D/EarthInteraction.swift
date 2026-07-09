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

  // MARK: - Per-frame integration

  private func advance(time: TimeInterval) {
    let dt: Float
    if let prev = lastFrameTime {
      dt = Float(time - prev)
    } else {
      dt = 0
    }
    lastFrameTime = time

    // Apply momentum.
    if simd_length(momentum) > 0.0001 {
      let yaw = momentum.x * dt
      let pitch = momentum.y * dt
      applyAngularDelta(yaw: yaw, pitch: pitch)
      // Frame-rate-independent damping: convert per-frame 0.92 → per-second.
      let perSecondDamping = powf(damping, 60.0)
      momentum *= powf(perSecondDamping, dt)
    } else {
      momentum = .zero
    }

    // Idle Lissajous drift, integrated incrementally. Prime-ratio periods so
    // the loop never visibly repeats; the pitch term is the derivative of the
    // original `sin(t · 0.097) · 0.04` sweep.
    let idleFor = time - lastInteractionTime
    if idleFor > idleAfterSeconds, dt > 0 {
      let strength = min(1.0, Float(idleFor - idleAfterSeconds) / 1.5)
      let yaw = idleDriftSpeed * dt * strength
      let pitch = cos(Float(time) * 0.097) * 0.04 * 0.097 * dt * strength
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
