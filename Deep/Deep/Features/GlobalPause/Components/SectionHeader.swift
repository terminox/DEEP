import SwiftUI

/// A section title with optional subtitle and trailing action — the header
/// style shared by the reflection screen's sections (`IntentionPicker`,
/// the mood check-in).
struct SectionHeader: View {
  // Keys, not `String`s: every caller passes product copy, and a `String`
  // would render verbatim instead of in the reading language.
  let title: LocalizedStringKey
  var subtitle: LocalizedStringKey? = nil
  var trailing: LocalizedStringKey? = nil
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
          .accessibilityLabel(Text("See all \(Text(title))"))
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
  VStack(spacing: 24) {
    SectionHeader(title: "Set your intention", subtitle: "What would you like to pause for?")
    SectionHeader(title: "How are you feeling?")
    SectionHeader(title: "Voices", trailing: "See all")
  }
  .padding(.vertical)
  .background(.moonCream)
}
