import SwiftUI

/// A cause in full — the screen the references depict, re-laid-out for mobile in
/// the Deep language. A motif hero, the partner behind it, community stats, the
/// projects hearts move, the user's impact, and an ever-present way to give.
///
/// This is the leaf screen, so it owns its styling and hides the navigation bar,
/// providing its own back affordance. It reads the *live* cause from the ledger
/// so totals climb as hearts are sent.
struct CompassionCategoryView: View {
  @Environment(\.heartLedger) private var ledger
  @Environment(\.dismiss) private var dismiss
  let category: CompassionCategory

  private let heroHeight: CGFloat = 260

  /// The latest snapshot of this cause (totals shift as hearts are sent).
  private var live: CompassionCategory {
    ledger.category(category.id) ?? category
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        hero

        VStack(alignment: .leading, spacing: .rhythm) {
          PartnerOrganizationCard(partner: live.partner)
            .padding(.horizontal, .edge)

          CategoryStatsRow(category: live)
            .padding(.horizontal, .edge)

          projects

          ImpactSection(category: live, heartsGiven: ledger.heartsGiven)
            .padding(.horizontal, .edge)
        }
        .padding(.top, .rhythm)
        .padding(.bottom, .rhythm)
      }
    }
    .scrollIndicators(.hidden)
    .ignoresSafeArea(edges: .top)
    .background { AtmosphereBackground() }
    .safeAreaInset(edge: .top) { topBar }
    .safeAreaInset(edge: .bottom) { SendAHeartBar(category: live) }
    .toolbar(.hidden, for: .navigationBar)
  }

  private var hero: some View {
    ZStack(alignment: .bottomLeading) {
      CompassionMotif(symbol: live.symbol, palette: live.palette, cornerRadius: 0, symbolScale: 0.22)
        .frame(height: heroHeight)
        .overlay {
          LinearGradient(
            colors: [.clear, Color.deepPlum.opacity(0.35)],
            startPoint: .center,
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
      .shadow(color: Color.deepPlum.opacity(0.3), radius: 8, y: 3)
      .padding(.horizontal, .edge)
      .padding(.bottom, 20)
    }
  }

  private var topBar: some View {
    HStack {
      Button {
        dismiss()
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 40, height: 40)
          .background(.ultraThinMaterial, in: Circle())
          .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
      }
      .buttonStyle(.softPress)
      .accessibilityLabel("Back")

      Spacer()

      HeartBalanceChip(balance: ledger.balance, overDarkHero: true)
    }
    .padding(.horizontal, .edge)
    .padding(.vertical, 8)
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
}

/// The user's personal footprint within this one cause.
private struct ImpactSection: View {
  let category: CompassionCategory
  let heartsGiven: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Your impact here")
        .font(DeepType.sectionTitle)
        .foregroundStyle(.deepPlum)

      ImpactCluster(stats: [
        ImpactStat(label: "Projects", value: category.projects.count.formatted(), symbol: "square.stack.3d.up.fill"),
        ImpactStat(label: "People reached", value: category.peopleReached.formatted(.number.notation(.compactName)), symbol: "person.2.fill"),
        ImpactStat(label: "Hearts pooled", value: category.heartsShared.formatted(.number.notation(.compactName)), symbol: "heart.fill"),
      ])
    }
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
