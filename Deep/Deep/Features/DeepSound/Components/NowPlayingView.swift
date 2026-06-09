import SwiftUI

/// The full-screen player. Mirrors Apple Music's Now Playing: a large artwork
/// that contracts when paused, a draggable scrubber, transport, volume, and a
/// bottom utility row — retinted to Deep and with softened motion.
struct NowPlayingView: View {
  @Environment(\.soundPlayer) private var player
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var artworkNamespace: Namespace.ID
  var onDismiss: () -> Void

  /// Local scrub state so the timer doesn't fight the finger while dragging.
  @State private var isScrubbing = false
  @State private var scrubValue: Double = 0
  /// Downward drag offset for swipe-to-dismiss.
  @State private var dragOffset: CGFloat = 0

  var body: some View {
    ZStack {
      background

      VStack(spacing: 0) {
        grabHandle
          .transition(.opacity)

        Spacer(minLength: 8)

        artwork
          .padding(.horizontal, 28)

        Spacer(minLength: 24)

        VStack(spacing: 26) {
          titleRow
          scrubber
          transport
          volume
          bottomRow
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 40)
        // The controls rise from the bottom as the sheet appears — the spatial
        // "expand" — while the artwork (matched geometry) morphs independently.
        .transition(controlsTransition)
      }
    }
    .offset(y: dragOffset)
    .gesture(dismissDrag)
  }

  /// Bottom controls slide up + fade as Now Playing opens; a plain fade when the
  /// user has Reduce Motion on.
  private var controlsTransition: AnyTransition {
    reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
  }

  // MARK: - Background

  private var background: some View {
    ZStack {
      // Opaque base so the sheet is solid — nothing underneath bleeds through.
      Color.softLilac
      LinearGradient(
        colors: [
          .softLilac,
          .lavenderMist.opacity(0.7),
          .blushPowder.opacity(0.6)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .overlay(.ultraThinMaterial.opacity(0.4))
    }
    .ignoresSafeArea()
  }

  // MARK: - Pieces

  private var grabHandle: some View {
    Capsule()
      .fill(.deepPlum.opacity(0.22))
      .frame(width: 40, height: 5)
      .padding(.top, 12)
      .padding(.bottom, 4)
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
      .onTapGesture(perform: onDismiss)
  }

  private var artwork: some View {
    SoundArtwork(palette: player.collection?.palette ?? .mist, cornerRadius: 22)
      .matchedGeometryEffect(id: SoundPlayerNamespace.artwork, in: artworkNamespace)
      .aspectRatio(1, contentMode: .fit)
      .scaleEffect(artworkScale)
      .shadow(
        color: .lavenderMist.opacity(player.isPlaying ? 0.45 : 0.22),
        radius: player.isPlaying ? 34 : 16,
        x: 0,
        y: player.isPlaying ? 20 : 10
      )
      .animation(reduceMotion ? nil : .settle, value: player.isPlaying)
  }

  private var artworkScale: CGFloat {
    player.isPlaying ? 1.0 : 0.84
  }

  private var titleRow: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 3) {
        Text(player.currentTrack?.title ?? "")
          .font(.system(.title3, design: .default, weight: .semibold))
          .foregroundStyle(.deepPlum)
          .lineLimit(1)
        Text(player.collection?.title ?? "")
          .font(DeepType.body)
          .foregroundStyle(.driftGrey)
          .lineLimit(1)
      }
      Spacer()
      Image(systemName: "ellipsis")
        .font(.system(.body, weight: .semibold))
        .foregroundStyle(.driftGrey)
        .frame(width: 34, height: 34)
        .background(Circle().fill(.white.opacity(0.4)))
    }
  }

  private var scrubber: some View {
    VStack(spacing: 6) {
      SoundSlider(
        value: Binding(
          get: { isScrubbing ? scrubValue : player.progress },
          set: { scrubValue = $0 }
        ),
        onEditingChanged: { editing in
          if editing {
            isScrubbing = true
            scrubValue = player.progress
          } else {
            player.seek(toProgress: scrubValue)
            isScrubbing = false
          }
        }
      )

      HStack {
        Text(displayElapsed.clockString)
        Spacer()
        Text("-\(max(0, player.duration - displayElapsed).clockString)")
      }
      .font(DeepType.caption)
      .monospacedDigit()
      .foregroundStyle(.driftGrey)
    }
  }

  private var displayElapsed: TimeInterval {
    isScrubbing ? scrubValue * player.duration : player.elapsed
  }

  private var transport: some View {
    HStack(spacing: 44) {
      transportButton("backward.fill", size: 28) { player.previous() }
      Button {
        player.togglePlayPause()
      } label: {
        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
          .font(.system(size: 44, weight: .medium))
          .foregroundStyle(.deepPlum)
          .frame(width: 64, height: 64)
          .contentShape(Rectangle())
      }
      .buttonStyle(.softPress)
      transportButton("forward.fill", size: 28) { player.next() }
    }
  }

  private func transportButton(
    _ systemName: String,
    size: CGFloat,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: size, weight: .medium))
        .foregroundStyle(.deepPlum)
        .frame(width: 56, height: 56)
        .contentShape(Rectangle())
    }
    .buttonStyle(.softPress)
  }

  private var volume: some View {
    HStack(spacing: 12) {
      Image(systemName: "speaker.fill")
        .font(.footnote)
        .foregroundStyle(.driftGrey)
      SoundSlider(
        value: Binding(get: { player.volume }, set: { player.volume = $0 }),
        activeColor: .lavenderMist.opacity(0.8)
      )
      Image(systemName: "speaker.wave.3.fill")
        .font(.footnote)
        .foregroundStyle(.driftGrey)
    }
  }

  private var bottomRow: some View {
    HStack {
      utilityButton("airplayaudio")
      Spacer()
      utilityButton("list.bullet")
    }
    .padding(.horizontal, 24)
  }

  private func utilityButton(_ systemName: String) -> some View {
    Image(systemName: systemName)
      .font(.system(.body, weight: .medium))
      .foregroundStyle(.driftGrey)
      .frame(width: 44, height: 44)
      .contentShape(Rectangle())
  }

  // MARK: - Dismiss gesture

  private var dismissDrag: some Gesture {
    DragGesture()
      .onChanged { value in
        dragOffset = max(0, value.translation.height)
      }
      .onEnded { value in
        if value.translation.height > 120 || value.predictedEndTranslation.height > 300 {
          onDismiss()
        }
        withAnimation(.exhale) { dragOffset = 0 }
      }
  }
}

#if DEBUG
/// Hosts the `@Namespace` the player needs for its matched-geometry artwork.
private struct NowPlayingPreviewHost: View {
  @Namespace private var artworkNamespace

  var body: some View {
    NowPlayingView(artworkNamespace: artworkNamespace) {}
  }
}

#Preview("Now Playing — Playing") {
  NowPlayingPreviewHost()
    .environment(\.soundPlayer, MockSoundPlayer.playing)
}

#Preview("Now Playing — Paused") {
  let player = MockSoundPlayer.playing
  player.isPlaying = false
  return NowPlayingPreviewHost()
    .environment(\.soundPlayer, player)
}
#endif
