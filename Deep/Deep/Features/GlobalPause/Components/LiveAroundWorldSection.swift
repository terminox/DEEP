import SwiftUI

struct LiveAroundWorldSection: View {
  let pauses: [CountryPause]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Live now around the world")

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: 12) {
          ForEach(pauses) { pause in
            CountryPauseCard(pause: pause)
              .scrollTransition(.animated(.exhale)) { content, phase in
                content
                  .opacity(phase.isIdentity ? 1 : 0.75)
                  .scaleEffect(phase.isIdentity ? 1 : 0.97)
              }
          }
        }
        .scrollTargetLayout()
        .padding(.horizontal, .edge)
      }
      .scrollTargetBehavior(.viewAligned)
      .contentMargins(.horizontal, 0)
      .scrollClipDisabled()
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
          .foregroundStyle(.deepPlum)
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
            .foregroundStyle(.lavenderMist)
          }
          .buttonStyle(.softPress)
          .accessibilityLabel("See all \(title.lowercased())")
        }
      }
      if let subtitle {
        Text(subtitle)
          .font(DeepType.caption)
          .foregroundStyle(.driftGrey)
      }
    }
    .padding(.horizontal, .edge)
  }
}

#Preview {
  LiveAroundWorldSection(pauses: CountryPause.samples)
    .padding(.vertical)
    .background(.moonCream)
}
