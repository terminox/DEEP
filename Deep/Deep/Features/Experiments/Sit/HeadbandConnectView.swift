#if EXPERIMENTS
import SwiftUI

/// Step 1: explain why DEEP needs Bluetooth, then find the headband and tap it.
struct HeadbandConnectView: View {
  let headband: any MuseConnecting
  let onClose: () -> Void

  @State private var searchingSince: Date?

  var body: some View {
    SitStepScaffold(title: "Connect your Muse", onClose: onClose) {
      switch headband.link {
      case .idle where searchingSince == nil:
        introduction
      case .failed(let problem):
        ProblemCard(problem: problem) { search() }
      case .connecting(let found), .reconnecting(let found, _):
        connecting(to: found)
      default:
        searching
      }
      Spacer(minLength: 0)
    }
  }

  private var introduction: some View {
    VStack(alignment: .leading, spacing: .rhythm) {
      Text("Your headband reads your brainwaves while you sit, and DEEP turns them into art as it happens. They connect over Bluetooth; iOS will ask you to allow it.")
        .font(DeepType.body)
        .foregroundStyle(.deepPlum.opacity(0.8))
      ConnectTips()
      Spacer(minLength: 0)
      OnboardingPrimaryButton(title: "Find my headband", systemImage: "dot.radiowaves.left.and.right", action: search)
        .accessibilityIdentifier("sit.find")
        .padding(.bottom, 12)
    }
  }

  private var searching: some View {
    VStack(alignment: .leading, spacing: .rhythm) {
      HStack(spacing: 10) {
        ProgressView()
          .tint(.deepPlum)
        Text("Looking for headbands nearby…")
          .font(DeepType.body)
          .foregroundStyle(.deepPlum.opacity(0.8))
      }
      VStack(spacing: 10) {
        ForEach(headband.nearby) { found in
          Button { headband.connect(found) } label: {
            HStack(spacing: 14) {
              Image(systemName: "brain.head.profile")
                .font(.system(size: 22, weight: .light))
              VStack(alignment: .leading, spacing: 2) {
                Text(found.name)
                  .font(DeepType.sectionTitle)
                Text(found.model)
                  .font(DeepType.caption)
                  .foregroundStyle(.driftGrey)
              }
              Spacer(minLength: 0)
              Text("Connect")
                .font(DeepType.caption.weight(.semibold))
            }
            .foregroundStyle(.deepPlum)
            .padding(16)
            .frostedCard()
          }
          .buttonStyle(.softPress)
          .accessibilityIdentifier("sit.headband.\(found.name)")
        }
      }
      .animation(.exhale, value: headband.nearby)
      TimelineView(.periodic(from: .now, by: 1)) { context in
        if let searchingSince, context.date.timeIntervalSince(searchingSince) > 15, headband.nearby.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Still looking. A few things that help:")
              .font(DeepType.caption.weight(.semibold))
              .foregroundStyle(.deepPlum)
            ConnectTips()
          }
          .transition(.opacity)
        }
      }
    }
  }

  private func connecting(to found: HeadbandInfo) -> some View {
    HStack(spacing: 10) {
      ProgressView()
        .tint(.deepPlum)
      Text("Connecting to \(found.name)…")
        .font(DeepType.body)
        .foregroundStyle(.deepPlum.opacity(0.8))
    }
  }

  private func search() {
    searchingSince = Date()
    headband.startScanning()
  }
}

/// What usually stops a Muse from showing up.
private struct ConnectTips: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      tip("battery.75percent", "Charge the headband and turn it on: hold the button until the lights move.")
      tip("xmark.app", "Close the Muse app. While it's connected, no other app can be.")
      tip("antenna.radiowaves.left.and.right", "Keep Bluetooth on and the headband close to your phone.")
    }
    .padding(16)
    .frostedCard()
  }

  private func tip(_ icon: String, _ text: LocalizedStringKey) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Image(systemName: icon)
        .frame(width: 22)
        .foregroundStyle(.irisDusk)
      Text(text)
        .font(DeepType.caption)
        .foregroundStyle(.deepPlum.opacity(0.85))
    }
  }
}

/// A headband problem, what to do about it, and a way to try again.
private struct ProblemCard: View {
  let problem: HeadbandProblem
  let retry: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: .rhythm) {
      VStack(alignment: .leading, spacing: 8) {
        Text(title)
          .font(DeepType.sectionTitle)
          .foregroundStyle(.deepPlum)
        Text(detail)
          .font(DeepType.body)
          .foregroundStyle(.deepPlum.opacity(0.8))
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .frostedCard()
      if problem == .bluetoothDenied {
        OnboardingPrimaryButton(title: "Open Settings", systemImage: "gear") {
          if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        }
      } else {
        OnboardingPrimaryButton(title: "Try again", systemImage: "arrow.clockwise", action: retry)
      }
    }
  }

  private var title: LocalizedStringKey {
    switch problem {
    case .bluetoothOff: "Bluetooth is off"
    case .bluetoothDenied: "DEEP can't use Bluetooth"
    case .needsFirmwareUpdate: "Your headband needs an update"
    case .needsLicense: "This headband can't be used"
    case .connectionFailed: "Couldn't connect"
    }
  }

  private var detail: LocalizedStringKey {
    switch problem {
    case .bluetoothOff: "Turn Bluetooth on in Control Centre, then try again."
    case .bluetoothDenied: "Allow Bluetooth for DEEP in Settings so it can find your headband."
    case .needsFirmwareUpdate: "Open the Muse app to update it, close the Muse app, then come back."
    case .needsLicense: "The headband asked for a licence DEEP doesn't have."
    case .connectionFailed: "Make sure the headband is on and close by, and that the Muse app is closed."
    }
  }
}

#Preview("Connect · introduction") {
  HeadbandConnectView(headband: SimulatedHeadband(), onClose: {})
}
#endif
