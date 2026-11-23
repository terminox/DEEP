#if EXPERIMENTS
import SwiftUI

/// Settings → Experiments: the EEG art, twice. "Live demos" play a simulated sit and
/// need nothing; "With your Muse" runs a real sit on a Muse 2 headband. Shown only in
/// Dev, Staging and the TestFlight lab build.
struct ExperimentsSettingsSection: View {
  @Binding var launch: ExperimentLaunch?
  var headband: any MuseConnecting = Headbands.shared

  var body: some View {
    SettingsSection(title: "Live demos") {
      ForEach(EEGArt.allCases) { art in
        SettingsRow(icon: art.icon, verbatim: art.title, accessory: .chevron) {
          launch = .demo(art)
        }
        .accessibilityIdentifier("experiments.demo.\(art.rawValue)")
      }
    }
    SettingsSection(title: "With your Muse") {
      if let connected = headband.link.headband, headband.link.isConnected {
        SettingsRow(
          icon: "brain.head.profile",
          verbatim: headband.isSimulated ? "\(connected.name) (simulated)" : connected.name,
          accessory: .value(headband.battery.map { "\(Int($0 * 100))%" } ?? "Connected")
        )
        SettingsRow(icon: "xmark.circle", title: "Disconnect headband", tint: .duskRose) {
          headband.disconnect()
        }
      }
      ForEach(EEGArt.allCases) { art in
        SettingsRow(icon: art.icon, verbatim: art.title, accessory: .chevron) {
          launch = .sit(art)
        }
        .accessibilityIdentifier("experiments.sit.\(art.rawValue)")
      }
    }
  }
}

extension ExperimentLaunch {
  #if DEBUG
  /// `-experiment demo.lantern` / `-experiment sit.aurora`, for QA and recordings.
  static var fromLaunchArguments: ExperimentLaunch? {
    guard let value = UserDefaults.standard.string(forKey: "experiment") else { return nil }
    let parts = value.split(separator: ".").map(String.init)
    guard parts.count == 2, let art = EEGArt(rawValue: parts[1]) else { return nil }
    switch parts[0] {
    case "demo": return .demo(art)
    case "sit": return .sit(art)
    default: return nil
    }
  }
  #endif

  /// The full-screen view Settings presents for this launch.
  @ViewBuilder
  var destination: some View {
    switch self {
    case .demo(let art): LiveDemoView(art: art)
    case .sit(let art): MuseSitCoordinatorView(art: art)
    }
  }
}

#Preview("Experiments section") {
  @Previewable @State var launch: ExperimentLaunch?
  ZStack {
    AtmosphereBackground()
    VStack(spacing: .rhythm) {
      ExperimentsSettingsSection(launch: $launch, headband: SimulatedHeadband(connected: true))
    }
    .padding(.horizontal, .edge)
  }
}
#endif
