import SwiftUI

struct CountryPauseCard: View {
    let pause: CountryPause

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 10)

            CountryImage(url: pause.imageURL, accent: accentColor)
                .frame(height: 92)
                .clipShape(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .frame(width: 168)
        .background(
            RoundedRectangle(cornerRadius: DeepRadius.tile, style: .continuous)
                .fill(.white.opacity(0.7))
                .background(
                    RoundedRectangle(cornerRadius: DeepRadius.tile, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DeepRadius.tile, style: .continuous)
                .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: DeepColor.lavenderMist.opacity(0.16), radius: 14, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(pause.countryName), paused at \(pause.localTime), \(pause.participantCount.formatted()) people"
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(pause.flagEmoji)
                    .font(.system(size: 16))
                Text(pause.countryName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DeepColor.deepPlum)
                Spacer(minLength: 0)
                Text(pause.localTime)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(DeepColor.driftGrey)
            }
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(DeepColor.lavenderMist)
                Text(pause.participantCount.formatted(.number.grouping(.automatic)))
                    .font(.system(size: 11))
                    .foregroundStyle(DeepColor.driftGrey)
            }
        }
    }

    private var accentColor: Color {
        switch pause.countryName {
        case "Thailand": DeepColor.blushPowder
        case "Japan":    DeepColor.softLilac
        case "France":   DeepColor.skyWash
        case "Brazil":   DeepColor.peachCloud
        default:         DeepColor.lavenderMist
        }
    }
}

private struct CountryImage: View {
    let url: URL?
    let accent: Color

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: DeepMotion.bloom)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, accent.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            default:
                placeholder
            }
        }
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [accent.opacity(0.7), DeepColor.softLilac.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.55))
        )
    }
}

#Preview {
    HStack {
        ForEach(CountryPause.samples.prefix(2)) { CountryPauseCard(pause: $0) }
    }
    .padding()
    .background(DeepColor.moonCream)
}
