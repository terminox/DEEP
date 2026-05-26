import Foundation

struct VoiceOfPeace: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let country: String
    let quote: String
    let avatarTint: AvatarTint

    enum AvatarTint: Hashable {
        case lavender, blush, sky, peach
    }

    static let samples: [VoiceOfPeace] = [
        VoiceOfPeace(
            name: "Lina",
            country: "Thailand",
            quote: "Paused for my dad and sent love to the world.",
            avatarTint: .blush
        ),
        VoiceOfPeace(
            name: "Emma",
            country: "Australia",
            quote: "Pausing together reminds me we are never alone.",
            avatarTint: .lavender
        ),
        VoiceOfPeace(
            name: "Akio",
            country: "Japan",
            quote: "Ten quiet minutes — a small home inside the day.",
            avatarTint: .sky
        )
    ]
}
