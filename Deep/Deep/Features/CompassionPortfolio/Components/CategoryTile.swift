import SwiftUI

/// A single cause in the portfolio's "where your hearts go" list. Tapping it
/// routes to the cause detail through the coordinator's injected `openCategory`
/// action — never a `NavigationLink`.
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

        VStack(alignment: .leading, spacing: 3) {
          Text(category.name)
            .font(DeepType.sectionTitle)
            .foregroundStyle(.deepPlum)
          Text(category.tagline)
            .font(DeepType.caption)
            .foregroundStyle(.driftGrey)
            .lineLimit(1)
          HStack(spacing: 6) {
            Image(systemName: "heart.fill")
              .font(.system(size: 10, weight: .semibold))
              .foregroundStyle(.blushPowder)
            Text("\(category.heartsShared.formatted(.number.notation(.compactName))) shared")
              .contentTransition(.numericText(value: Double(category.heartsShared)))
            Text("·")
            Text("\(Int((category.allocation * 100).rounded()))% of giving")
          }
          .font(DeepType.caption.weight(.medium))
          .foregroundStyle(.driftGrey)
          .lineLimit(1)
        }

        Spacer(minLength: 8)

        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.lavenderMist)
      }
      .padding(14)
      .frostedCard()
    }
    .buttonStyle(.softPress)
    .accessibilityElement(children: .combine)
    .accessibilityHint("Opens \(category.name)")
  }
}

#Preview("Category tile") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: 14) {
      CategoryTile(category: CompassionLibrary.peace)
      CategoryTile(category: CompassionLibrary.nature)
    }
    .padding(.edge)
  }
  .environment(\.openCategory, { _ in })
}
