import SwiftUI

/// A single cause in the portfolio's "where your hearts go" list. The card wears
/// a wash of the cause's own palette, so five causes read as five warmths rather
/// than five identical boxes. Tapping it routes to the cause detail through the
/// coordinator's injected `openCategory` action — never a `NavigationLink`.
struct CategoryTile: View {
  @Environment(\.openCategory) private var openCategory
  let category: CompassionCategory

  var body: some View {
    Button {
      openCategory(category)
    } label: {
      HStack(spacing: 14) {
        CompassionMotif(symbol: category.symbol, palette: category.palette)
          .frame(width: 60, height: 60)

        VStack(alignment: .leading, spacing: 4) {
          Text(category.name)
            .font(DeepType.sectionTitle)
            .foregroundStyle(.deepPlum)
            .lineLimit(2)
          Text(category.tagline)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .lineLimit(1)

          // Two facts, held apart by space rather than a middot.
          HStack(spacing: 12) {
            fact(symbol: "heart.fill", tint: .blushPowder) {
              Text("\(category.heartsShared.formatted(.number.notation(.compactName))) shared")
                .contentTransition(.numericText(value: Double(category.heartsShared)))
            }
            fact(symbol: "chart.pie.fill", tint: .lavenderMist) {
              Text("\(Int((category.allocation * 100).rounded()))% of giving")
            }
          }
          .font(DeepType.caption.weight(.medium))
          .foregroundStyle(.driftGrey)
          .padding(.top, 2)
        }
        // Claims the leftover width outright. A `Spacer` here competes with the
        // text for it, and the title and tagline lose — wrapping and truncating
        // on a row that has room to spare.
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.lavenderMist.opacity(0.7))
      }
      .padding(14)
      .frostedCard(tint: category.palette.colors.first)
    }
    .buttonStyle(.softPress)
    .accessibilityElement(children: .combine)
    .accessibilityHint("Opens \(category.name)")
  }

  private func fact<Label: View>(
    symbol: String,
    tint: Color,
    @ViewBuilder label: () -> Label
  ) -> some View {
    HStack(spacing: 5) {
      Image(systemName: symbol)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(tint)
      label()
    }
    .fixedSize()
  }
}

#Preview("Category tile") {
  ZStack {
    AtmosphereBackground()
    ScrollView {
      VStack(spacing: 12) {
        ForEach(CompassionLibrary.categories) { category in
          CategoryTile(category: category)
        }
      }
      .padding(.edge)
    }
  }
  .environment(\.openCategory, { _ in })
}
