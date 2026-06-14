import SwiftUI

/// The home's "Explore" section — a row of soft category chips drawn from
/// `HomeCategory`, mirroring Calm's "Explore by Content".
struct ExploreByContentSection: View {
  var onSelect: (HomeCategory) -> Void = { _ in }

  private let columns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12)
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HomeSectionHeader(title: "Explore")

      LazyVGrid(columns: columns, spacing: 12) {
        ForEach(HomeCategory.allCases) { category in
          ExploreTile(category: category) { onSelect(category) }
        }
      }
      .padding(.horizontal, .edge)
    }
  }
}

private struct ExploreTile: View {
  let category: HomeCategory
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: category.systemImage)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(category.tint)
          .frame(width: 40, height: 40)
          .background(category.tint.opacity(0.18), in: Circle())

        Text(category.rawValue)
          .font(DeepType.body.weight(.medium))
          .foregroundStyle(.deepPlum)

        Spacer(minLength: 0)
      }
      .padding(12)
      .frostedCard(cornerRadius: 18)
    }
    .buttonStyle(.softPress)
    .accessibilityLabel("Explore \(category.rawValue)")
  }
}

#Preview("Explore by Content") {
  ScrollView {
    ExploreByContentSection()
      .padding(.vertical, 24)
  }
  .background { AtmosphereBackground() }
}
