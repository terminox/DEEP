#if DEBUG
import SwiftUI

// PROTOTYPE, throwaway. The two variants that play after the sheet has gone:
// C (a full-screen moment the coordinator presents) and D (hearts drifting
// into the cause card on the home).

// MARK: - C · full-screen moment

private struct HeartThanksCoverHost: ViewModifier {
  @Bindable var prototype: HeartThanksPrototype

  func body(content: Content) -> some View {
    content.fullScreenCover(item: $prototype.coverMoment) { moment in
      HeartThanksCoverPrototype(moment: moment) {
        var quiet = Transaction()
        quiet.disablesAnimations = true
        withTransaction(quiet) { prototype.coverMoment = nil }
      }
      .presentationBackground(.clear)
    }
  }
}

extension View {
  func prototypeThanksCover(_ prototype: HeartThanksPrototype) -> some View {
    modifier(HeartThanksCoverHost(prototype: prototype))
  }
}

struct HeartThanksCoverPrototype: View {
  let moment: HeartThanksMoment
  let close: () -> Void

  @State private var shown = false
  @State private var halo = false
  @State private var plan: HeartSwarmPlan

  init(moment: HeartThanksMoment, close: @escaping () -> Void) {
    self.moment = moment
    self.close = close
    _plan = State(initialValue: HeartSwarmPlan(mode: .bokeh, budget: moment.particles))
  }

  var body: some View {
    ZStack {
      // The atmosphere's lower stops are translucent by design; it always
      // sits on moonCream, so a clear cover has to bring its own.
      Color.moonCream.ignoresSafeArea()
      AtmosphereBackground()
      HeartSwarmPrototype(plan: plan)
        .ignoresSafeArea()

      VStack(spacing: 24) {
        CompassionMotif(symbol: moment.category.symbol, palette: moment.category.palette, cornerRadius: .card)
          .frame(width: 112, height: 112)
          .overlay { if halo { HaloRingPrototype(cornerRadius: .card) } }

        VStack(spacing: 10) {
          Text(moment.thanks)
            .font(DeepType.wordmark)
            .foregroundStyle(.deepPlum)
            .multilineTextAlignment(.center)
          Label(moment.amountLine, systemImage: "heart.fill")
            .font(DeepType.body.weight(.medium))
            .foregroundStyle(.driftGrey)
            .labelStyle(TintedHeartLabel())
        }
      }
      .padding(.horizontal, 32)

      Text("Tap anywhere to continue")
        .font(DeepType.micro)
        .foregroundStyle(.driftGrey)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 24)
    }
    .opacity(shown ? 1 : 0)
    .contentShape(Rectangle())
    .onTapGesture {
      withAnimation(.exhale) { shown = false } completion: { close() }
    }
    .sensoryFeedback(.success, trigger: shown) { _, new in new }
    .task {
      withAnimation(.hush) { shown = true }
      try? await Task.sleep(for: .seconds(0.6))
      halo = true
    }
  }
}

// MARK: - D · on the cause card

private struct HeartThanksCardStage: ViewModifier {
  @Environment(\.heartThanksPrototype) private var prototype

  func body(content: Content) -> some View {
    content.overlayPreferenceValue(HeartThanksTileAnchors.self) { anchors in
      GeometryReader { proxy in
        if let prototype, let moment = prototype.cardMoment, let anchor = anchors[moment.category.id] {
          CardStage(moment: moment, tile: proxy[anchor], bounds: proxy.size, prototype: prototype)
            .id(moment.id)
        }
      }
      .allowsHitTesting(false)
    }
  }
}

private struct CardStage: View {
  let moment: HeartThanksMoment
  let tile: CGRect
  let bounds: CGSize
  let prototype: HeartThanksPrototype

  @State private var plan: HeartSwarmPlan
  @State private var flying = false
  @State private var landed = 0

  init(moment: HeartThanksMoment, tile: CGRect, bounds: CGSize, prototype: HeartThanksPrototype) {
    self.moment = moment
    self.tile = tile
    self.bounds = bounds
    self.prototype = prototype
    _plan = State(initialValue: HeartSwarmPlan(mode: .arc, budget: moment.particles))
  }

  var body: some View {
    ZStack {
      if flying {
        HeartSwarmPrototype(
          plan: plan,
          origin: CGPoint(x: bounds.width / 2, y: bounds.height - 40),
          target: CGPoint(x: tile.midX, y: tile.midY)
        )
      }
    }
    .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: landed)
    .task {
      // Let the sheet get out of the way first.
      try? await Task.sleep(for: .seconds(0.35))
      flying = true
      var clock = 0.0
      var lastTick = -1.0
      for arrival in plan.arrivals {
        try? await Task.sleep(for: .seconds(arrival - clock))
        clock = arrival
        prototype.tileBeats[moment.category.id, default: 0] += 1
        if arrival - lastTick >= 0.1 {
          landed += 1
          lastTick = arrival
        }
      }
      prototype.tileThanks = moment
      try? await Task.sleep(for: .seconds(4.5))
      prototype.tileThanks = nil
      prototype.cardMoment = nil
    }
  }
}

private struct HeartThanksTileNote: ViewModifier {
  @Environment(\.heartThanksPrototype) private var prototype
  let categoryID: String

  func body(content: Content) -> some View {
    let moment = prototype?.tileThanks?.category.id == categoryID ? prototype?.tileThanks : nil
    content
      .anchorPreference(key: HeartThanksTileAnchors.self, value: .bounds) { [categoryID: $0] }
      .prototypeBeat(prototype?.tileBeats[categoryID] ?? 0)
      .overlay {
        if let moment {
          VStack(spacing: 6) {
            Text(moment.thanks)
              .font(DeepType.displayTitle)
              .foregroundStyle(.deepPlum)
              .multilineTextAlignment(.center)
              .minimumScaleFactor(0.8)
            Label(moment.amountLine, systemImage: "heart.fill")
              .font(DeepType.caption.weight(.medium))
              .foregroundStyle(.driftGrey)
              .labelStyle(TintedHeartLabel())
          }
          .padding(.horizontal, 14)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color.moonCream.opacity(0.86))
          .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
      }
      .overlay { if moment != nil { HaloRingPrototype(cornerRadius: .card) } }
      .animation(.bloom, value: moment?.id)
  }
}

extension View {
  func prototypeCardStage() -> some View {
    modifier(HeartThanksCardStage())
  }

  /// On a cause tile's banner: where D's hearts land and its note blooms.
  func prototypeTileNote(_ categoryID: String) -> some View {
    modifier(HeartThanksTileNote(categoryID: categoryID))
  }
}
#endif
