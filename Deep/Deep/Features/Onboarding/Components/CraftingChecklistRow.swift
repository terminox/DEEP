import SwiftUI

/// One line in the "crafting your space" loader. Ticks from a hollow ring to a
/// filled lavender check as each step completes, blooming in gently. Mirrors the
/// Calm reference's "We're crafting your sleep plan" checklist, re-voiced.
struct CraftingChecklistRow: View {
  private let label: Text
  private let isDone: Bool

  /// For a caller whose title is chosen at runtime. Such a title does not pass
  /// through the String Catalog.
  init(title: String, isDone: Bool) {
    self.label = Text(title)
    self.isDone = isDone
  }

  /// For a literal title, which resolves through the String Catalog against the
  /// view's locale — how the paywall's benefit list reaches Thai.
  init(_ titleKey: LocalizedStringKey, isDone: Bool) {
    self.label = Text(titleKey)
    self.isDone = isDone
  }

  var body: some View {
    HStack(spacing: 14) {
      ZStack {
        if isDone {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 22))
            .foregroundStyle(.lavenderMist)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else {
          Circle()
            .strokeBorder(Color.driftGrey.opacity(0.4), lineWidth: 1.5)
            .frame(width: 22, height: 22)
        }
      }

      label
        .font(DeepType.body)
        .foregroundStyle(isDone ? .deepPlum : .driftGrey)

      Spacer(minLength: 0)
    }
    .animation(.bloom, value: isDone)
    .accessibilityElement(children: .combine)
    .accessibilityValue(isDone ? "done" : "in progress")
  }
}

#Preview("Crafting checklist row") {
  ZStack {
    AtmosphereBackground()
    VStack(alignment: .leading, spacing: .rhythm) {
      CraftingChecklistRow(title: "Gathering a little calm", isDone: true)
      CraftingChecklistRow(title: "Listening to what you shared", isDone: true)
      CraftingChecklistRow(title: "Shaping your space", isDone: false)
    }
    .padding(.horizontal, .edge)
  }
}
