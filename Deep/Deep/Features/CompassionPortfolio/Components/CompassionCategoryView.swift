import SwiftUI

/// A cause in full, told in order: meet it, see its scale, back a project, learn
/// who does the work on the ground, and close on your own part in it. Ending on
/// reflection rather than an ask is deliberate — an invitation, never a demand.
///
/// This is the leaf screen, so it owns its styling and hides the navigation bar,
/// providing its own back affordance. It reads the *live* cause from the ledger
/// so totals climb as hearts are sent.
struct CompassionCategoryView: View {
  @Environment(\.heartLedger) private var ledger
  @Environment(\.dismiss) private var dismiss
  let category: CompassionCategory

  private let heroHeight: CGFloat = 288
  /// Upward scroll distance, normalised so 0 is the resting top.
  @State private var scrollY: CGFloat = 0

  /// The latest snapshot of this cause (totals shift as hearts are sent).
  private var live: CompassionCategory {
    ledger.category(category.id) ?? category
  }

  /// 0 while the top bar still floats over the hero artwork, 1 once it has left
  /// it for the pale atmosphere — where a white chevron and a white chip would
  /// otherwise vanish.
  private var barProgress: CGFloat {
    let start = heroHeight - 150
    return min(1, max(0, (scrollY - start) / 60))
  }

  private var overHero: Bool { barProgress < 0.5 }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        hero

        VStack(alignment: .leading, spacing: .rhythm) {
          ImpactPebbles(stats: communityStats)
            .padding(.horizontal, .edge)

          projects

          PartnerOrganizationCard(partner: live.partner)
            .padding(.horizontal, .edge)

          YourPartCard(category: live, heartsGiven: ledger.heartsGiven(in: live.id))
            .padding(.horizontal, .edge)
        }
        .padding(.top, .rhythm)
        // Clears the send bar's feathered strip, so the closing line is never
        // left blurred at the end of the scroll.
        .padding(.bottom, .rhythm * 3)
      }
    }
    .scrollIndicators(.hidden)
    .ignoresSafeArea(edges: .top)
    .onScrollGeometryChange(for: CGFloat.self) { geometry in
      geometry.contentOffset.y + geometry.contentInsets.top
    } action: { _, newValue in
      scrollY = newValue
    }
    .background { AtmosphereBackground() }
    .safeAreaInset(edge: .top) { topBar }
    .safeAreaInset(edge: .bottom) { sendBar }
    .toolbar(.hidden, for: .navigationBar)
  }

  /// The cause's own figures — all community-level, and labelled as such. The
  /// member's own contribution is told separately, in words, at the close.
  private var communityStats: [ImpactStat] {
    [
      ImpactStat(
        label: "Hearts pooled",
        value: live.heartsShared.formatted(.number.notation(.compactName)),
        symbol: "heart.fill"
      ),
      ImpactStat(
        label: "People reached",
        value: live.peopleReached.formatted(.number.notation(.compactName)),
        symbol: "person.2.fill"
      ),
      ImpactStat(
        label: "Share of giving",
        value: "\(Int((live.allocation * 100).rounded()))%",
        symbol: "chart.pie.fill"
      ),
    ]
  }

  /// The cause's motif at hero scale. The symbol retreats to a large, soft,
  /// cropped watermark — a crisp centred glyph at this size reads as a missing
  /// image — the border is switched off, and the artwork's lower edge is
  /// feathered so it dissolves into the atmosphere instead of ending on a line.
  private var hero: some View {
    ZStack(alignment: .bottomLeading) {
      CompassionMotif(
        symbol: live.symbol,
        palette: live.palette,
        cornerRadius: 0,
        symbolScale: 0.95,
        symbolOpacity: 0.22,
        symbolBlur: 2,
        symbolAlignment: .trailing,
        bordered: false
      )
      .frame(height: heroHeight)
      // The app's standard over-media recipe: progressive blur under a soft
      // scrim, so the title floats instead of sitting on an edge.
      .overlay(alignment: .bottom) {
        VariableBlurView(maxBlurRadius: 4, direction: .blurredBottomClearTop)
          .frame(height: 130)
      }
      .overlay {
        LinearGradient(
          colors: [.clear, Color.deepPlum.opacity(0.42)],
          startPoint: .center,
          endPoint: .bottom
        )
      }
      .mask {
        LinearGradient(
          stops: [
            .init(color: .black, location: 0),
            .init(color: .black, location: 0.85),
            .init(color: .black.opacity(0), location: 1),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(live.name)
          .font(DeepType.wordmark)
          .foregroundStyle(.white)
        Text(live.tagline)
          .font(DeepType.body)
          .foregroundStyle(.white.opacity(0.9))
      }
      .shadow(color: Color.deepPlum.opacity(0.35), radius: 8, y: 3)
      .padding(.horizontal, .edge)
      // Clear of the feathered edge, so the title never fades with the artwork.
      .padding(.bottom, 48)
    }
  }

  private var topBar: some View {
    HStack {
      Button {
        dismiss()
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.white.mix(with: .deepPlum, by: barProgress))
          .frame(width: 40, height: 40)
          .background {
            ZStack {
              Circle().fill(.ultraThinMaterial).opacity(1 - barProgress)
              Circle().fill(.white.opacity(0.65)).opacity(barProgress)
            }
          }
          .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
      }
      .buttonStyle(.softPress)
      .accessibilityLabel("Back")

      Spacer()

      HeartBalanceChip(balance: ledger.balance, overDarkHero: overHero)
    }
    .padding(.horizontal, .edge)
    .padding(.vertical, 8)
    .animation(.exhale, value: overHero)
    .background(alignment: .top) {
      VariableBlurView(maxBlurRadius: 20, direction: .blurredTopClearBottom)
        .opacity(barProgress)
        .allowsHitTesting(false)
        .ignoresSafeArea(edges: .top)
    }
  }

  private var projects: some View {
    VStack(alignment: .leading, spacing: 14) {
      HomeSectionHeader(title: "Projects in this cause")

      VStack(spacing: 12) {
        ForEach(live.projects) { project in
          CompassionProjectCard(category: live, project: project)
        }
      }
      .padding(.horizontal, .edge)
    }
  }

  /// The CTA rides a feathered blur so the scroll dissolves beneath it instead
  /// of colliding with a floating capsule.
  private var sendBar: some View {
    SendAHeartBar(category: live)
      .background(alignment: .bottom) {
        VariableBlurView(maxBlurRadius: 12, direction: .blurredBottomClearTop)
          .frame(height: 130)
          .allowsHitTesting(false)
          .ignoresSafeArea(edges: .bottom)
      }
  }
}

/// What this member has personally put into the cause — told in a sentence,
/// because a stat column would make one warm fact look like a scoreboard. With
/// nothing given yet it becomes an invitation rather than an empty figure.
private struct YourPartCard: View {
  let category: CompassionCategory
  let heartsGiven: Int

  private var line: String {
    guard heartsGiven > 0 else {
      return "No hearts here yet — the first one is yours to send."
    }
    let hearts = heartsGiven == 1 ? "heart" : "hearts"
    return "You've sent \(heartsGiven.formatted()) \(hearts) to this cause."
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("YOUR PART")
        .font(DeepType.micro)
        .tracking(.microTracking)
        .foregroundStyle(.lavenderMist)

      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "heart.fill")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.blushPowder)
          .padding(.top, 2)
        Text(line)
          .font(DeepType.body)
          .foregroundStyle(.deepPlum)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
      }
    }
    .padding(18)
    .frostedCard(tint: category.palette.colors.first)
    .accessibilityElement(children: .combine)
  }
}

#Preview("Compassion — Cause detail") {
  NavigationStack {
    CompassionCategoryView(category: CompassionLibrary.healthcare)
      .environment(\.heartLedger, .sample)
  }
}

#Preview("Compassion — Cause detail (spent)") {
  NavigationStack {
    CompassionCategoryView(category: CompassionLibrary.peace)
      .environment(\.heartLedger, .spent)
  }
}

#Preview("Compassion — Cause detail (nothing given)") {
  NavigationStack {
    CompassionCategoryView(category: CompassionLibrary.community)
      .environment(\.heartLedger, .fresh)
  }
}
