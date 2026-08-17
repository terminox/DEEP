import Foundation

/// Static sample catalogue for the Compassion portfolio — five causes, their
/// partners and projects, plus a "from the field" feed. Mirrors `SoundLibrary`:
/// hand-authored mock data until a backend exists.
enum CompassionLibrary {
  /// Order is load-bearing: `CommunityPoolCard`'s ring lays its arcs out in this
  /// order and its legend repeats it, as does the causes carousel.
  ///
  /// So are the palettes. Each cause wears one of the five single-hue pairings
  /// (`veil`, `petal`, `iris`, `shore`, `hearth`) — one cause, one colour, on its
  /// arc, its legend chip, its tile banner and its card tint. They're assigned so
  /// that neighbours *on the ring* sit far apart on the wheel, wrap included:
  /// lilac → pink → violet → blue → peach → back to lilac. The two violets
  /// (`veil`, `iris`) are deliberately never adjacent.
  static let categories: [CompassionCategory] = [
    peace, healthcare, education, nature, community,
  ]

  static let peace = CompassionCategory(
    id: "peace",
    name: "Peace & Well-being",
    tagline: "Calmer minds, a kinder world",
    symbol: "bird.fill",
    palette: .veil,
    allocation: 0.20,
    peopleReached: 124_580,
    partner: CompassionPartner(
      name: "V-Peace Foundation",
      blurb: "Volunteers nurturing compassion and global understanding through mindful practice.",
      scope: "Global",
      since: 2008,
      website: "v-peace.org",
      symbol: "hands.and.sparkles.fill"
    ),
    projects: [
      CompassionProject(id: "peace-light", title: "Light of Peace", blurb: "Candlelit gatherings carrying a shared intention for calm.", palette: .aurora, symbol: "flame.fill", peopleReached: 7_820, progress: 0.62, heartsShared: 5_240),
      CompassionProject(id: "peace-meditation", title: "Global Meditation Day", blurb: "A worldwide pause held together, once each season.", palette: .mist, symbol: "moon.stars.fill", peopleReached: 12_140, progress: 0.78, heartsShared: 8_960),
      CompassionProject(id: "peace-circle", title: "Peace Circle", blurb: "Small local circles learning to listen and reconcile.", palette: .dusk, symbol: "circle.hexagongrid.fill", peopleReached: 3_410, progress: 0.41, heartsShared: 2_180),
    ],
    heartsShared: 18_520
  )

  static let healthcare = CompassionCategory(
    id: "healthcare",
    name: "Healthcare",
    tagline: "Caring for health and well-being",
    symbol: "cross.fill",
    palette: .petal,
    allocation: 0.24,
    peopleReached: 96_240,
    partner: CompassionPartner(
      name: "Ramathibodi Foundation",
      blurb: "Supporting healthcare access and medical care for those who need it most.",
      scope: "Thailand",
      since: 1969,
      website: "ramafoundation.or.th",
      symbol: "stethoscope"
    ),
    projects: [
      CompassionProject(id: "health-clinic", title: "Mobile Clinic", blurb: "Bringing healthcare to remote communities by road.", palette: .bloom, symbol: "bus.fill", peopleReached: 9_370, progress: 0.71, heartsShared: 6_410),
      CompassionProject(id: "health-surgery", title: "Children's Heart Surgery", blurb: "Funding life-changing treatment for children.", palette: .dusk, symbol: "heart.text.square.fill", peopleReached: 1_240, progress: 0.55, heartsShared: 4_980),
      CompassionProject(id: "health-mental", title: "Mental Health Care", blurb: "Access to counselling and mental wellness.", palette: .mist, symbol: "brain.head.profile", peopleReached: 5_120, progress: 0.48, heartsShared: 3_220),
    ],
    heartsShared: 16_240
  )

  static let education = CompassionCategory(
    id: "education",
    name: "Education",
    tagline: "Empowering minds, building tomorrow",
    symbol: "book.fill",
    palette: .iris,
    allocation: 0.18,
    peopleReached: 124_580,
    partner: CompassionPartner(
      name: "One Buddhist",
      blurb: "Inspiring wisdom, mindfulness and compassionate learning for every child.",
      scope: "Global",
      since: 2014,
      website: "onebuddhist.org",
      symbol: "graduationcap.fill"
    ),
    projects: [
      CompassionProject(id: "edu-art", title: "Mindful Art for Kids", blurb: "Cultivating creativity, calm and focus through art.", palette: .ember, symbol: "paintbrush.fill", peopleReached: 6_240, progress: 0.66, heartsShared: 4_510),
      CompassionProject(id: "edu-learning", title: "Learning for Life", blurb: "Books and resources for children in need.", palette: .bloom, symbol: "books.vertical.fill", peopleReached: 8_900, progress: 0.73, heartsShared: 5_870),
      CompassionProject(id: "edu-scholarship", title: "Scholarship Program", blurb: "Supporting bright students to reach their dreams.", palette: .aurora, symbol: "rosette", peopleReached: 1_210, progress: 0.52, heartsShared: 3_040),
    ],
    heartsShared: 14_180
  )

  static let nature = CompassionCategory(
    id: "nature",
    name: "Nature",
    tagline: "Protecting nature for future generations",
    symbol: "leaf.fill",
    palette: .shore,
    allocation: 0.22,
    peopleReached: 124_580,
    partner: CompassionPartner(
      name: "Seub Nakhasathien Foundation",
      blurb: "Conserving forests and wildlife so wild places endure for those who follow.",
      scope: "Thailand",
      since: 1990,
      website: "seub.or.th",
      symbol: "tree.fill"
    ),
    projects: [
      CompassionProject(id: "nature-forest", title: "Restore the Forest", blurb: "Replanting native canopy across cleared land.", palette: .mist, symbol: "tree.fill", peopleReached: 7_890, progress: 0.78, heartsShared: 6_120),
      CompassionProject(id: "nature-water", title: "Clean Water Streams", blurb: "Protecting watersheds that villages depend on.", palette: .tide, symbol: "drop.fill", peopleReached: 6_230, progress: 0.75, heartsShared: 5_010),
      CompassionProject(id: "nature-wildlife", title: "Wildlife Refuge", blurb: "Safe habitat for species on the edge.", palette: .aurora, symbol: "pawprint.fill", peopleReached: 5_500, progress: 0.72, heartsShared: 4_320),
    ],
    heartsShared: 12_450
  )

  static let community = CompassionCategory(
    id: "community",
    name: "Community",
    tagline: "Stronger communities, brighter futures",
    symbol: "house.fill",
    palette: .hearth,
    allocation: 0.16,
    peopleReached: 124_580,
    partner: CompassionPartner(
      name: "Together Foundation",
      blurb: "Building resilient neighbourhoods through shared care and local hands.",
      scope: "Thailand",
      since: 2011,
      website: "together.or.th",
      symbol: "person.3.fill"
    ),
    projects: [
      CompassionProject(id: "community-elderly", title: "Care for Elders", blurb: "Companionship and support for those living alone.", palette: .tide, symbol: "figure.2.arms.open", peopleReached: 7_350, progress: 0.78, heartsShared: 5_640),
      CompassionProject(id: "community-meals", title: "Shared Meals", blurb: "Warm food for families through hard seasons.", palette: .ember, symbol: "fork.knife", peopleReached: 6_280, progress: 0.71, heartsShared: 4_710),
      CompassionProject(id: "community-shelter", title: "Safe Shelter", blurb: "A roof and a fresh start for those in crisis.", palette: .dusk, symbol: "house.lodge.fill", peopleReached: 1_640, progress: 0.58, heartsShared: 3_180),
    ],
    heartsShared: 11_980
  )

  /// The "from the field" feed — real-world outcomes reported back to the app.
  static let reports: [FieldReport] = [
    FieldReport(id: "report-clinic", categoryName: "Healthcare", title: "Mobile clinic reached Mae Hong Son", blurb: "320 villagers received check-ups and medicine over three days in the hills.", location: "Mae Hong Son", date: daysAgo(2), symbol: "bus.fill", palette: .bloom),
    FieldReport(id: "report-forest", categoryName: "Nature", title: "12,000 saplings planted", blurb: "Volunteers restored 40 rai of native canopy ahead of the rains.", location: "Chiang Mai", date: daysAgo(6), symbol: "tree.fill", palette: .mist),
    FieldReport(id: "report-scholarship", categoryName: "Education", title: "18 new scholarships awarded", blurb: "Students from rural provinces begin their first university term.", location: "Nationwide", date: daysAgo(11), symbol: "graduationcap.fill", palette: .ember),
    FieldReport(id: "report-meals", categoryName: "Community", title: "5,000 meals shared this month", blurb: "Neighbourhood kitchens kept families fed through the flood season.", location: "Ayutthaya", date: daysAgo(15), symbol: "fork.knife", palette: .tide),
  ]

  private static func daysAgo(_ days: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
  }
}
