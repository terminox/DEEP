#if DEBUG
import SwiftUI
import UIKit

// PROTOTYPE — throwaway. Fixture data for the Growth Passport UI prototype.
// Nothing here is read from a store or the server: today the API exposes no
// dated history (stage reached dates, heart spends, pauses attended), and no
// challenge system exists at all — the challenges below are invented so the
// variants have something to show.

/// How long the sample member has been with DEEP. The switcher flips this so
/// every variant can be judged with a thin journey as well as a full one.
enum PassportJourney: String, CaseIterable, Identifiable {
  case firstWeek
  case sixMonths
  case twoYears

  var id: String { rawValue }

  var label: String {
    switch self {
    case .firstWeek: "First week"
    case .sixMonths: "Six months"
    case .twoYears: "Two years"
    }
  }
}

/// One form of the oak, with the day the member reached it.
struct PassportStage: Identifiable {
  let index: Int
  let name: String
  /// Nil while the form is still ahead.
  let reachedOn: Date?

  var id: Int { index }
  var isReached: Bool { reachedOn != nil }
}

/// A cause the member has sent hearts to.
struct PassportCauseGift: Identifiable {
  let category: CompassionCategory
  let hearts: Int
  let firstGivenOn: Date

  var id: String { category.id }
}

/// A peace message the member wrote after a Global Pause.
struct PassportPeaceMessage: Identifiable {
  let text: String
  let writtenOn: Date

  var id: String { text }
}

/// A challenge or event the member joined. Invented — DEEP has no challenges yet.
struct PassportChallenge: Identifiable {
  let title: String
  let detail: String
  let symbol: String
  let completedOn: Date

  var id: String { title }
}

/// One dated line in the member's story, oldest first.
struct PassportMoment: Identifiable {
  enum Kind {
    case seed, stage, practice, pause, hearts, message, challenge
  }

  let kind: Kind
  let title: String
  let detail: String
  let date: Date
  /// Which oak form was standing on that day — lets a timeline grow the tree
  /// as it scrolls.
  let stageIndex: Int

  var id: String { "\(title)-\(date.timeIntervalSince1970)" }

  var symbol: String {
    switch kind {
    case .seed: "leaf.fill"
    case .stage: "tree.fill"
    case .practice: "wind"
    case .pause: "globe.asia.australia.fill"
    case .hearts: "heart.fill"
    case .message: "envelope.fill"
    case .challenge: "sparkles"
    }
  }
}

/// Everything a Growth Passport could show for one member.
struct PassportSample {
  let journey: PassportJourney
  let memberName: String
  let memberSince: Date
  let issuedOn: Date

  let plantName: String
  /// The plant's character words, e.g. ["Steady", "Strong", "Grounded"].
  let plantTraits: [String]
  let stages: [PassportStage]
  let sunlight: Int
  /// Sunlight needed for the next form; nil once fully grown.
  let nextThreshold: Int?

  let sessions: Int
  let minutes: Int
  let practiceDays: Int
  let pausesAttended: Int

  let gifts: [PassportCauseGift]
  let peaceMessages: [PassportPeaceMessage]
  let challenges: [PassportChallenge]
  let moments: [PassportMoment]

  /// A short reflection written back to the member.
  let note: String
  /// The member's strengths, as a reflection would name them.
  let strengths: [String]
  /// Shown on the printed passport so a reader can check it is genuine.
  let verificationCode: String

  var currentStageIndex: Int { stages.lastIndex(where: \.isReached) ?? 0 }
  var currentStage: PassportStage { stages[currentStageIndex] }
  var isFullyGrown: Bool { nextThreshold == nil }

  /// 0...1 toward the next form; 1 once fully grown.
  var growthProgress: Double {
    guard let nextThreshold else { return 1 }
    let floor = [0, 200, 700][currentStageIndex]
    return Double(sunlight - floor) / Double(nextThreshold - floor)
  }

  var heartsGiven: Int { gifts.reduce(0) { $0 + $1.hearts } }
  var causesSupported: Int { gifts.count }

  /// Shares of hearts per cause, in `CompassionLibrary` order, for a
  /// `CompassionRing`.
  var giftSegments: [RingSegment] {
    guard heartsGiven > 0 else { return [] }
    return gifts.map {
      RingSegment(share: Double($0.hearts) / Double(heartsGiven), colors: $0.category.palette.colors)
    }
  }
}

// MARK: - Stage art

/// The oak's three bundled portraits, copied from the API's seeded media so the
/// prototype runs with no server. They ship on opaque white squares: over a
/// light surface use `.blendMode(.multiply)` and the white disappears.
enum PassportArt {
  static func oak(stage index: Int) -> Image {
    let name = ["passport_oak_seedling", "passport_oak_young", "passport_oak_mature"][min(max(index, 0), 2)]
    return Image(uiImage: UIImage(named: name) ?? UIImage())
  }
}

/// A round stage portrait seated the way the garden seats its own (a soft
/// lilac rim dissolves the white square), optionally ringed by the growth halo.
struct PassportStagePortrait: View {
  let stageIndex: Int
  var diameter: CGFloat = 84
  /// When set, a green growth arc rides around the portrait.
  var progress: Double? = nil

  var body: some View {
    ZStack {
      if let progress {
        Circle()
          .stroke(GardenColor.meadow.opacity(0.55), lineWidth: 3.5)
        Circle()
          .trim(from: 0, to: min(1, max(0, progress)))
          .stroke(
            LinearGradient(colors: [GardenColor.sage, GardenColor.fern], startPoint: .topLeading, endPoint: .bottomTrailing),
            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
      }
      PassportArt.oak(stage: stageIndex)
        .resizable()
        .scaledToFill()
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay {
          Circle().fill(
            RadialGradient(
              colors: [.clear, Color.softLilac.opacity(0.22)],
              center: .center,
              startRadius: diameter * 0.3,
              endRadius: diameter / 2
            )
          )
        }
        .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
    }
    .frame(width: diameter + 17, height: diameter + 17)
  }
}

// MARK: - Fixtures

extension PassportSample {
  static func sample(_ journey: PassportJourney) -> PassportSample {
    switch journey {
    case .firstWeek: .firstWeek
    case .sixMonths: .sixMonths
    case .twoYears: .twoYears
    }
  }

  private static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9)) ?? .now
  }

  private static let oakTraits = ["Steady", "Strong", "Grounded"]
  private static let issued = day(2026, 10, 23)

  static let firstWeek = PassportSample(
    journey: .firstWeek,
    memberName: "Mali Srisuk",
    memberSince: day(2026, 10, 17),
    issuedOn: issued,
    plantName: "Oak",
    plantTraits: oakTraits,
    stages: [
      PassportStage(index: 0, name: "Oak Seedling", reachedOn: day(2026, 10, 17)),
      PassportStage(index: 1, name: "Young Oak", reachedOn: nil),
      PassportStage(index: 2, name: "Mature Oak", reachedOn: nil),
    ],
    sunlight: 14,
    nextThreshold: 200,
    sessions: 5,
    minutes: 38,
    practiceDays: 4,
    pausesAttended: 1,
    gifts: [
      PassportCauseGift(category: CompassionLibrary.peace, hearts: 6, firstGivenOn: day(2026, 10, 20)),
    ],
    peaceMessages: [
      PassportPeaceMessage(text: "May everyone who feels alone tonight feel a little less so.", writtenOn: day(2026, 10, 20)),
    ],
    challenges: [],
    moments: [
      PassportMoment(kind: .seed, title: "You planted your first seed", detail: "An oak, steady and strong. The start of something quiet.", date: day(2026, 10, 17), stageIndex: 0),
      PassportMoment(kind: .practice, title: "Your first DEEP Session", detail: "Three minutes of balancing breath.", date: day(2026, 10, 17), stageIndex: 0),
      PassportMoment(kind: .pause, title: "You paused with the world", detail: "Your first Global Pause, with 2,140 others.", date: day(2026, 10, 20), stageIndex: 0),
      PassportMoment(kind: .hearts, title: "Your first hearts", detail: "Six hearts to Peace & Well-being.", date: day(2026, 10, 20), stageIndex: 0),
    ],
    note: "Every garden starts as something you can barely see. You showed up four times this week. That is how roots begin.",
    strengths: ["Curiosity", "Self-care"],
    verificationCode: "7KQ-2M4"
  )

  static let sixMonths = PassportSample(
    journey: .sixMonths,
    memberName: "Mali Srisuk",
    memberSince: day(2026, 4, 12),
    issuedOn: issued,
    plantName: "Oak",
    plantTraits: oakTraits,
    stages: [
      PassportStage(index: 0, name: "Oak Seedling", reachedOn: day(2026, 4, 12)),
      PassportStage(index: 1, name: "Young Oak", reachedOn: day(2026, 7, 3)),
      PassportStage(index: 2, name: "Mature Oak", reachedOn: nil),
    ],
    sunlight: 412,
    nextThreshold: 700,
    sessions: 96,
    minutes: 812,
    practiceDays: 71,
    pausesAttended: 23,
    gifts: [
      PassportCauseGift(category: CompassionLibrary.peace, hearts: 40, firstGivenOn: day(2026, 4, 15)),
      PassportCauseGift(category: CompassionLibrary.education, hearts: 32, firstGivenOn: day(2026, 6, 2)),
      PassportCauseGift(category: CompassionLibrary.nature, hearts: 18, firstGivenOn: day(2026, 8, 22)),
    ],
    peaceMessages: [
      PassportPeaceMessage(text: "Breathing for my mother tonight. Thank you for breathing with me.", writtenOn: day(2026, 5, 10)),
      PassportPeaceMessage(text: "May the people in Myanmar find a quiet night.", writtenOn: day(2026, 9, 21)),
    ],
    challenges: [
      PassportChallenge(title: "Seven Mornings of Breath", detail: "A DEEP Session before 9am, seven days running.", symbol: "sunrise.fill", completedOn: day(2026, 5, 19)),
      PassportChallenge(title: "International Day of Peace", detail: "Joined the world's pause on 21 September.", symbol: "globe.asia.australia.fill", completedOn: day(2026, 9, 21)),
    ],
    moments: [
      PassportMoment(kind: .seed, title: "You planted your first seed", detail: "An oak, steady and strong.", date: day(2026, 4, 12), stageIndex: 0),
      PassportMoment(kind: .pause, title: "You paused with the world", detail: "Your first Global Pause, with 3,912 others.", date: day(2026, 4, 15), stageIndex: 0),
      PassportMoment(kind: .hearts, title: "Your first hearts", detail: "Sent to Peace & Well-being.", date: day(2026, 4, 15), stageIndex: 0),
      PassportMoment(kind: .message, title: "You wrote to the world", detail: "\u{201C}Breathing for my mother tonight. Thank you for breathing with me.\u{201D}", date: day(2026, 5, 10), stageIndex: 0),
      PassportMoment(kind: .challenge, title: "Seven Mornings of Breath", detail: "Seven mornings in a row, before the day began.", date: day(2026, 5, 19), stageIndex: 0),
      PassportMoment(kind: .hearts, title: "A new cause", detail: "Your hearts reached Education for the first time.", date: day(2026, 6, 2), stageIndex: 0),
      PassportMoment(kind: .stage, title: "Your oak grew into a Young Oak", detail: "200 sunlight, gathered one breath at a time.", date: day(2026, 7, 3), stageIndex: 1),
      PassportMoment(kind: .practice, title: "500 minutes of practice", detail: "More than eight hours given back to yourself.", date: day(2026, 8, 9), stageIndex: 1),
      PassportMoment(kind: .hearts, title: "A new cause", detail: "Your hearts reached Nature for the first time.", date: day(2026, 8, 22), stageIndex: 1),
      PassportMoment(kind: .challenge, title: "International Day of Peace", detail: "You paused with the world on 21 September.", date: day(2026, 9, 21), stageIndex: 1),
    ],
    note: "Six months ago you planted a seed. Since then you have come back to yourself 96 times, and sent kindness to three causes. Your oak is young, and its roots are already strong.",
    strengths: ["Consistency", "Kindness", "Self-care"],
    verificationCode: "4HD-9TX"
  )

  static let twoYears = PassportSample(
    journey: .twoYears,
    memberName: "Mali Srisuk",
    memberSince: day(2024, 11, 2),
    issuedOn: issued,
    plantName: "Oak",
    plantTraits: oakTraits,
    stages: [
      PassportStage(index: 0, name: "Oak Seedling", reachedOn: day(2024, 11, 2)),
      PassportStage(index: 1, name: "Young Oak", reachedOn: day(2025, 2, 14)),
      PassportStage(index: 2, name: "Mature Oak", reachedOn: day(2025, 9, 30)),
    ],
    sunlight: 1286,
    nextThreshold: nil,
    sessions: 412,
    minutes: 3960,
    practiceDays: 318,
    pausesAttended: 141,
    gifts: [
      PassportCauseGift(category: CompassionLibrary.peace, hearts: 168, firstGivenOn: day(2024, 11, 6)),
      PassportCauseGift(category: CompassionLibrary.healthcare, hearts: 74, firstGivenOn: day(2025, 3, 1)),
      PassportCauseGift(category: CompassionLibrary.education, hearts: 131, firstGivenOn: day(2025, 1, 9)),
      PassportCauseGift(category: CompassionLibrary.nature, hearts: 92, firstGivenOn: day(2025, 6, 5)),
      PassportCauseGift(category: CompassionLibrary.community, hearts: 55, firstGivenOn: day(2026, 2, 20)),
    ],
    peaceMessages: [
      PassportPeaceMessage(text: "Breathing for my mother tonight. Thank you for breathing with me.", writtenOn: day(2025, 1, 22)),
      PassportPeaceMessage(text: "To whoever is awake and afraid right now, you are not alone.", writtenOn: day(2026, 3, 8)),
    ],
    challenges: [
      PassportChallenge(title: "Seven Mornings of Breath", detail: "A DEEP Session before 9am, seven days running.", symbol: "sunrise.fill", completedOn: day(2025, 1, 14)),
      PassportChallenge(title: "Earth Hour Pause", detail: "Lights off, breathing with the planet.", symbol: "moon.stars.fill", completedOn: day(2025, 3, 29)),
      PassportChallenge(title: "International Day of Peace", detail: "Joined the world's pause on 21 September.", symbol: "globe.asia.australia.fill", completedOn: day(2025, 9, 21)),
      PassportChallenge(title: "30 Days of Kindness", detail: "A heart sent every day for a month.", symbol: "heart.circle.fill", completedOn: day(2026, 2, 28)),
      PassportChallenge(title: "Exam Season Calm", detail: "Ten DEEP Sessions through exam weeks.", symbol: "graduationcap.fill", completedOn: day(2026, 5, 30)),
    ],
    moments: [
      PassportMoment(kind: .seed, title: "You planted your first seed", detail: "An oak, steady and strong.", date: day(2024, 11, 2), stageIndex: 0),
      PassportMoment(kind: .pause, title: "You paused with the world", detail: "Your first Global Pause, with 1,204 others.", date: day(2024, 11, 6), stageIndex: 0),
      PassportMoment(kind: .hearts, title: "Your first hearts", detail: "Sent to Peace & Well-being.", date: day(2024, 11, 6), stageIndex: 0),
      PassportMoment(kind: .challenge, title: "Seven Mornings of Breath", detail: "Seven mornings in a row, before the day began.", date: day(2025, 1, 14), stageIndex: 0),
      PassportMoment(kind: .message, title: "You wrote to the world", detail: "\u{201C}Breathing for my mother tonight. Thank you for breathing with me.\u{201D}", date: day(2025, 1, 22), stageIndex: 0),
      PassportMoment(kind: .stage, title: "Your oak grew into a Young Oak", detail: "200 sunlight, gathered one breath at a time.", date: day(2025, 2, 14), stageIndex: 1),
      PassportMoment(kind: .challenge, title: "Earth Hour Pause", detail: "Lights off, breathing with the planet.", date: day(2025, 3, 29), stageIndex: 1),
      PassportMoment(kind: .practice, title: "1,000 minutes of practice", detail: "Almost seventeen hours given back to yourself.", date: day(2025, 6, 18), stageIndex: 1),
      PassportMoment(kind: .stage, title: "Your oak reached its full height", detail: "A Mature Oak. Steady, strong, grounded.", date: day(2025, 9, 30), stageIndex: 2),
      PassportMoment(kind: .hearts, title: "Every cause, touched", detail: "Your hearts have now reached all five causes.", date: day(2026, 2, 20), stageIndex: 2),
      PassportMoment(kind: .message, title: "You wrote to the world", detail: "\u{201C}To whoever is awake and afraid right now, you are not alone.\u{201D}", date: day(2026, 3, 8), stageIndex: 2),
      PassportMoment(kind: .practice, title: "100 Global Pauses", detail: "A hundred evenings of breathing with strangers.", date: day(2026, 6, 11), stageIndex: 2),
    ],
    note: "Two years ago you planted a seed. Since then you have come back to yourself 412 times, paused with the world 141 times, and sent 520 hearts to people you will never meet. Strong roots make a steady tree. Steady trees give shade to others.",
    strengths: ["Consistency", "Kindness", "Resilience", "Growth mindset"],
    verificationCode: "2PN-6WB"
  )
}
#endif
