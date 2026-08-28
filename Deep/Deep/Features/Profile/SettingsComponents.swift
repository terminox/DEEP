import SwiftUI

// MARK: - Section

/// A Calm-style settings group: an optional whisper of a title above a frosted
/// card of rows. The card *is* the grouping — Deep separates content with
/// whitespace and surfaces, never with rules, so there are no hairlines
/// between the rows.
struct SettingsSection<Content: View>: View {
  var title: String? = nil
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let title {
        Text(title)
          .font(DeepType.micro)
          .foregroundStyle(.driftGrey)
          .padding(.horizontal, 8)
      }
      VStack(spacing: 0) {
        content
      }
      .frostedCard(cornerRadius: .card)
    }
  }
}

// MARK: - Row

/// One settings line: SF Symbol in a fixed column, a title, and an optional
/// trailing accessory. With an action it becomes a soft-press button; without
/// one it renders as a static (informational) row.
struct SettingsRow: View {
  enum Accessory: Equatable {
    case none
    case chevron
    case value(String)
    case progress
  }

  let icon: String
  let title: String
  var accessory: Accessory = .none
  var role: ButtonRole? = nil
  /// Overrides the plum icon/title colour — e.g. `.duskRose` for rows whose
  /// action is irreversible.
  var tint: Color? = nil
  var action: (() -> Void)? = nil

  var body: some View {
    if let action {
      Button(role: role, action: action) { label }
        .buttonStyle(.softPress)
    } else {
      label
    }
  }

  private var label: some View {
    HStack(spacing: 14) {
      Image(systemName: icon)
        .font(DeepType.body)
        .foregroundStyle((tint ?? .deepPlum).opacity(0.7))
        .frame(width: 24, height: 24)
      Text(title)
        .font(DeepType.body)
        .foregroundStyle(tint ?? .deepPlum)
        .multilineTextAlignment(.leading)
      Spacer(minLength: 12)
      accessoryView
    }
    .padding(.vertical, 16)
    .padding(.horizontal, 18)
    .contentShape(Rectangle())
  }

  @ViewBuilder
  private var accessoryView: some View {
    switch accessory {
    case .none:
      EmptyView()
    case .chevron:
      Image(systemName: "chevron.right")
        .font(DeepType.micro)
        .foregroundStyle(.driftGrey)
    case .value(let text):
      Text(text)
        .font(DeepType.caption)
        .foregroundStyle(.driftGrey)
    case .progress:
      ProgressView()
        .controlSize(.small)
        .tint(.driftGrey)
    }
  }
}

// MARK: - Previews

#Preview("Settings section") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: .rhythm) {
      SettingsSection(title: "Membership") {
        SettingsRow(icon: "sparkles", title: "DEEP Pro", accessory: .value("Yearly"))
        SettingsRow(icon: "creditcard", title: "Manage subscription", accessory: .chevron) {}
        SettingsRow(icon: "arrow.clockwise", title: "Restore purchases", accessory: .progress) {}
      }
      SettingsSection(title: "Account") {
        SettingsRow(icon: "rectangle.portrait.and.arrow.right", title: "Log out", role: .destructive) {}
        SettingsRow(icon: "trash", title: "Delete account", role: .destructive, tint: .duskRose) {}
      }
    }
    .padding(.horizontal, .edge)
  }
}
