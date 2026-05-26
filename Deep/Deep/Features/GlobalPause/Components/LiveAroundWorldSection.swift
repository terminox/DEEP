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
        }
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(DeepColor.deepPlum)
                Spacer(minLength: 0)
                if let trailing {
                    Button {
                        // Reserved for future navigation.
                    } label: {
                        HStack(spacing: 2) {
                            Text(trailing)
                                .font(.system(size: 12))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(DeepColor.lavenderMist)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("See all \(title.lowercased())")
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
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
