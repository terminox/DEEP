#if DEBUG
import SwiftUI

// PROTOTYPE, throwaway. Plays a gift inside the donate sheet: A, B and E here;
// C and D only close the sheet and hand the moment on.

private struct HeartThanksSheetStage: ViewModifier {
  @Environment(\.heartThanksPrototype) private var prototype
  @Environment(\.dismiss) private var dismiss

  func body(content: Content) -> some View {
    content
      .overlayPreferenceValue(HeartThanksSheetAnchors.self) { anchors in
        GeometryReader { proxy in
          if let prototype, let moment = prototype.sheetMoment {
            SheetStage(
              moment: moment,
              variant: prototype.variant,
              frames: anchors.mapValues { proxy[$0] },
              width: proxy.size.width,
              prototype: prototype,
              dismiss: dismiss
            )
            .id(moment.id)
          }
        }
      }
      .onAppear { prototype?.resetSheet() }
  }
}

extension View {
  func prototypeSheetStage() -> some View {
    modifier(HeartThanksSheetStage())
  }
}

private struct SheetStage: View {
  let moment: HeartThanksMoment
  let variant: HeartThanksVariant
  let frames: [HeartThanksSpot: CGRect]
  /// The sheet's width, so a thank-you line can use the whole of it.
  let width: CGFloat
  let prototype: HeartThanksPrototype
  let dismiss: DismissAction

  @State private var plan: HeartSwarmPlan
  /// Where the swarm left from, frozen at the tap.
  @State private var origin: CGPoint?
  @State private var gave = 0
  @State private var landed = 0
  @State private var showThanks = false
  @State private var halo = false

  init(
    moment: HeartThanksMoment,
    variant: HeartThanksVariant,
    frames: [HeartThanksSpot: CGRect],
    width: CGFloat,
    prototype: HeartThanksPrototype,
    dismiss: DismissAction
  ) {
    self.moment = moment
    self.variant = variant
    self.frames = frames
    self.width = width
    self.prototype = prototype
    self.dismiss = dismiss
    let mode: HeartSwarmPlan.Mode = switch variant {
    case .toCause: .arc
    case .confetti: .confetti
    default: .rise
    }
    _plan = State(initialValue: HeartSwarmPlan(mode: mode, budget: moment.particles))
  }

  var body: some View {
    ZStack {
      switch variant {
      case .inSheet: inSheet
      case .toCause: toCause
      case .confetti: confetti
      default: Color.clear
      }
    }
    .sensoryFeedback(variant == .confetti ? .impact(weight: .medium) : .impact(weight: .light), trigger: gave)
    .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: landed)
    .task { await run() }
  }

  private var ctaTop: CGPoint {
    origin ?? frames[.cta].map { CGPoint(x: $0.midX, y: $0.minY + 8) } ?? .zero
  }

  // MARK: - A · in the sheet

  private var inSheet: some View {
    ZStack {
      if showThanks {
        VStack(spacing: 22) {
          CompassionMotif(symbol: moment.category.symbol, palette: moment.category.palette, cornerRadius: .tile)
            .frame(width: 88, height: 88)
            .overlay { if halo { HaloRingPrototype(cornerRadius: .tile) } }

          VStack(spacing: 8) {
            Text(moment.thanks)
              .font(DeepType.displayTitle)
              .foregroundStyle(.deepPlum)
              .multilineTextAlignment(.center)
            amountLabel
          }

          Button { dismiss() } label: {
            Text("Done")
              .font(DeepType.sectionTitle)
              .foregroundStyle(.white)
              .padding(.vertical, 16)
              .frame(maxWidth: .infinity)
              .background {
                Capsule().fill(
                  LinearGradient(colors: [.lavenderMist, .blushPowder], startPoint: .leading, endPoint: .trailing)
                )
              }
              .shadow(color: Color.lavenderMist.opacity(0.35), radius: 18, y: 10)
          }
          .buttonStyle(.softPress)
          .padding(.top, 12)
        }
        .padding(.horizontal, .edge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
      }
      HeartSwarmPrototype(plan: plan, origin: ctaTop)
    }
    .contentShape(Rectangle())
  }

  // MARK: - B · hearts fly to the cause

  @ViewBuilder
  private var toCause: some View {
    ZStack {
      if let motif = frames[.motif] {
        HeartSwarmPrototype(plan: plan, origin: ctaTop, target: CGPoint(x: motif.midX, y: motif.midY))
        if halo {
          HaloRingPrototype(cornerRadius: 14)
            .frame(width: motif.width, height: motif.height)
            .position(x: motif.midX, y: motif.midY)
        }
      }
      if showThanks, let text = frames[.causeText] {
        VStack(alignment: .leading, spacing: 2) {
          Text(moment.thanks)
            .font(DeepType.sectionTitle)
            .foregroundStyle(.deepPlum)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
          amountLabel
        }
        .frame(width: text.width, alignment: .leading)
        .position(x: text.midX, y: text.midY)
        .transition(.opacity)
      }
    }
  }

  // MARK: - E · confetti

  @ViewBuilder
  private var confetti: some View {
    ZStack {
      if showThanks, let readout = frames[.readout] {
        VStack(spacing: 6) {
          Text(moment.thanks)
            .font(DeepType.displayTitle)
            .foregroundStyle(.deepPlum)
            .multilineTextAlignment(.center)
          amountLabel
        }
        .frame(width: width - 2 * .edge)
        .position(x: readout.midX, y: readout.midY)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
      }
      HeartSwarmPrototype(plan: plan, origin: ctaTop)
    }
  }

  private var amountLabel: some View {
    Label(moment.amountLine, systemImage: "heart.fill")
      .font(DeepType.caption.weight(.medium))
      .foregroundStyle(.driftGrey)
      .labelStyle(TintedHeartLabel())
  }

  // MARK: - Choreography

  private func run() async {
    origin = ctaTop
    gave += 1
    switch variant {
    case .inSheet:
      try? await Task.sleep(for: .seconds(0.15))
      prototype.hidden = [.content]
      try? await Task.sleep(for: .seconds(0.35))
      withAnimation(.bloom) { showThanks = true }
      try? await Task.sleep(for: .seconds(0.3))
      halo = true

    case .toCause:
      await land()
      halo = true
      prototype.hidden.insert(.causeText)
      withAnimation(.bloom) { showThanks = true }
      try? await Task.sleep(for: .seconds(1.8))
      dismiss()

    case .confetti:
      try? await Task.sleep(for: .seconds(0.25))
      prototype.hidden.insert(.readout)
      withAnimation(.bloom) { showThanks = true }
      try? await Task.sleep(for: .seconds(2.4))
      dismiss()

    case .fullScreen, .onCard:
      dismiss()

    case .current:
      break
    }
  }

  /// Beats the cause motif as each heart lands; haptics no closer than 0.1s,
  /// so 24 hearts read as a patter, not a buzz.
  private func land() async {
    var clock = 0.0
    var lastTick = -1.0
    for arrival in plan.arrivals {
      try? await Task.sleep(for: .seconds(arrival - clock))
      clock = arrival
      prototype.motifBeat += 1
      if arrival - lastTick >= 0.1 {
        landed += 1
        lastTick = arrival
      }
    }
  }
}

/// Heart glyph in blush, words in whatever the label's style is.
struct TintedHeartLabel: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 6) {
      configuration.icon.foregroundStyle(.blushPowder)
      configuration.title
    }
  }
}
#endif
