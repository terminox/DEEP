#if DEBUG
import SwiftUI

// THROWAWAY. Small pieces the player variants share. Each variant still owns
// its whole layout; these are only the controls every player needs, in two
// inks: light over a photograph, plum over DEEP's pale sky.

/// Which ground a control sits on.
enum LabInk {
  case onPhoto
  case onPale

  var primary: Color {
    switch self {
    case .onPhoto: .moonCream
    case .onPale: .deepPlum
    }
  }

  var secondary: Color {
    switch self {
    case .onPhoto: .moonCream.opacity(0.72)
    case .onPale: .driftGrey
    }
  }

  var sliderFill: Color {
    switch self {
    case .onPhoto: .moonCream
    case .onPale: .deepPlum.opacity(0.75)
    }
  }
}

// MARK: - Artwork

/// The track photograph, filling whatever frame the variant gives it. Drifts
/// slowly while playing and settles under a soft plum dim on pause, in place
/// of the old shrink-on-pause, which has nowhere to shrink to full screen.
struct LabArtwork: View {
  var cornerRadius: CGFloat = 0

  @Environment(\.soundPlayer) private var player
  @Environment(\.nowPlayingLabKnobs) private var knobs

  var body: some View {
    let drifting = knobs.breathes && player.isPlaying
    TimelineView(.animation(minimumInterval: 1 / 30, paused: !drifting)) { context in
      let t = context.date.timeIntervalSinceReferenceDate
      ArtworkImage(
        url: url,
        colors: (player.collection?.palette ?? .mist).colors,
        cornerRadius: cornerRadius,
        bordered: false
      )
      .scaleEffect(knobs.breathes ? 1.05 + 0.03 * sin(t * 2 * .pi / 18) : 1)
    }
    .overlay(Color.deepPlum.opacity(player.isPlaying ? 0 : 0.2))
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    .animation(.settle, value: player.isPlaying)
  }

  private var url: URL? {
    let override = NowPlayingLabArtwork(rawValue: knobs.artwork) ?? .playing
    return override.url ?? NowPlayingLabArtwork.upsized(player.collection?.imageURL)
  }
}

/// A plum wash that fades out from one edge, to seat light text on a photo.
struct LabScrim: View {
  var edge: VerticalEdge
  /// Peak opacity before the `scrim` knob scales it.
  var peak: Double = 0.85

  @Environment(\.nowPlayingLabKnobs) private var knobs

  var body: some View {
    let ink = Color.deepPlum.opacity(peak * knobs.scrim)
    let stops: [Gradient.Stop] = [
      .init(color: ink, location: 0),
      .init(color: ink.opacity(0.8), location: 0.5),
      .init(color: .clear, location: 1)
    ]
    LinearGradient(
      stops: stops,
      startPoint: edge == .top ? .top : .bottom,
      endPoint: edge == .top ? .bottom : .top
    )
    .allowsHitTesting(false)
  }
}

// MARK: - Controls

/// The scrubber from `NowPlayingView`, with local scrub state so the timer
/// doesn't fight the finger.
struct LabScrubber: View {
  var ink: LabInk
  var showsTimes = true

  @Environment(\.soundPlayer) private var player
  @State private var isScrubbing = false
  @State private var scrubValue: Double = 0

  var body: some View {
    VStack(spacing: 4) {
      SoundSlider(
        value: Binding(
          get: { isScrubbing ? scrubValue : player.progress },
          set: { scrubValue = $0 }
        ),
        activeColor: ink.sliderFill,
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
      if showsTimes {
        HStack {
          Text(displayElapsed.clockString)
          Spacer()
          Text("-\(max(0, player.duration - displayElapsed).clockString)")
        }
        .font(DeepType.caption)
        .monospacedDigit()
        .foregroundStyle(ink.secondary)
      }
    }
  }

  private var displayElapsed: TimeInterval {
    isScrubbing ? scrubValue * player.duration : player.elapsed
  }
}

/// Play / pause. `filled` draws a solid disc with the glyph cut in the
/// opposite ink — the Spotify-style key action; otherwise the glyph stands
/// alone on glass.
struct LabPlayButton: View {
  var ink: LabInk
  var diameter: CGFloat = 64
  var filled = true

  @Environment(\.soundPlayer) private var player

  var body: some View {
    Button {
      player.togglePlayPause()
    } label: {
      Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
        .font(.system(size: diameter * 0.36, weight: .semibold))
        .contentTransition(.symbolEffect(.replace))
        .foregroundStyle(filled ? (ink == .onPhoto ? Color.deepPlum : .moonCream) : ink.primary)
        .frame(width: diameter, height: diameter)
        .background {
          if filled { Circle().fill(ink.primary) }
        }
        .modifier(LabGlass(enabled: !filled, tinted: ink == .onPhoto))
        .contentShape(Circle())
    }
    .buttonStyle(.softPress)
    .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
  }
}

struct LabSkipButton: View {
  enum Direction { case back, forward }
  var direction: Direction
  var ink: LabInk
  var size: CGFloat = 24

  @Environment(\.soundPlayer) private var player

  var body: some View {
    Button {
      direction == .back ? player.previous() : player.next()
    } label: {
      Image(systemName: direction == .back ? "backward.fill" : "forward.fill")
        .font(.system(size: size, weight: .medium))
        .foregroundStyle(ink.primary)
        .frame(width: 52, height: 52)
        .contentShape(Rectangle())
    }
    .buttonStyle(.softPress)
    .accessibilityLabel(direction == .back ? "Previous" : "Next")
  }
}

/// Save to playlist, in either ink. Same store call as `SaveTrackButton`.
struct LabSaveButton: View {
  var ink: LabInk
  var glass = false

  @Environment(\.soundPlayer) private var player
  @Environment(\.playlistStore) private var store

  var body: some View {
    if let track = player.currentTrack, let collection = player.collection {
      let saved = store.isSaved(track)
      Button {
        store.toggle(track, from: collection)
      } label: {
        Image(systemName: saved ? "bookmark.fill" : "bookmark")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(saved ? ink.primary : ink.secondary)
          .contentTransition(.symbolEffect(.replace))
          .frame(width: 44, height: 44)
          .modifier(LabGlass(enabled: glass, tinted: ink == .onPhoto))
          .contentShape(Circle())
      }
      .buttonStyle(.softPress)
      .animation(.exhale, value: saved)
      .accessibilityLabel(saved ? "Saved to playlist" : "Save to playlist")
    }
  }
}

struct LabIconButton: View {
  var systemName: String
  var ink: LabInk
  var glass = false
  var label: String
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(ink.primary)
        .frame(width: 44, height: 44)
        .modifier(LabGlass(enabled: glass, tinted: ink == .onPhoto))
        .contentShape(Circle())
    }
    .buttonStyle(.softPress)
    .accessibilityLabel(label)
  }
}

/// Glass chevron that pulls the player back into the mini bar.
struct LabDismissButton: View {
  var ink: LabInk
  var action: () -> Void

  var body: some View {
    LabIconButton(systemName: "chevron.down", ink: ink, glass: true, label: "Close player", action: action)
  }
}

/// The onboarding back button's look (`OnboardingChromeBar`) — a frosted
/// cream circle with a plum back chevron.
struct LabFrostedDismissButton: View {
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "chevron.backward")
        .font(DeepType.sectionTitle)
        .foregroundStyle(.deepPlum)
        .frame(width: 40, height: 40)
        .background(FrostedCardBackground(cornerRadius: .chip))
        .contentShape(Circle())
    }
    .buttonStyle(.softPress)
    .accessibilityLabel("Close player")
  }
}

struct LabVolume: View {
  var ink: LabInk

  @Environment(\.soundPlayer) private var player

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "speaker.fill")
      SoundSlider(
        value: Binding(get: { player.volume }, set: { player.volume = $0 }),
        activeColor: ink.sliderFill.opacity(0.8),
        trackHeight: 4
      )
      Image(systemName: "speaker.wave.3.fill")
    }
    .font(.footnote)
    .foregroundStyle(ink.secondary)
  }
}

/// Liquid Glass on iOS 26, frosted material before — `GlassCloseButton`'s recipe.
/// `tinted` steeps the glass in plum so a light glyph reads over a pale photo
/// as well as a dark one.
struct LabGlass: ViewModifier {
  var enabled = true
  var tinted = false

  func body(content: Content) -> some View {
    if !enabled {
      content
    } else if #available(iOS 26.0, *) {
      content.glassEffect(
        (tinted ? Glass.regular.tint(.deepPlum.opacity(0.35)) : .regular).interactive(),
        in: Circle()
      )
    } else {
      content.background(Circle().fill(.ultraThinMaterial))
    }
  }
}

extension View {
  /// The lyrics sheet, presented exactly as `NowPlayingView` does.
  func labLyrics(isPresented: Binding<Bool>) -> some View {
    modifier(LabLyricsSheet(isPresented: isPresented))
  }
}

private struct LabLyricsSheet: ViewModifier {
  @Binding var isPresented: Bool
  @Environment(\.soundPlayer) private var player

  func body(content: Content) -> some View {
    content.sheet(isPresented: $isPresented) {
      if let track = player.currentTrack {
        LyricsSheet(track: track)
          .presentationDetents([.medium, .large])
          .presentationBackground(.ultraThinMaterial)
      }
    }
  }
}

#Preview("Lab parts") {
  ZStack {
    LabArtwork().ignoresSafeArea()
    VStack(spacing: 24) {
      LabScrubber(ink: .onPhoto)
      HStack(spacing: 24) {
        LabSkipButton(direction: .back, ink: .onPhoto)
        LabPlayButton(ink: .onPhoto)
        LabPlayButton(ink: .onPhoto, filled: false)
        LabSkipButton(direction: .forward, ink: .onPhoto)
      }
      HStack {
        LabDismissButton(ink: .onPhoto) {}
        LabSaveButton(ink: .onPhoto, glass: true)
      }
    }
    .padding(.horizontal, .edge)
  }
  .environment(\.soundPlayer, MockSoundPlayer.playing)
}
#endif
