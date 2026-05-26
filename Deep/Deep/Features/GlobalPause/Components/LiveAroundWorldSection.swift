import SwiftUI

struct LiveAroundWorldSection: View {
  let pauses: [CountryPause]
  @State private var visibleIndex: Int = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(
        title: "Live now around the world",
        subtitle: "Who around the world is pausing for peace?",
        trailing: "See all"
      )

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: 12) {
          ForEach(Array(pauses.enumerated()), id: \.element.id) { index, pause in
            CountryPauseCard(pause: pause)
              .scrollTransition(.animated(DeepMotion.exhale)) { content, phase in
                content
                  .opacity(phase.isIdentity ? 1 : 0.75)
                  .scaleEffect(phase.isIdentity ? 1 : 0.97)
              }
              .onScrollVisibilityChange { isVisible in
                if isVisible { visibleIndex = index }
              }
          }
        }
        .scrollTargetLayout()
        .padding(.horizontal, DeepSpacing.edge)
      }
      .scrollTargetBehavior(.viewAligned)
      .contentMargins(.horizontal, 0)

      HStack(spacing: 6) {
        ForEach(pauses.indices, id: \.self) { index in
          Capsule()
            .fill(index == visibleIndex ? DeepColor.lavenderMist : DeepColor.driftGrey.opacity(0.25))
            .frame(width: index == visibleIndex ? 14 : 6, height: 6)
            .animation(DeepMotion.exhale, value: visibleIndex)
        }
      }
      .frame(maxWidth: .infinity)
      .accessibilityHidden(true)
    }
  }
}

struct SectionHeader: View {
  let title: String
  var subtitle: String? = nil
  var trailing: String? = nil
  var action: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .firstTextBaseline) {
        Text(title)
          .font(DeepType.sectionTitle)
          .foregroundStyle(DeepColor.deepPlum)
          .accessibilityAddTraits(.isHeader)
        Spacer(minLength: 8)
        if let trailing {
          Button(action: action) {
            HStack(spacing: 2) {
              Text(trailing)
                .font(DeepType.caption)
              Image(systemName: "chevron.right")
                .font(.system(.caption2, design: .default, weight: .medium))
            }
            .foregroundStyle(DeepColor.lavenderMist)
          }
          .buttonStyle(.softPress)
          .accessibilityLabel("See all \(title.lowercased())")
        }
      }
      if let subtitle {
        Text(subtitle)
          .font(DeepType.caption)
          .foregroundStyle(DeepColor.driftGrey)
      }
    }
    .padding(.horizontal, DeepSpacing.edge)
  }
}

#Preview {
  LiveAroundWorldSection(pauses: CountryPause.samples)
    .padding(.vertical)
    .background(DeepColor.moonCream)
}
