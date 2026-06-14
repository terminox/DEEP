import SwiftUI
import UIKit
import AVFoundation

/// A muted, looping video that fills its frame (`resizeAspectFill`). Used for
/// ambient motion behind hero content. If the named resource is missing it
/// renders nothing, so previews and load failures degrade cleanly.
struct LoopingVideoView: UIViewRepresentable {
  let resource: String
  var fileExtension = "mp4"
  /// When false (e.g. Reduce Motion is on) the video holds on its first frame
  /// instead of looping.
  var isAnimating = true

  func makeCoordinator() -> Coordinator {
    Coordinator(resource: resource, fileExtension: fileExtension)
  }

  func makeUIView(context: Context) -> VideoLayerView {
    let view = VideoLayerView()
    view.playerLayer.player = context.coordinator.player
    view.playerLayer.videoGravity = .resizeAspectFill
    context.coordinator.setAnimating(isAnimating)
    return view
  }

  func updateUIView(_ uiView: VideoLayerView, context: Context) {
    context.coordinator.setAnimating(isAnimating)
  }

  static func dismantleUIView(_ uiView: VideoLayerView, coordinator: Coordinator) {
    coordinator.stop()
  }

  /// Owns the queue player + looper so playback survives SwiftUI re-renders.
  @MainActor
  final class Coordinator {
    let player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    init(resource: String, fileExtension: String) {
      guard let url = Bundle.main.url(forResource: resource, withExtension: fileExtension) else {
        player = nil
        return
      }
      let item = AVPlayerItem(url: url)
      let queue = AVQueuePlayer(playerItem: item)
      queue.isMuted = true
      queue.preventsDisplaySleepDuringVideoPlayback = false
      looper = AVPlayerLooper(player: queue, templateItem: item)
      player = queue
    }

    func setAnimating(_ animating: Bool) {
      guard let player else { return }
      if animating { player.play() } else { player.pause() }
    }

    func stop() {
      player?.pause()
      looper?.disableLooping()
    }
  }

  /// A `UIView` whose backing layer is an `AVPlayerLayer`, so the video always
  /// fills the view's bounds without manual layout.
  final class VideoLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
  }
}

#Preview("Looping Video") {
  LoopingVideoView(resource: "sky")
    .frame(height: 360)
    .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
    .padding()
    .background(.moonCream)
}
