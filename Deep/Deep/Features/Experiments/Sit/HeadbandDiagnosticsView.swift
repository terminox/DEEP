#if EXPERIMENTS
import SwiftUI

/// The hidden panel testers open with a long press: what the headband is sending, and
/// a "Copy report" button so they can paste it into TestFlight feedback. Nothing is
/// stored; the report is built when copied.
struct HeadbandDiagnosticsView: View {
  let headband: any MuseConnecting
  let sit: LiveSit?
  let onClose: () -> Void

  @State private var copied = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Diagnostics")
          .font(.system(size: 13, weight: .bold))
        Spacer(minLength: 12)
        if let simulated = headband as? SimulatedHeadband {
          // Exercises "Reconnecting…" without a real headband.
          Button("Drop link") { simulated.simulateDrop(for: 5) }
            .font(.system(size: 12, weight: .semibold))
            .accessibilityIdentifier("diagnostics.drop")
        }
        Button("Copy report", systemImage: copied ? "checkmark" : "doc.on.doc", action: copy)
          .font(.system(size: 12, weight: .semibold))
        Button("Close", systemImage: "xmark", action: onClose)
          .labelStyle(.iconOnly)
          .font(.system(size: 12, weight: .bold))
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(rows, id: \.label) { row in
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Text(row.label)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 96, alignment: .leading)
              Text(row.value)
                .textSelection(.enabled)
            }
          }
          ForEach(Array(headband.diagnostics.log.suffix(12).enumerated()), id: \.offset) { _, line in
            Text(line)
              .foregroundStyle(.white.opacity(0.55))
              .lineLimit(2)
          }
        }
        .font(.system(size: 11, design: .monospaced))
      }
      .frame(maxHeight: 320)
    }
    .foregroundStyle(.white)
    .padding(14)
    .frame(maxWidth: 360)
    .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private var rows: [(label: String, value: String)] {
    var rows = headband.diagnostics.readings.map { ($0.label, $0.value) }
    if let sit {
      rows.append(("Sit", String(format: "%.0f / %.0f s · %d frames · %d artifacts", sit.elapsed, sit.length, sit.frames.count, sit.events.count)))
      rows.append(("Paused", sit.pause.map { "\($0)" } ?? "no"))
    }
    rows.append(("Build", Self.build))
    return rows
  }

  private static var build: String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "?"
    let number = info?["CFBundleVersion"] as? String ?? "?"
    let flavor = info?["DeepBuildFlavor"] as? String ?? "?"
    return "\(version) (\(number)) \(flavor)"
  }

  private func copy() {
    let lines = rows.map { "\($0.label): \($0.value)" } + ["", "Log:"] + headband.diagnostics.log
    UIPasteboard.general.string = "DEEP Muse report\n" + lines.joined(separator: "\n")
    withAnimation(.exhale) { copied = true }
  }
}

#Preview("Diagnostics") {
  ZStack {
    Color.indigo.ignoresSafeArea()
    HeadbandDiagnosticsView(
      headband: SimulatedHeadband(connected: true),
      sit: .replaying(.regular, length: 300, upTo: 60),
      onClose: {}
    )
  }
}
#endif
