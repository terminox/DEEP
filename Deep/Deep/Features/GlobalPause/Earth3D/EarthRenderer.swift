import MetalKit
import simd

/// Triple-buffered renderer for the Earth orb.
///
/// Pipelines:
///   - mainPipeline:   raymarches the orb + atmosphere into an offscreen HDR texture
///   - thresholdPipeline: extracts highlights into bloomTexA
///   - blurHPipeline / blurVPipeline: separable gaussian blur (bloomTexA ↔ bloomTexB)
///   - compositePipeline: composites scene + bloom + rim aberration + dither to drawable
///
/// In Phase A we stand the main pipeline up first; the bloom chain comes online
/// in Phase F. The post-process pipelines are nil until then and `draw(in:)`
/// detects that and short-circuits to a single-pass render directly to drawable.
final class EarthRenderer: NSObject, MTKViewDelegate {

  // MARK: - GPU resources

  let device: MTLDevice
  private let commandQueue: MTLCommandQueue
  private let library: MTLLibrary

  private var mainPipeline: MTLRenderPipelineState!
  private var thresholdPipeline: MTLRenderPipelineState?
  private var blurHPipeline: MTLRenderPipelineState?
  private var blurVPipeline: MTLRenderPipelineState?
  private var compositePipeline: MTLRenderPipelineState?

  /// Equirectangular continent map (2048×1024). Black = land, white = ocean
  /// (PBR "specular" polarity — inverted in the shader). Loaded once at init.
  private var continentTexture: MTLTexture?

  // Triple-buffered uniform + glow buffers so the CPU can prepare frame N+1
  // while the GPU is still consuming N. Standard Metal pattern.
  private static let maxInflightFrames = 3
  private let inflightSemaphore = DispatchSemaphore(value: maxInflightFrames)
  private var bufferIndex = 0
  private var uniformBuffers: [MTLBuffer] = []
  private var glowBuffers: [MTLBuffer] = []
  private var tuningBuffers: [MTLBuffer] = []

  // Offscreen targets — created lazily on size change.
  private var sceneTexture: MTLTexture?
  private var bloomTexA: MTLTexture?
  private var bloomTexB: MTLTexture?
  private var currentDrawableSize: CGSize = .zero

  // MARK: - Scene state

  private let startTime = CACurrentMediaTime()
  weak var glowStore: EarthGlowStore?
  weak var interaction: EarthInteraction?
  /// Optional callback invoked once per frame so the SwiftUI host can step
  /// any time-driven state (breath, idle drift). Driven by the MTKView's
  /// display link so it runs at the device's refresh rate without an extra timer.
  var onFrame: ((TimeInterval) -> Void)?

  // MARK: - Init

  init?(glowStore: EarthGlowStore? = nil, interaction: EarthInteraction? = nil) {
    guard let device = MTLCreateSystemDefaultDevice(),
          let queue = device.makeCommandQueue(),
          let library = device.makeDefaultLibrary() else {
      return nil
    }
    self.device = device
    self.commandQueue = queue
    self.library = library
    self.glowStore = glowStore
    self.interaction = interaction
    super.init()

    do {
      try buildMainPipeline()
      try buildPostPipelines()
      buildBuffers()
      loadContinentTexture()
    } catch {
      assertionFailure("EarthRenderer pipeline build failed: \(error)")
      return nil
    }
  }

  private func loadContinentTexture() {
    guard let url = Bundle.main.url(forResource: "earth_specular_2048", withExtension: "jpg") else {
      assertionFailure("earth_specular_2048.jpg not found in bundle")
      return
    }
    let loader = MTKTextureLoader(device: device)
    let options: [MTKTextureLoader.Option: Any] = [
      .SRGB: false,
      .generateMipmaps: true,
      .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
      .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
      .origin: MTKTextureLoader.Origin.topLeft.rawValue,
    ]
    do {
      continentTexture = try loader.newTexture(URL: url, options: options)
      continentTexture?.label = "Earth.ContinentMap"
    } catch {
      assertionFailure("Failed to load continent texture: \(error)")
    }
  }

  // MARK: - Pipeline setup

  private func buildMainPipeline() throws {
    let desc = MTLRenderPipelineDescriptor()
    desc.label = "Earth.Main"
    desc.vertexFunction = library.makeFunction(name: "earthFullscreenVertex")
    desc.fragmentFunction = library.makeFunction(name: "earthSurfaceFragment")
    // HDR target so over-bright continents/rim/specular survive into the
    // bloom chain without clipping to white. The composite pass tonemaps
    // them back into the [0,1] display range while preserving palette hue.
    desc.colorAttachments[0].pixelFormat = .rgba16Float
    desc.colorAttachments[0].isBlendingEnabled = false
    mainPipeline = try device.makeRenderPipelineState(descriptor: desc)
  }

  private func buildPostPipelines() throws {
    // Phase F brings these online. If any function is missing in the library,
    // we silently leave the post chain disabled and render direct-to-drawable.
    let vfn = library.makeFunction(name: "earthFullscreenVertex")
    let threshFn = library.makeFunction(name: "earthBloomThresholdFragment")
    let blurHFn = library.makeFunction(name: "earthBloomBlurHFragment")
    let blurVFn = library.makeFunction(name: "earthBloomBlurVFragment")
    let compFn = library.makeFunction(name: "earthCompositeFragment")
    guard let vfn, let threshFn, let blurHFn, let blurVFn, let compFn else { return }

    func make(_ name: String, fragment: MTLFunction, pixelFormat: MTLPixelFormat) throws -> MTLRenderPipelineState {
      let desc = MTLRenderPipelineDescriptor()
      desc.label = name
      desc.vertexFunction = vfn
      desc.fragmentFunction = fragment
      desc.colorAttachments[0].pixelFormat = pixelFormat
      desc.colorAttachments[0].isBlendingEnabled = false
      return try device.makeRenderPipelineState(descriptor: desc)
    }

    // Bloom intermediates stay HDR (rgba16Float) so wide blurs of bright
    // pixels don't wash to white before reaching composite. Composite is
    // the only LDR output — it tonemaps and writes to the drawable.
    thresholdPipeline = try make("Earth.Threshold", fragment: threshFn, pixelFormat: .rgba16Float)
    blurHPipeline = try make("Earth.BlurH", fragment: blurHFn, pixelFormat: .rgba16Float)
    blurVPipeline = try make("Earth.BlurV", fragment: blurVFn, pixelFormat: .rgba16Float)
    compositePipeline = try make("Earth.Composite", fragment: compFn, pixelFormat: .bgra8Unorm)
  }

  private func buildBuffers() {
    let uniformLen = MemoryLayout<EarthUniforms>.stride
    let glowLen = MemoryLayout<GlowSourceGPU>.stride * EarthRendererConstants.maxGlowSources
    let tuningLen = MemoryLayout<EarthTuningUniforms>.stride
    // Layout-drift tripwire: the Metal mirror (EarthTuningShared.h) is 14
    // packed float4s. If the Swift struct ever grows padding or a field,
    // this must change in lockstep on both sides.
    assert(tuningLen == 224, "EarthTuningUniforms layout drifted from EarthTuningShared.h")

    for i in 0..<Self.maxInflightFrames {
      let u = device.makeBuffer(length: uniformLen, options: .storageModeShared)!
      u.label = "Earth.Uniforms.\(i)"
      uniformBuffers.append(u)

      let g = device.makeBuffer(length: glowLen, options: .storageModeShared)!
      g.label = "Earth.GlowSources.\(i)"
      glowBuffers.append(g)

      let t = device.makeBuffer(length: tuningLen, options: .storageModeShared)!
      t.label = "Earth.Tuning.\(i)"
      tuningBuffers.append(t)
    }
  }

  // MARK: - MTKViewDelegate

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    currentDrawableSize = size
    sceneTexture = nil
    bloomTexA = nil
    bloomTexB = nil
  }

  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable,
          let rpd = view.currentRenderPassDescriptor else { return }

    _ = inflightSemaphore.wait(timeout: .distantFuture)

    let frameIndex = bufferIndex
    bufferIndex = (bufferIndex + 1) % Self.maxInflightFrames

    let now = CACurrentMediaTime() - startTime
    onFrame?(now)

    // Snapshot glow sources first so the uniform's count and the GPU buffer
    // contents are a consistent pair (no chance the store mutates between).
    let glowSources = glowStore?.currentGPUSources() ?? []
    let glowCount = min(glowSources.count, EarthRendererConstants.maxGlowSources)
    if glowCount > 0 {
      glowSources.withUnsafeBufferPointer { ptr in
        glowBuffers[frameIndex].contents().copyMemory(
          from: ptr.baseAddress!,
          byteCount: MemoryLayout<GlowSourceGPU>.stride * glowCount
        )
      }
    }

    let aspect = Float(currentDrawableSize.width / max(currentDrawableSize.height, 1))
    let uniforms = makeUniforms(time: Float(now), aspect: aspect, glowCount: glowCount)
    uniformBuffers[frameIndex].contents().copyMemory(
      from: [uniforms],
      byteCount: MemoryLayout<EarthUniforms>.stride
    )

    // Live look parameters — defaults reproduce the shipped literals, so this
    // is a straight passthrough outside the DEBUG tuning panel.
    tuningBuffers[frameIndex].contents().copyMemory(
      from: [EarthTuning.shared.gpu],
      byteCount: MemoryLayout<EarthTuningUniforms>.stride
    )

    guard let cmd = commandQueue.makeCommandBuffer() else {
      inflightSemaphore.signal()
      return
    }

    if let composite = compositePipeline,
       let threshold = thresholdPipeline,
       let blurH = blurHPipeline,
       let blurV = blurVPipeline {
      ensureOffscreenTargets()
      if let scene = sceneTexture, let blA = bloomTexA, let blB = bloomTexB {
        encodeMainPass(cmd: cmd, into: scene, uniformIdx: frameIndex)
        encodePostPass(cmd: cmd, pipeline: threshold, src: scene, dst: blA, uniformIdx: frameIndex)
        encodePostPass(cmd: cmd, pipeline: blurH, src: blA, dst: blB, uniformIdx: frameIndex)
        encodePostPass(cmd: cmd, pipeline: blurV, src: blB, dst: blA, uniformIdx: frameIndex)
        encodeCompositePass(cmd: cmd, pipeline: composite, scene: scene, bloom: blA, rpd: rpd, uniformIdx: frameIndex)
      } else {
        encodeMainPassDirect(cmd: cmd, rpd: rpd, uniformIdx: frameIndex)
      }
    } else {
      encodeMainPassDirect(cmd: cmd, rpd: rpd, uniformIdx: frameIndex)
    }

    cmd.addCompletedHandler { [inflightSemaphore] _ in
      inflightSemaphore.signal()
    }
    if (view.layer as? CAMetalLayer)?.presentsWithTransaction == true {
      // Transactional present (mid-resize, main thread): commit, wait until
      // scheduled, then present so the drawable rides the current CATransaction
      // and commits atomically with the layer's new bounds.
      cmd.commit()
      cmd.waitUntilScheduled()
      drawable.present()
    } else {
      cmd.present(drawable)
      cmd.commit()
    }
  }

  // MARK: - Offscreen targets

  private func ensureOffscreenTargets() {
    let w = Int(currentDrawableSize.width)
    let h = Int(currentDrawableSize.height)
    if w == 0 || h == 0 { return }

    // The scene is rendered at full drawable resolution (sharp orb). The bloom
    // chain runs at a FIXED reference resolution: its blur steps a constant
    // number of texels, so a drawable-sized bloom texture would make the glow
    // a constant number of pixels — visibly popping wider/tighter whenever the
    // card-lift transition swaps between card- and lobby-scale renders. Every
    // pass samples by normalized UV, so the resolutions can differ freely.
    let bloomH = EarthRendererConstants.bloomReferenceHeight
    let bloomW = max(1, Int((Double(w) / Double(h)) * Double(bloomH)))

    if let scene = sceneTexture, scene.width == w, scene.height == h,
       let bloom = bloomTexA, bloom.width == bloomW, bloom.height == bloomH {
      return
    }

    func makeTexture(_ label: String, width: Int, height: Int) -> MTLTexture? {
      let desc = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba16Float,
        width: width,
        height: height,
        mipmapped: false
      )
      desc.usage = [.shaderRead, .renderTarget]
      desc.storageMode = .private
      let t = device.makeTexture(descriptor: desc)
      t?.label = label
      return t
    }
    sceneTexture = makeTexture("Earth.Scene", width: w, height: h)
    bloomTexA = makeTexture("Earth.BloomA", width: bloomW, height: bloomH)
    bloomTexB = makeTexture("Earth.BloomB", width: bloomW, height: bloomH)
  }

  // MARK: - Render passes

  private func encodeMainPass(cmd: MTLCommandBuffer, into dst: MTLTexture, uniformIdx: Int) {
    let rpd = MTLRenderPassDescriptor()
    rpd.colorAttachments[0].texture = dst
    rpd.colorAttachments[0].loadAction = .clear
    rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    rpd.colorAttachments[0].storeAction = .store
    guard let enc = cmd.makeRenderCommandEncoder(descriptor: rpd) else { return }
    enc.label = "Earth.MainPass"
    enc.setRenderPipelineState(mainPipeline)
    enc.setFragmentBuffer(uniformBuffers[uniformIdx], offset: 0, index: 0)
    enc.setFragmentBuffer(glowBuffers[uniformIdx], offset: 0, index: 1)
    enc.setFragmentBuffer(tuningBuffers[uniformIdx], offset: 0, index: 2)
    enc.setFragmentTexture(continentTexture, index: 0)
    enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    enc.endEncoding()
  }

  private func encodeMainPassDirect(cmd: MTLCommandBuffer, rpd: MTLRenderPassDescriptor, uniformIdx: Int) {
    rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    rpd.colorAttachments[0].loadAction = .clear
    rpd.colorAttachments[0].storeAction = .store
    guard let enc = cmd.makeRenderCommandEncoder(descriptor: rpd) else { return }
    enc.label = "Earth.MainPassDirect"
    enc.setRenderPipelineState(mainPipeline)
    enc.setFragmentBuffer(uniformBuffers[uniformIdx], offset: 0, index: 0)
    enc.setFragmentBuffer(glowBuffers[uniformIdx], offset: 0, index: 1)
    enc.setFragmentBuffer(tuningBuffers[uniformIdx], offset: 0, index: 2)
    enc.setFragmentTexture(continentTexture, index: 0)
    enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    enc.endEncoding()
  }

  private func encodePostPass(cmd: MTLCommandBuffer,
                              pipeline: MTLRenderPipelineState,
                              src: MTLTexture,
                              dst: MTLTexture,
                              uniformIdx: Int) {
    let rpd = MTLRenderPassDescriptor()
    rpd.colorAttachments[0].texture = dst
    rpd.colorAttachments[0].loadAction = .dontCare
    rpd.colorAttachments[0].storeAction = .store
    guard let enc = cmd.makeRenderCommandEncoder(descriptor: rpd) else { return }
    enc.setRenderPipelineState(pipeline)
    enc.setFragmentBuffer(tuningBuffers[uniformIdx], offset: 0, index: 0)
    enc.setFragmentTexture(src, index: 0)
    enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    enc.endEncoding()
  }

  private func encodeCompositePass(cmd: MTLCommandBuffer,
                                   pipeline: MTLRenderPipelineState,
                                   scene: MTLTexture,
                                   bloom: MTLTexture,
                                   rpd: MTLRenderPassDescriptor,
                                   uniformIdx: Int) {
    rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    rpd.colorAttachments[0].loadAction = .clear
    rpd.colorAttachments[0].storeAction = .store
    guard let enc = cmd.makeRenderCommandEncoder(descriptor: rpd) else { return }
    enc.label = "Earth.Composite"
    enc.setRenderPipelineState(pipeline)
    enc.setFragmentTexture(scene, index: 0)
    enc.setFragmentTexture(bloom, index: 1)
    // Buffer 0 here is the tuning struct (see EarthBloom.metal) — if
    // EarthUniforms is ever needed in the composite pass, bind it at a
    // different index.
    enc.setFragmentBuffer(tuningBuffers[uniformIdx], offset: 0, index: 0)
    enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    enc.endEncoding()
  }

  // MARK: - Uniform assembly

  private func makeUniforms(time: Float, aspect: Float, glowCount: Int) -> EarthUniforms {
    // Camera at +Z looking at origin. We don't use a real view matrix here
    // because the fragment shader reconstructs world rays from NDC via the
    // inverse projection; sphere orientation handles all rotation.
    let proj = perspectiveProjection(
      fovYRadians: EarthRendererConstants.cameraFovYRadians,
      aspect: aspect,
      near: 0.1,
      far: 100
    )
    let view = simd_float4x4(translation: SIMD3<Float>(0, 0, -EarthRendererConstants.cameraDistance))
    let vp = proj * view
    let invVP = vp.inverse

    let tuning = EarthTuning.shared.values

    // Breath default: 4s inhale / 6s exhale — the physiological sigh ratio
    // per DESIGN.md.
    let breath = breathingCurve(
      time: time,
      inhale: tuning.breathInhaleSeconds,
      exhale: tuning.breathExhaleSeconds
    )

    // Sphere orientation: axial tilt + user-driven rotation + slow idle drift.
    let orientation = interaction?.orientationMatrix(time: time) ?? defaultIdleOrientation(time: time)

    // Sun default: from upper-left, slightly forward — warm peach key light.
    // The shader uses dot(N, sunDir) for a *soft* terminator.
    let sun = simd_normalize(SIMD3<Float>(tuning.sunX, tuning.sunY, tuning.sunZ))

    return EarthUniforms(
      inverseViewProj: invVP,
      cameraPosition: SIMD4<Float>(0, 0, EarthRendererConstants.cameraDistance, 1),
      sphereOrientation: orientation,
      sunDirection: SIMD4<Float>(sun.x, sun.y, sun.z, 0),
      params: SIMD4<Float>(time, breath, aspect, Float(glowCount)),
      sphereData: SIMD4<Float>(0, 0, 0, EarthRendererConstants.sphereRadius),
      atmosphereData: SIMD4<Float>(
        EarthRendererConstants.atmosphereRadius,
        tuning.atmosphereStrength,
        0.12,   // baseline emissive — dead slot, never read by the shader
        0
      )
    )
  }

  private func defaultIdleOrientation(time: Float) -> simd_float4x4 {
    // Used only when no interaction is wired (e.g. minimal preview).
    let yaw = time * 0.08
    let tilt = EarthRendererConstants.axialTiltRadians
    return simd_float4x4(rotationAroundY: yaw) * simd_float4x4(rotationAroundZ: tilt)
  }

  private func breathingCurve(time: Float, inhale: Float, exhale: Float) -> Float {
    // Two-piece eased cosine, period = inhale + exhale (default 4s + 6s).
    let inhale = max(inhale, 0.1)
    let exhale = max(exhale, 0.1)
    let t = time.truncatingRemainder(dividingBy: inhale + exhale)
    if t < inhale {
      // 0 → 1 over the inhale, cosine-eased.
      let u = t / inhale
      return 0.5 - 0.5 * cos(u * .pi)
    } else {
      // 1 → 0 over the exhale.
      let u = (t - inhale) / exhale
      return 0.5 + 0.5 * cos(u * .pi)
    }
  }
}

// MARK: - matrix helpers

extension simd_float4x4 {
  init(translation t: SIMD3<Float>) {
    self = matrix_identity_float4x4
    columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1)
  }
  init(rotationAroundY a: Float) {
    let c = cos(a), s = sin(a)
    self = simd_float4x4(
      SIMD4<Float>( c, 0, s, 0),
      SIMD4<Float>( 0, 1, 0, 0),
      SIMD4<Float>(-s, 0, c, 0),
      SIMD4<Float>( 0, 0, 0, 1)
    )
  }
  init(rotationAroundX a: Float) {
    let c = cos(a), s = sin(a)
    self = simd_float4x4(
      SIMD4<Float>(1,  0, 0, 0),
      SIMD4<Float>(0,  c, s, 0),
      SIMD4<Float>(0, -s, c, 0),
      SIMD4<Float>(0,  0, 0, 1)
    )
  }
  init(rotationAroundZ a: Float) {
    let c = cos(a), s = sin(a)
    self = simd_float4x4(
      SIMD4<Float>( c, s, 0, 0),
      SIMD4<Float>(-s, c, 0, 0),
      SIMD4<Float>( 0, 0, 1, 0),
      SIMD4<Float>( 0, 0, 0, 1)
    )
  }
}

func perspectiveProjection(fovYRadians fovy: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
  let yScale = 1 / tan(fovy * 0.5)
  let xScale = yScale / aspect
  let zRange = far - near
  let zScale = -(far + near) / zRange
  let wzScale = -2 * far * near / zRange
  return simd_float4x4(
    SIMD4<Float>(xScale, 0,      0,       0),
    SIMD4<Float>(0,      yScale, 0,       0),
    SIMD4<Float>(0,      0,      zScale, -1),
    SIMD4<Float>(0,      0,      wzScale, 0)
  )
}
