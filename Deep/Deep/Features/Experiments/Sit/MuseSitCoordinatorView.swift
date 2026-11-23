#if EXPERIMENTS
import SwiftUI

/// A real sit on a Muse 2, from "find my headband" to the finished art:
/// connect → fit → length → the art playing. Owns which step is showing; each step is
/// a leaf screen. A headband that is already connected (from an earlier art) skips
/// straight to the fit check.
struct MuseSitCoordinatorView: View {
  let art: EEGArt
  let headband: any MuseConnecting
  @Environment(\.dismiss) private var dismiss
  @State private var step: Step

  private enum Step {
    case connect
    case fit
    case length
    case sitting(SitConductor)
  }

  init(art: EEGArt, headband: any MuseConnecting = Headbands.shared) {
    self.art = art
    self.headband = headband
    _step = State(initialValue: headband.link.isConnected ? .fit : .connect)
  }

  var body: some View {
    Group {
      switch step {
      case .connect:
        HeadbandConnectView(headband: headband, onClose: close)
      case .fit:
        SensorFitView(headband: headband, onClose: close) { go(to: .length) }
      case .length:
        SitLengthView(art: art, onClose: close) { length in
          go(to: .sitting(SitConductor(headband: headband, length: length.seconds)))
        }
      case .sitting(let conductor):
        ExperimentStage(art: art, conductor: conductor, isDemo: false, onClose: close)
      }
    }
    .transition(.opacity)
    .onChange(of: headband.link) { _, link in
      // Connected: on to the fit check. Lost before the sit began: back to connect.
      switch (step, link) {
      case (.connect, .connected):
        go(to: .fit)
      case (.fit, .idle), (.fit, .failed), (.length, .idle), (.length, .failed):
        go(to: .connect)
      default:
        break
      }
    }
  }

  private func go(to next: Step) {
    withAnimation(.hush) { step = next }
  }

  private func close() {
    headband.stopScanning()
    // A connection still being attempted is abandoned with the flow; a working one
    // stays up for the next art.
    if !headband.link.isConnected, headband.link.headband != nil {
      headband.disconnect()
    }
    dismiss()
  }
}

/// The light DEEP frame the steps before a sit share: atmosphere, a close button, a
/// title and the content below it.
struct SitStepScaffold<Content: View>: View {
  let title: LocalizedStringKey
  let onClose: () -> Void
  @ViewBuilder let content: Content

  var body: some View {
    ZStack {
      AtmosphereBackground()
      VStack(alignment: .leading, spacing: .rhythm) {
        Button("Close", systemImage: "xmark", action: onClose)
          .labelStyle(.iconOnly)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.deepPlum)
          .frame(width: 44, height: 44)
          .background(.ultraThinMaterial, in: Circle())
          .accessibilityIdentifier("sit.close")
        Text(title)
          .font(DeepType.displayTitle)
          .foregroundStyle(.deepPlum)
        content
      }
      .padding(.horizontal, .edge)
      .padding(.top, 8)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  }
}

#Preview("Sit flow · simulated headband") {
  MuseSitCoordinatorView(art: .lantern, headband: SimulatedHeadband())
}
#endif
