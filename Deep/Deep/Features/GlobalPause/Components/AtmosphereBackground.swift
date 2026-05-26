import SwiftUI

struct AtmosphereBackground: View {
    @State private var drift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DeepColor.moonCream,
                    DeepColor.softLilac.opacity(0.55),
                    DeepColor.blushPowder.opacity(0.45),
                    DeepColor.peachCloud.opacity(0.30)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Soft world map dot pattern — abstract, not literal.
            WorldDotsLayer()
                .opacity(0.12)
                .allowsHitTesting(false)

            // Ambient floating orbs.
            orb(color: DeepColor.lavenderMist, size: 220)
                .offset(x: drift ? -90 : -120, y: drift ? -260 : -240)
                .blur(radius: 60)

            orb(color: DeepColor.blushPowder, size: 180)
                .offset(x: drift ? 130 : 110, y: drift ? -180 : -210)
                .blur(radius: 70)

            orb(color: DeepColor.skyWash, size: 160)
                .offset(x: drift ? -120 : -100, y: drift ? 320 : 300)
                .blur(radius: 60)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                drift.toggle()
            }
        }
    }

    private func orb(color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(0.55))
            .frame(width: size, height: size)
    }
}

private struct WorldDotsLayer: View {
    var body: some View {
        Canvas { context, size in
            let cols = 36
            let rows = 22
            let stepX = size.width / CGFloat(cols)
            let stepY = size.height / CGFloat(rows)
            for r in 0..<rows {
                for c in 0..<cols {
                    let x = CGFloat(c) * stepX + stepX / 2
                    let y = CGFloat(r) * stepY + stepY / 2
                    let nx = (CGFloat(c) / CGFloat(cols) - 0.5) * 2
                    let ny = (CGFloat(r) / CGFloat(rows) - 0.5) * 2
                    // Approximate continents with a soft radial mask.
                    let mask = max(0, 1 - sqrt(nx * nx * 1.1 + ny * ny * 1.6))
                    guard mask > 0.42 else { continue }
                    let dot = Path(ellipseIn: CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4))
                    context.fill(dot, with: .color(DeepColor.deepPlum.opacity(0.7)))
                }
            }
        }
    }
}

#Preview {
    AtmosphereBackground()
}
