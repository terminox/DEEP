import SwiftUI
import UIKit
import AVFoundation

/// A bundled clip that plays through exactly once and then says so, filling its
/// frame (`resizeAspectFill`). Unlike `LoopingVideoView` it can carry sound, and
/// it can be joined part-way through — both of which a broadcast needs: whoever
/// walks in two seconds late sees the intro two seconds in, hears it, and the
/// hero hands off to the ambient loop when it ends.
///
/// Carrying sound means claiming the audio session. An unmuted clip puts it on
/// `.playback`, the category the app's four audio engines set, so the ring/silent
/// switch can't silence it; a muted one claims nothing.
///
/// If the named resource is missing it renders nothing and reports the end
/// immediately, so a stripped bundle degrades into "there was no intro" rather
/// than a hero that never moves on.
struct OneShotVideoView: UIViewRepresentable {
  let resource: String
  var fileExtension = "mp4"
  /// Seconds into the clip to begin at. A latecomer joins here.
  var startAt: TimeInterval = 0
  var isMuted = false
  /// Called on the main actor when the clip reaches its end — once per view.
  var onEnded: () -> Void = {}

  func makeCoordinator() -> Coordinator {
    Coordinator(resource: resource, fileExtension: fileExtension)
  }

  func makeUIView(context: Context) -> LoopingVideoView.VideoLayerView {
    let view = LoopingVideoView.VideoLayerView()
    view.playerLayer.player = context.coordinator.player
    view.playerLayer.videoGravity = .resizeAspectFill
    context.coordinator.start(at: startAt, muted: isMuted, onEnded: onEnded)
    return view
  }

  func updateUIView(_ uiView: LoopingVideoView.VideoLayerView, context: Context) {
    // Only the mute flag can change mid-clip — the member tapping ON AIR. A new
    // `startAt` would mean a different join, which is a different view.
    context.coordinator.setMuted(isMuted)
    context.coordinator.onEnded = onEnded
  }

  static func dismantleUIView(_ uiView: LoopingVideoView.VideoLayerView, coordinator: Coordinator) {
    coordinator.stop()
  }

  /// Owns the player so playback survives SwiftUI re-renders, and guarantees
  /// `onEnded` fires exactly once.
  @MainActor
  final class Coordinator {
    let player: AVPlayer?
    var onEnded: () -> Void = {}

    private var endObserver: NSObjectProtocol?
    private var hasEnded = false
    private var sessionConfigured = false

    init(resource: String, fileExtension: String) {
      guard let url = Bundle.main.url(forResource: resource, withExtension: fileExtension) else {
        player = nil
        return
      }
      let player = AVPlayer(playerItem: AVPlayerItem(url: url))
      player.preventsDisplaySleepDuringVideoPlayback = false
      self.player = player
    }

    func start(at offset: TimeInterval, muted: Bool, onEnded: @escaping () -> Void) {
      self.onEnded = onEnded
      guard let player else {
        // Nothing to play: the caller is waiting on an end that will never come
        // from AVFoundation, so give it one now.
        finish()
        return
      }
      player.isMuted = muted
      if !muted { configureSessionIfNeeded() }
      endObserver = NotificationCenter.default.addObserver(
        forName: AVPlayerItem.didPlayToEndTimeNotification,
        object: player.currentItem,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.finish() }
      }
      let target = CMTime(seconds: max(0, offset), preferredTimescale: 600)
      player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak player] _ in
        player?.play()
      }
    }

    func setMuted(_ muted: Bool) {
      player?.isMuted = muted
      // Un-muting mid-clip — the member tapping ON AIR back on — is the other
      // moment there is something to hear.
      if !muted { configureSessionIfNeeded() }
    }

    func stop() {
      if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
      endObserver = nil
      player?.pause()
      player?.replaceCurrentItem(with: nil)
    }

    private func finish() {
      guard !hasEnded else { return }
      hasEnded = true
      onEnded()
    }

    // MARK: - Session

    /// The same category the app's four audio engines set, behind the same
    /// latch. Left alone, an `AVPlayer` plays under the process default
    /// `.soloAmbient`, where the ring/silent switch silences it — which is how
    /// Fuku's intro came to be mute on a phone in silent mode while the lounge
    /// track that follows it, joined through `LoungeRadioPlayer`, played
    /// straight through. Never deactivated: the session is process-wide and
    /// shared with the streamers.
    ///
    /// Claimed only when there is something to hear. `.playback` takes the
    /// session outright, so a muted clip must not stop whatever the member is
    /// listening to elsewhere — and the latch earns its keep more here than it
    /// does for the engines, because `updateUIView` re-asserts the mute flag on
    /// every body pass.
    private func configureSessionIfNeeded() {
      guard !sessionConfigured else { return }
      sessionConfigured = true
      let session = AVAudioSession.sharedInstance()
      try? session.setCategory(.playback, mode: .default)
      try? session.setActive(true)
    }
  }
}

#Preview("One-shot video") {
  OneShotVideoView(resource: "fuku_intro", isMuted: true)
    .frame(height: 320)
    .clipShape(RoundedRectangle(cornerRadius: .card, style: .continuous))
    .padding()
    .background(.moonCream)
}
