import SwiftUI

/// Interactive preview for tuning the orb against live participant data.
///
/// Run this preview to push slider-driven counts into the EarthGlowStore and
/// watch the corresponding regions bloom. Country selector picks which country
/// the active slider drives. Tapping "Send wave" emits a ripple manually.
struct Earth3DDebugHarness: View {
  @State private var glow = EarthGlowStore()
  @State private var selectedISO: String = "TH"
  @State private var slider: Double = 0
  @State private var counts: [String: Int] = [:]

  private let featured = ["TH", "JP", "US", "FR", "BR", "IN", "ID", "DE", "AU", "ZA", "MX", "KR", "SG", "NG", "GB"]

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [.moonCream, Color.softLilac.opacity(0.35)],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      VStack(spacing: 16) {
        Earth3DView(glow: glow)
          .padding(.horizontal, 20)
          .frame(maxHeight: .infinity)

        controls
          .padding(.horizontal, 20)
          .padding(.bottom, 16)
      }
    }
  }

  private var controls: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Country").font(DeepType.micro).tracking(1.2).foregroundStyle(.driftGrey)
        Spacer()
        Picker("", selection: $selectedISO) {
          ForEach(featured, id: \.self) { iso in
            Text(label(for: iso)).tag(iso)
          }
        }
        .pickerStyle(.menu)
        .tint(.lavenderMist)
      }

      HStack {
        Text("Participants")
          .font(DeepType.micro).tracking(1.2).foregroundStyle(.driftGrey)
        Spacer()
        Text("\(Int(slider))")
          .font(DeepType.counter)
          .foregroundStyle(.deepPlum)
      }

      Slider(value: $slider, in: 0...10_000, step: 50)
        .tint(.lavenderMist)
        .onChange(of: slider) { _, newValue in
          counts[selectedISO] = Int(newValue)
          glow.participantsByCountry = counts
        }
        .onChange(of: selectedISO) { _, newISO in
          slider = Double(counts[newISO] ?? 0)
        }

      HStack(spacing: 12) {
        Button("Reset all") {
          counts = [:]
          slider = 0
          glow.participantsByCountry = [:]
        }
        .buttonStyle(.borderedProminent)
        .tint(.softLilac)

        Button("Sample world") {
          counts = [
            "TH": 1_240, "JP": 980, "US": 3_410, "FR": 870, "BR": 1_120,
            "IN": 2_300, "ID": 640, "GB": 520, "DE": 410, "AU": 180,
            "ZA": 120, "MX": 280, "KR": 560, "SG": 90,
          ]
          glow.participantsByCountry = counts
          slider = Double(counts[selectedISO] ?? 0)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blushPowder)
      }
    }
    .padding(20)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  private func label(for iso: String) -> String {
    CountryLookup.shared.country(forISO: iso)?.name ?? iso
  }
}

#Preview {
  Earth3DDebugHarness()
}

// MARK: - Shipping-globe harness (EarthSceneView)

// DEBUG-only: leans on `GlobalPauseEarthScene.preview`, which release builds
// don't compile.
#if DEBUG

/// Bridges the shipping UIKit globe into SwiftUI for the harness below.
/// Debug-only wiring; the app itself composes `EarthSceneView` in UIKit.
private struct EarthSceneRepresentable: UIViewRepresentable {
  let scene: GlobalPauseEarthScene

  func makeUIView(context: Context) -> EarthSceneView {
    let view = EarthSceneView(
      glow: scene.glow,
      interaction: scene.interaction,
      ripples: scene.ripples
    )
    view.isInteractive = true
    return view
  }

  func updateUIView(_ uiView: EarthSceneView, context: Context) {}
}

/// Exercises the shipping globe's live APIs against `EarthSceneView` — the
/// same view the card and lobby render — rather than the legacy SwiftUI one:
/// join ripples (random country), decelerate-to-hold, and resume. E2E drives
/// these buttons to verify the behaviours visually.
struct EarthSceneDebugHarness: View {
  @State private var scene = GlobalPauseEarthScene.preview
  @State private var lastWaveISO: String?

  private let featured = ["TH", "JP", "US", "FR", "BR", "IN", "ID", "DE", "AU", "ZA", "MX", "KR", "SG", "NG", "GB"]

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [.moonCream, Color.softLilac.opacity(0.35)],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      VStack(spacing: 16) {
        EarthSceneRepresentable(scene: scene)
          .padding(.horizontal, 20)
          .frame(maxHeight: .infinity)

        controls
          .padding(.horizontal, 20)
          .padding(.bottom, 16)
      }
    }
  }

  private var controls: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(spinLabel)
          .font(DeepType.micro).tracking(1.2).foregroundStyle(.driftGrey)
        Spacer()
        if let iso = lastWaveISO {
          Text("wave: \(CountryLookup.shared.country(forISO: iso)?.name ?? iso)")
            .font(DeepType.micro).foregroundStyle(.deepPlum)
        }
      }

      HStack(spacing: 12) {
        Button("Send wave") {
          let iso = featured.randomElement() ?? "TH"
          lastWaveISO = iso
          scene.ripples.emit(forISO: iso)
        }
        .buttonStyle(.borderedProminent)
        .tint(.lavenderMist)

        Button("Decelerate") {
          scene.interaction.decelerateToRest()
        }
        .buttonStyle(.borderedProminent)
        .tint(.blushPowder)

        Button("Resume") {
          scene.interaction.resumeSpin()
        }
        .buttonStyle(.borderedProminent)
        .tint(.softLilac)
      }
    }
    .padding(20)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  private var spinLabel: String {
    switch scene.interaction.spinState {
    case .free: "Spin: free"
    case .held: "Spin: held"
    }
  }
}

#Preview("Earth scene harness") {
  EarthSceneDebugHarness()
}

#endif
