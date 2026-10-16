#if DEBUG
import SwiftUI

// PROTOTYPE, throwaway. The floating bar that picks which thank-you variant
// the next donation plays, and says which one is live.

struct HeartThanksSwitcherPrototype: View {
  @Environment(\.heartThanksPrototype) private var prototype
  @State private var open = true

  var body: some View {
    if let prototype {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          Text("PROTOTYPE")
            .font(DeepType.micro)
            .foregroundStyle(.driftGrey)
          Text(prototype.variant.title)
            .font(DeepType.caption.weight(.semibold))
            .foregroundStyle(.deepPlum)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
          Button {
            withAnimation(.exhale) { open.toggle() }
          } label: {
            Image(systemName: open ? "chevron.down" : "chevron.up")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.driftGrey)
              .frame(width: 28, height: 28)
          }
        }

        if open {
          Text(prototype.variant.blurb)
            .font(DeepType.caption)
            .foregroundStyle(prototype.variant.breaksDesignRules ? Color.duskRose : Color.driftGrey)
            .fixedSize(horizontal: false, vertical: true)

          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
              ForEach(HeartThanksVariant.allCases) { variant in
                pill(variant, selected: prototype.variant == variant) {
                  withAnimation(.exhale) { prototype.variant = variant }
                }
              }
            }
          }
        }
      }
      .padding(12)
      .frostedCard(cornerRadius: .tile)
      .padding(.horizontal, 12)
      .padding(.bottom, 8)
      .sensoryFeedback(.selection, trigger: prototype.variant)
    }
  }

  private func pill(_ variant: HeartThanksVariant, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(variant.pill)
        .font(DeepType.caption.weight(.semibold))
        .foregroundStyle(selected ? Color.white : Color.deepPlum)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
          Capsule().fill(
            selected
              ? AnyShapeStyle(LinearGradient(colors: [.lavenderMist, .blushPowder], startPoint: .leading, endPoint: .trailing))
              : AnyShapeStyle(Color.white.opacity(0.5))
          )
        }
    }
    .buttonStyle(.softPress)
  }
}

#Preview("Thanks switcher") {
  ZStack(alignment: .bottom) {
    AtmosphereBackground()
    HeartThanksSwitcherPrototype()
  }
  .environment(\.heartThanksPrototype, HeartThanksPrototype())
}
#endif
