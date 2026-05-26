import SwiftUI

/// Centralized type styles aligned with DESIGN.md.
/// All sizes are anchored to a Dynamic Type text style so they scale.
enum DeepType {
    /// Serif italic wordmark — "deep", "Global Pause". H2-ish.
    static let wordmark: Font = .system(.title, design: .serif, weight: .light).italic()

    /// H2 serif light — card titles, affirmations.
    static let displayTitle: Font = .system(.title2, design: .serif, weight: .light)

    /// H3 sans medium — UI section headers.
    static let sectionTitle: Font = .system(.headline, design: .default, weight: .medium)

    /// Body copy.
    static let body: Font = .system(.subheadline, design: .default, weight: .regular)

    /// Caption — metadata, schedule lines.
    static let caption: Font = .system(.footnote, design: .default, weight: .regular)

    /// Micro label — small caps, e.g. HR / MIN / SEC.
    static let micro: Font = .system(.caption2, design: .default, weight: .medium)

    /// Rounded mono digits — countdown, large counts.
    static let counter: Font = .system(.title2, design: .rounded, weight: .medium)

    /// Rounded mono digits at countdown scale.
    static let countdown: Font = .system(.title3, design: .rounded, weight: .medium)

    /// Big participant count.
    static let bigNumber: Font = .system(.title, design: .rounded, weight: .medium)
}
