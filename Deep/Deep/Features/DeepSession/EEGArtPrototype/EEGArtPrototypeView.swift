#if DEBUG
import SwiftUI

// PROTOTYPE — throwaway, DEBUG only.
// Three structurally different ways to see one meditation's EEG, on one
// screen, flipped from a floating bar: A Scientific Waveform, B Mindful
// Flower Art, C Aurora Art. Every variant reads the same simulated Muse 2
// session (`MuseSimulator.swift`). Boot straight in with `-eegArtPrototype`;
// `-hidePrototypeSwitcher` keeps the bar out of recordings.
// Plan: ~/.claude/plans/my-client-would-like-staged-sphinx.md

enum EEGArtVariant: String, CaseIterable, Identifiable {
  case a, b, c

  var id: String { rawValue }

  var title: String {
    switch self {
    case .a: "Scientific Waveform"
    case .b: "Mindful Flower"
    case .c: "Aurora"
    }
  }
}

/// During the sit, or the finished piece after it.
enum EEGArtStage: String, CaseIterable, Identifiable {
  case live, after

  var id: String { rawValue }

  var label: String {
    switch self {
    case .live: "Live"
    case .after: "After"
    }
  }
}

/// Hosts the variant being judged plus the switcher. Variant, person and stage
/// survive relaunch, the iOS stand-in for a `?variant=` URL.
struct EEGArtPrototypeView: View {
  @AppStorage("prototype.eegArt.variant") private var variant = EEGArtVariant.a
  @AppStorage("prototype.eegArt.person") private var person = EEGPerson.regular
  @AppStorage("prototype.eegArt.stage") private var stage = EEGArtStage.live
  @State private var player: EEGSessionPlayer?
  @State private var speed = EEGSessionPlayer.Speed.calm

  var body: some View {
    ZStack(alignment: .bottom) {
      Color.black.ignoresSafeArea()

      if let player {
        Group {
          switch variant {
          case .a: EEGScientificView(player: player, stage: stage)
          case .b: EEGFlowerView(player: player, stage: stage)
          case .c: EEGAuroraView(player: player, stage: stage)
          }
        }
        // A fresh identity per variant, person and stage, so each starts from
        // its own first moment instead of inheriting the last one's state.
        .id("\(variant.rawValue)-\(person.rawValue)-\(stage.rawValue)")
        .transition(.opacity)
      }

      if !ProcessInfo.processInfo.arguments.contains("-hidePrototypeSwitcher") {
        EEGArtPrototypeSwitcher(
          variant: $variant,
          person: $person,
          stage: $stage,
          speed: $speed,
          progress: player?.progress ?? 0,
          onRestart: { player?.restart() }
        )
        .padding(.bottom, 4)
      }
    }
    .animation(.exhale, value: variant)
    .animation(.exhale, value: stage)
    .onAppear { makePlayer() }
    .onChange(of: person) { makePlayer() }
    .onChange(of: speed) { player?.speed = speed }
    .onDisappear { player?.stop() }
  }

  private func makePlayer() {
    player?.stop()
    let next = EEGSessionPlayer(recording: .fixture(person), speed: speed)
    next.start()
    player = next
  }
}

#Preview("EEG Art prototype") {
  EEGArtPrototypeView()
}
#endif
