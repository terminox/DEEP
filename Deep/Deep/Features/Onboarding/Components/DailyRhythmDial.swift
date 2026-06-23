import SwiftUI
import Foundation

/// A decorative, **read-only** clock ring that reflects the chosen pause time —
/// the orbital look of the Calm reference's sleep-schedule dial, without the
/// drag-math. A real `DatePicker` drives the value; this only visualises it: a
/// soft gradient ring with a glowing knob at the time's angle (midnight at top,
/// clockwise through the 24-hour day).
struct DailyRhythmDial: View {
  let hour: Int
  let minute: Int

  private var fractionOfDay: Double {
    (Double(hour) + Double(minute) / 60.0) / 24.0
  }

  /// 0 fraction (midnight) sits at the top; the day runs clockwise.
  private var knobAngle: Angle {
    .degrees(fractionOfDay * 360 - 90)
  }

  var body: some View {
    GeometryReader { geo in
      let side = min(geo.size.width, geo.size.height)
      let radius = side / 2 - 14
      ZStack {
        Circle()
          .strokeBorder(Color.softLilac.opacity(0.35), lineWidth: 10)

        Circle()
          .strokeBorder(
            AngularGradient(
              colors: [.skyWash, .lavenderMist, .blushPowder, .peachCloud, .skyWash],
              center: .center
            ),
            lineWidth: 4
          )
          .opacity(0.8)

        // Glowing knob at the chosen time.
        Circle()
          .fill(.moonCream)
          .frame(width: 26, height: 26)
          .overlay(Circle().strokeBorder(.lavenderMist, lineWidth: 2))
          .shadow(color: Color.lavenderMist.opacity(0.6), radius: 10)
          .offset(
            x: cos(knobAngle.radians) * radius,
            y: sin(knobAngle.radians) * radius
          )

        Image(systemName: hour < 6 || hour >= 18 ? "moon.fill" : "sun.max.fill")
          .font(.system(size: 26))
          .foregroundStyle(.lavenderMist)
      }
      .frame(width: side, height: side)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .aspectRatio(1, contentMode: .fit)
    .animation(.exhale, value: fractionOfDay)
    .accessibilityHidden(true)
  }
}

#Preview("Rhythm dial") {
  ZStack {
    AtmosphereBackground()
    VStack(spacing: 40) {
      DailyRhythmDial(hour: 21, minute: 30)
        .frame(width: 220, height: 220)
      DailyRhythmDial(hour: 8, minute: 0)
        .frame(width: 160, height: 160)
    }
  }
}
