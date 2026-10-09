import SwiftUI

/// The full-screen player. The collection's photograph fills the whole screen,
/// edge to edge under the status bar, and the player sits over its lower part:
/// collection, track, scrubber, transport and volume, seated on a plum scrim
/// and a progressive blur so the photo melts out of focus behind the controls.
/// Shuffle and Repeat flank the transport, as in Spotify; Lyrics and Save sit
/// with the title.
struct NowPlayingView: View {
  @Environment(\.soundPlayer) private var player
  @Environment(\.listenReporter) private var listenReporter
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var onDismiss: () -> Void

  /// Local scrub state so the timer doesn't fight the finger while dragging.
  @State private var isScrubbing = false
  @State private var scrubValue: Double = 0
  @State private var showLyrics = false
  /// Where the artwork's slow drift is heading; flipped under `.drift`.
  @State private var drifted = false

  var body: some View {
    // The whole screen expands from (and collapses back into) the mini bar via
    // the system zoom transition wired in `MainTabController`; this view just
    // lays out its contents and stays opaque so the morph reads cleanly.
    ZStack {
      artwork
        .ignoresSafeArea()

      VStack(spacing: 0) {
        scrim(from: .top, peak: 0.36)
          .frame(height: 180)
        Spacer()
        scrim(from: .bottom, peak: 0.4)
          .frame(height: 520)
      }
      .ignoresSafeArea()
      .allowsHitTesting(false)

      VStack(spacing: 0) {
        closeButton
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, 4)
        Spacer(minLength: 0)
        controls
      }
      .padding(.horizontal, .edge)
    }
    .sheet(isPresented: $showLyrics) {
      if let track = player.currentTrack {
        LyricsSheet(track: track)
          .presentationDetents([.medium, .large])
          .presentationBackground(.ultraThinMaterial)
      }
    }
  }

  // MARK: - Artwork

  /// The photograph, drifting slowly while a sound plays and settling under a
  /// soft plum dim on pause.
  private var artwork: some View {
    ZStack {
      // Opaque base so nothing underneath bleeds through while the photo loads.
      Color.deepPlum
      ArtworkImage(
        url: player.collection?.imageURL,
        colors: (player.collection?.palette ?? .mist).colors,
        cornerRadius: 0,
        bordered: false
      )
      .scaleEffect(drifted ? 1.08 : 1.02)
      .overlay(Color.deepPlum.opacity(player.isPlaying ? 0 : 0.2))
      .animation(.settle, value: player.isPlaying)
    }
    .clipped()
    .onChange(of: drifts, initial: true) { _, drifts in
      // Replacing the endless drift with a finite settle is what stops it.
      withAnimation(drifts ? .drift : .settle) { drifted = drifts }
    }
  }

  private var drifts: Bool {
    player.isPlaying && !reduceMotion
  }

  /// A plum wash fading out from one edge, to seat moonlit text on any photo.
  private func scrim(from edge: VerticalEdge, peak: Double) -> some View {
    let ink = Color.deepPlum.opacity(peak)
    return LinearGradient(
      stops: [
        .init(color: ink, location: 0),
        .init(color: ink.opacity(0.8), location: 0.5),
        .init(color: .clear, location: 1)
      ],
      startPoint: edge == .top ? .top : .bottom,
      endPoint: edge == .top ? .bottom : .top
    )
  }

  // MARK: - Pieces

  /// The onboarding back button's frosted cream circle, here closing the
  /// player back into the mini bar.
  private var closeButton: some View {
    Button(action: onDismiss) {
      Image(systemName: "chevron.backward")
        .font(DeepType.sectionTitle)
        .foregroundStyle(.deepPlum)
        .frame(width: 40, height: 40)
        .background(FrostedCardBackground(cornerRadius: .chip))
        .contentShape(Circle())
    }
    .buttonStyle(.softPress)
    .accessibilityLabel("Close")
  }

  private var controls: some View {
    VStack(spacing: 18) {
      titleRow
      scrubber
      transport
      volume
    }
    .padding(.bottom, 12)
    .background(alignment: .top) { controlsBlur }
  }

  /// A progressive blur sized by the controls themselves, so its clear top
  /// edge always sits just above the collection name whatever the type size,
  /// running out to both screen edges and down past the home indicator.
  private var controlsBlur: some View {
    VariableBlurView(maxBlurRadius: 24, direction: .blurredBottomClearTop)
      .padding(.top, -28)
      .padding(.horizontal, -.edge)
      .ignoresSafeArea(edges: .bottom)
      .allowsHitTesting(false)
  }

  private var titleRow: some View {
    HStack(alignment: .center, spacing: 4) {
      VStack(alignment: .leading, spacing: 4) {
        Text((player.collection?.title ?? "").uppercased())
          .font(DeepType.micro)
          .tracking(1.6)
          .foregroundStyle(.moonCream.opacity(0.72))
          .lineLimit(1)
        Text(player.currentTrack?.title ?? "")
          .font(.system(.title2, weight: .semibold))
          .foregroundStyle(.moonCream)
          .lineLimit(1)
        subtitle
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .heartBurst(for: listenReporter.notice)

      // Lyrics — opens the (multi-language) lyrics sheet for the current track.
      utilityButton("text.quote", isOn: true) { showLyrics = true }
        .accessibilityLabel("Lyrics")
      if let track = player.currentTrack, let collection = player.collection {
        SaveTrackButton(track: track, collection: collection)
      }
    }
  }

  /// The collection's subtitle — giving way, for a few seconds, to a listen's
  /// heart when one lands (the mini player's swap, at this screen's size).
  private var subtitle: some View {
    ZStack(alignment: .leading) {
      if let notice = listenReporter.notice {
        ListenNoticeLabel(notice: notice, font: DeepType.body, ink: .moonCream)
          .id(notice.id)
          .transition(.opacity)
      } else {
        Text(player.collection?.subtitle ?? "")
          .font(DeepType.body)
          .foregroundStyle(.moonCream.opacity(0.72))
          .lineLimit(1)
          .transition(.opacity)
      }
    }
    .animation(.exhale, value: listenReporter.notice)
  }

  private var scrubber: some View {
    VStack(spacing: 4) {
      SoundSlider(
        value: Binding(
          get: { isScrubbing ? scrubValue : player.progress },
          set: { scrubValue = $0 }
        ),
        activeColor: .moonCream,
        trackHeight: 4,
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
      .foregroundStyle(.moonCream.opacity(0.72))
    }
  }

  private var displayElapsed: TimeInterval {
    isScrubbing ? scrubValue * player.duration : player.elapsed
  }

  private var transport: some View {
    HStack {
      utilityButton("shuffle", isOn: player.isShuffled) {
        player.isShuffled.toggle()
      }
      .accessibilityLabel("Shuffle")
      .accessibilityValue(player.isShuffled ? "On" : "Off")

      Spacer(minLength: 0)

      transportButton("backward.fill") { player.previous() }
      Button {
        player.togglePlayPause()
      } label: {
        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(.deepPlum)
          .contentTransition(.symbolEffect(.replace))
          .frame(width: 68, height: 68)
          .background(Circle().fill(.moonCream))
          .contentShape(Circle())
      }
      .buttonStyle(.softPress)
      .padding(.horizontal, 12)
      .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
      transportButton("forward.fill") { player.next() }

      Spacer(minLength: 0)

      // Off → all → one, as in Apple Music. Lit whenever a queue will repeat.
      utilityButton(
        player.repeatMode == .one ? "repeat.1" : "repeat",
        isOn: player.repeatMode != .off
      ) {
        player.repeatMode = player.repeatMode.next
      }
      .accessibilityLabel("Repeat")
      .accessibilityValue(repeatValue)
    }
  }

  private func transportButton(
    _ systemName: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 24, weight: .medium))
        .foregroundStyle(.moonCream)
        .frame(width: 52, height: 52)
        .contentShape(Rectangle())
    }
    .buttonStyle(.softPress)
  }

  private var volume: some View {
    HStack(spacing: 12) {
      Image(systemName: "speaker.fill")
      SoundSlider(
        value: Binding(get: { player.volume }, set: { player.volume = $0 }),
        activeColor: .moonCream.opacity(0.8),
        trackHeight: 4
      )
      Image(systemName: "speaker.wave.3.fill")
    }
    .font(.footnote)
    .foregroundStyle(.moonCream.opacity(0.72))
  }

  private var repeatValue: LocalizedStringKey {
    switch player.repeatMode {
    case .off: "Off"
    case .all: "All"
    case .one: "One"
    }
  }

  /// `isOn` lights a mode control in full cream, the ink the title wears;
  /// off, it steps back to the subtitle's softer cream.
  private func utilityButton(
    _ systemName: String,
    isOn: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(isOn ? Color.moonCream : .moonCream.opacity(0.5))
        .contentTransition(.symbolEffect(.replace))
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.softPress)
    .animation(.exhale, value: isOn)
    .animation(.exhale, value: systemName)
  }
}

#if DEBUG
#Preview("Now Playing — Playing") {
  NowPlayingView {}
    .environment(\.soundPlayer, MockSoundPlayer.playing)
}

#Preview("Now Playing — Heart earned") {
  NowPlayingView {}
    .environment(\.soundPlayer, MockSoundPlayer.playing)
    .environment(\.listenReporter, MockListenReporter.earned)
}

#Preview("Now Playing — Today's hearts in") {
  NowPlayingView {}
    .environment(\.soundPlayer, MockSoundPlayer.playing)
    .environment(\.listenReporter, MockListenReporter.dayComplete)
}

#Preview("Now Playing — Paused") {
  let player = MockSoundPlayer.playing
  player.isPlaying = false
  return NowPlayingView {}
    .environment(\.soundPlayer, player)
}

#Preview("Now Playing — Shuffle, Repeat One") {
  let player = MockSoundPlayer.playing
  player.isShuffled = true
  player.repeatMode = .one
  return NowPlayingView {}
    .environment(\.soundPlayer, player)
}

#Preview("Now Playing — Repeat All") {
  let player = MockSoundPlayer.playing
  player.repeatMode = .all
  return NowPlayingView {}
    .environment(\.soundPlayer, player)
}
#endif
