import SwiftUI
import MetalKit

/// SwiftUI bridge for an MTKView that hosts the EarthRenderer.
///
/// We do not use RealityKit's CustomMaterial here. The orb needs a single
/// custom Metal pipeline with: a per-frame uniform struct, an arbitrary-sized
/// glow source buffer, a post-process bloom pass, and direct touch handling.
/// Going straight to MTKView gives all of that without bridging gymnastics.
struct EarthMetalView: UIViewRepresentable {
  let renderer: EarthRenderer
  let interaction: EarthInteraction

  func makeUIView(context: Context) -> EarthMTKView {
    EarthMTKView.configured(renderer: renderer, interaction: interaction)
  }

  func updateUIView(_ uiView: EarthMTKView, context: Context) {
    uiView.interaction = interaction
  }
}

/// MTKView subclass that forwards touches to EarthInteraction.
///
/// We override touchesBegan/Moved/Ended (instead of using a SwiftUI DragGesture
/// outside the view) so we receive precise touch locations in the MTKView's
/// own coordinate space — needed for the tap raycast against the sphere.
final class EarthMTKView: MTKView {
  weak var interaction: EarthInteraction?

  /// The one blessed configuration for an Earth Metal view, shared by the
  /// SwiftUI bridge above and the UIKit `EarthSceneView`.
  static func configured(renderer: EarthRenderer, interaction: EarthInteraction) -> EarthMTKView {
    let view = EarthMTKView(frame: .zero, device: renderer.device)
    view.delegate = renderer
    view.colorPixelFormat = .bgra8Unorm
    view.depthStencilPixelFormat = .invalid
    view.framebufferOnly = false
    view.isOpaque = false
    view.backgroundColor = .clear
    view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    view.preferredFramesPerSecond = 120
    view.enableSetNeedsDisplay = false
    view.isPaused = false
    view.interaction = interaction
    view.isMultipleTouchEnabled = false
    return view
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    interaction?.touchBegan(at: touch.location(in: self), viewSize: bounds.size)
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    interaction?.touchMoved(to: touch.location(in: self), viewSize: bounds.size)
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    interaction?.touchEnded(at: touch.location(in: self), viewSize: bounds.size)
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    interaction?.touchCancelled()
  }
}
