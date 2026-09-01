import SwiftUI

/// A settings line whose accessory is a switch.
///
/// A sibling of `SettingsRow` rather than another `Accessory` case: a toggle
/// owns the row's whole hit area, so it can't sit inside a row that is itself
/// a button. Everything visual is borrowed from `SettingsRow` so the two stack
/// inside one card without a seam.
struct SettingsToggleRow: View {
  var icon: String? = nil
  let title: String
  @Binding var isOn: Bool

  var body: some View {
    HStack(spacing: 14) {
      if let icon {
        Image(systemName: icon)
          .font(DeepType.body)
          .foregroundStyle(Color.deepPlum.opacity(0.7))
          .frame(width: 24, height: 24)
      }
      Toggle(isOn: $isOn) {
        Text(title)
          .font(DeepType.body)
          .foregroundStyle(.deepPlum)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .tint(.lavenderMist)
    }
    .padding(.vertical, 16)
    .padding(.horizontal, 18)
  }
}

/// A settings line whose accessory is a time of day.
///
/// `.hourAndMinute` only — the day is meaningless for a daily reminder, and
/// showing a date field would invite someone to set one.
struct SettingsTimeRow: View {
  var icon: String? = nil
  let title: String
  @Binding var date: Date

  var body: some View {
    HStack(spacing: 14) {
      if let icon {
        Image(systemName: icon)
          .font(DeepType.body)
          .foregroundStyle(Color.deepPlum.opacity(0.7))
          .frame(width: 24, height: 24)
      }
      DatePicker(selection: $date, displayedComponents: .hourAndMinute) {
        Text(title)
          .font(DeepType.body)
          .foregroundStyle(.deepPlum)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .tint(.deepPlum)
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 18)
  }
}

#if DEBUG
private struct SettingsControlRowsPreview: View {
  @State private var isOn = true
  @State private var date = Date()

  var body: some View {
    ZStack {
      AtmosphereBackground()
      SettingsSection(title: "Reminders") {
        SettingsToggleRow(icon: "bell", title: "Daily reminder", isOn: $isOn)
        SettingsTimeRow(icon: "clock", title: "Time", date: $date)
      }
      .padding(.horizontal, .edge)
    }
  }
}

#Preview("Settings control rows") {
  SettingsControlRowsPreview()
}
#endif
