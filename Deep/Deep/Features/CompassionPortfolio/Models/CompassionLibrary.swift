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
  static var categories: [CompassionCategory] {
    [
      peace, healthcare, education, nature, community,
    ]
  }

  static var peace: CompassionCategory {
    CompassionCategory(
      id: "peace",
      name: String(localized: "Peace & Well-being", bundle: .app, locale: .app),
      tagline: String(localized: "Calmer minds, a kinder world", bundle: .app, locale: .app),
      symbol: "bird.fill",
      palette: .aurora,
      peopleReached: 124_580,
      partner: CompassionPartner(
        name: String(localized: "V-Peace Foundation", bundle: .app, locale: .app),
        blurb: String(localized: "Volunteers nurturing compassion and global understanding through mindful practice.", bundle: .app, locale: .app),
        scope: String(localized: "Global", bundle: .app, locale: .app),
        since: 2008,
        website: "v-peace.org",
        symbol: "hands.and.sparkles.fill"
      ),
      projects: [
        CompassionProject(id: "peace-light", title: String(localized: "Light of Peace", bundle: .app, locale: .app), blurb: String(localized: "Candlelit gatherings carrying a shared intention for calm.", bundle: .app, locale: .app), palette: .aurora, symbol: "flame.fill", peopleReached: 7_820, progress: 0.62, heartsShared: 5_240),
        CompassionProject(id: "peace-meditation", title: String(localized: "Global Meditation Day", bundle: .app, locale: .app), blurb: String(localized: "A worldwide pause held together, once each season.", bundle: .app, locale: .app), palette: .mist, symbol: "moon.stars.fill", peopleReached: 12_140, progress: 0.78, heartsShared: 8_960),
        CompassionProject(id: "peace-circle", title: String(localized: "Peace Circle", bundle: .app, locale: .app), blurb: String(localized: "Small local circles learning to listen and reconcile.", bundle: .app, locale: .app), palette: .dusk, symbol: "circle.hexagongrid.fill", peopleReached: 3_410, progress: 0.41, heartsShared: 2_180),
      ],
      heartsShared: 18_520
    )
  }

  static var healthcare: CompassionCategory {
    CompassionCategory(
      id: "healthcare",
      name: String(localized: "Healthcare", bundle: .app, locale: .app),
      tagline: String(localized: "Caring for health and well-being", bundle: .app, locale: .app),
      symbol: "cross.fill",
      palette: .bloom,
      peopleReached: 96_240,
      partner: CompassionPartner(
        name: String(localized: "Ramathibodi Foundation", bundle: .app, locale: .app),
        blurb: String(localized: "Supporting healthcare access and medical care for those who need it most.", bundle: .app, locale: .app),
        scope: String(localized: "Thailand", bundle: .app, locale: .app),
        since: 1969,
        website: "ramafoundation.or.th",
        symbol: "stethoscope"
      ),
      projects: [
        CompassionProject(id: "health-clinic", title: String(localized: "Mobile Clinic", bundle: .app, locale: .app), blurb: String(localized: "Bringing healthcare to remote communities by road.", bundle: .app, locale: .app), palette: .bloom, symbol: "bus.fill", peopleReached: 9_370, progress: 0.71, heartsShared: 6_410),
        CompassionProject(id: "health-surgery", title: String(localized: "Children's Heart Surgery", bundle: .app, locale: .app), blurb: String(localized: "Funding life-changing treatment for children.", bundle: .app, locale: .app), palette: .dusk, symbol: "heart.text.square.fill", peopleReached: 1_240, progress: 0.55, heartsShared: 4_980),
        CompassionProject(id: "health-mental", title: String(localized: "Mental Health Care", bundle: .app, locale: .app), blurb: String(localized: "Access to counselling and mental wellness.", bundle: .app, locale: .app), palette: .mist, symbol: "brain.head.profile", peopleReached: 5_120, progress: 0.48, heartsShared: 3_220),
      ],
      heartsShared: 16_240
    )
  }

  static var education: CompassionCategory {
    CompassionCategory(
      id: "education",
      name: String(localized: "Education", bundle: .app, locale: .app),
      tagline: String(localized: "Empowering minds, building tomorrow", bundle: .app, locale: .app),
      symbol: "book.fill",
      palette: .ember,
      peopleReached: 124_580,
      partner: CompassionPartner(
        name: String(localized: "One Buddhist", bundle: .app, locale: .app),
        blurb: String(localized: "Inspiring wisdom, mindfulness and compassionate learning for every child.", bundle: .app, locale: .app),
        scope: String(localized: "Global", bundle: .app, locale: .app),
        since: 2014,
        website: "onebuddhist.org",
        symbol: "graduationcap.fill"
      ),
      projects: [
        CompassionProject(id: "edu-art", title: String(localized: "Mindful Art for Kids", bundle: .app, locale: .app), blurb: String(localized: "Cultivating creativity, calm and focus through art.", bundle: .app, locale: .app), palette: .ember, symbol: "paintbrush.fill", peopleReached: 6_240, progress: 0.66, heartsShared: 4_510),
        CompassionProject(id: "edu-learning", title: String(localized: "Learning for Life", bundle: .app, locale: .app), blurb: String(localized: "Books and resources for children in need.", bundle: .app, locale: .app), palette: .bloom, symbol: "books.vertical.fill", peopleReached: 8_900, progress: 0.73, heartsShared: 5_870),
        CompassionProject(id: "edu-scholarship", title: String(localized: "Scholarship Program", bundle: .app, locale: .app), blurb: String(localized: "Supporting bright students to reach their dreams.", bundle: .app, locale: .app), palette: .aurora, symbol: "rosette", peopleReached: 1_210, progress: 0.52, heartsShared: 3_040),
      ],
      heartsShared: 14_180
    )
  }

  static var nature: CompassionCategory {
    CompassionCategory(
      id: "nature",
      name: String(localized: "Nature", bundle: .app, locale: .app),
      tagline: String(localized: "Protecting nature for future generations", bundle: .app, locale: .app),
      symbol: "leaf.fill",
      palette: .mist,
      peopleReached: 124_580,
      partner: CompassionPartner(
        name: String(localized: "Seub Nakhasathien Foundation", bundle: .app, locale: .app),
        blurb: String(localized: "Conserving forests and wildlife so wild places endure for those who follow.", bundle: .app, locale: .app),
        scope: String(localized: "Thailand", bundle: .app, locale: .app),
        since: 1990,
        website: "seub.or.th",
        symbol: "tree.fill"
      ),
      projects: [
        CompassionProject(id: "nature-forest", title: String(localized: "Restore the Forest", bundle: .app, locale: .app), blurb: String(localized: "Replanting native canopy across cleared land.", bundle: .app, locale: .app), palette: .mist, symbol: "tree.fill", peopleReached: 7_890, progress: 0.78, heartsShared: 6_120),
        CompassionProject(id: "nature-water", title: String(localized: "Clean Water Streams", bundle: .app, locale: .app), blurb: String(localized: "Protecting watersheds that villages depend on.", bundle: .app, locale: .app), palette: .tide, symbol: "drop.fill", peopleReached: 6_230, progress: 0.75, heartsShared: 5_010),
        CompassionProject(id: "nature-wildlife", title: String(localized: "Wildlife Refuge", bundle: .app, locale: .app), blurb: String(localized: "Safe habitat for species on the edge.", bundle: .app, locale: .app), palette: .aurora, symbol: "pawprint.fill", peopleReached: 5_500, progress: 0.72, heartsShared: 4_320),
      ],
      heartsShared: 12_450
    )
  }

  static var community: CompassionCategory {
    CompassionCategory(
      id: "community",
      name: String(localized: "Community", bundle: .app, locale: .app),
      tagline: String(localized: "Stronger communities, brighter futures", bundle: .app, locale: .app),
      symbol: "house.fill",
      palette: .tide,
      peopleReached: 124_580,
      partner: CompassionPartner(
        name: String(localized: "Together Foundation", bundle: .app, locale: .app),
        blurb: String(localized: "Building resilient neighbourhoods through shared care and local hands.", bundle: .app, locale: .app),
        scope: String(localized: "Thailand", bundle: .app, locale: .app),
        since: 2011,
        website: "together.or.th",
        symbol: "person.3.fill"
      ),
      projects: [
        CompassionProject(id: "community-elderly", title: String(localized: "Care for Elders", bundle: .app, locale: .app), blurb: String(localized: "Companionship and support for those living alone.", bundle: .app, locale: .app), palette: .tide, symbol: "figure.2.arms.open", peopleReached: 7_350, progress: 0.78, heartsShared: 5_640),
        CompassionProject(id: "community-meals", title: String(localized: "Shared Meals", bundle: .app, locale: .app), blurb: String(localized: "Warm food for families through hard seasons.", bundle: .app, locale: .app), palette: .ember, symbol: "fork.knife", peopleReached: 6_280, progress: 0.71, heartsShared: 4_710),
        CompassionProject(id: "community-shelter", title: String(localized: "Safe Shelter", bundle: .app, locale: .app), blurb: String(localized: "A roof and a fresh start for those in crisis.", bundle: .app, locale: .app), palette: .dusk, symbol: "house.lodge.fill", peopleReached: 1_640, progress: 0.58, heartsShared: 3_180),
      ],
      heartsShared: 11_980
    )
  }

  /// The "from the field" feed — real-world outcomes reported back to the app.
  static var reports: [FieldReport] {
    [
      FieldReport(id: "report-clinic", categoryName: String(localized: "Healthcare", bundle: .app, locale: .app), title: String(localized: "Mobile clinic reached Mae Hong Son", bundle: .app, locale: .app), blurb: String(localized: "320 villagers received check-ups and medicine over three days in the hills.", bundle: .app, locale: .app), location: String(localized: "Mae Hong Son", bundle: .app, locale: .app), date: daysAgo(2), symbol: "bus.fill", palette: .bloom),
      FieldReport(id: "report-forest", categoryName: String(localized: "Nature", bundle: .app, locale: .app), title: String(localized: "12,000 saplings planted", bundle: .app, locale: .app), blurb: String(localized: "Volunteers restored 40 rai of native canopy ahead of the rains.", bundle: .app, locale: .app), location: String(localized: "Chiang Mai", bundle: .app, locale: .app), date: daysAgo(6), symbol: "tree.fill", palette: .mist),
      FieldReport(id: "report-scholarship", categoryName: String(localized: "Education", bundle: .app, locale: .app), title: String(localized: "18 new scholarships awarded", bundle: .app, locale: .app), blurb: String(localized: "Students from rural provinces begin their first university term.", bundle: .app, locale: .app), location: String(localized: "Nationwide", bundle: .app, locale: .app), date: daysAgo(11), symbol: "graduationcap.fill", palette: .ember),
      FieldReport(id: "report-meals", categoryName: String(localized: "Community", bundle: .app, locale: .app), title: String(localized: "5,000 meals shared this month", bundle: .app, locale: .app), blurb: String(localized: "Neighbourhood kitchens kept families fed through the flood season.", bundle: .app, locale: .app), location: String(localized: "Ayutthaya", bundle: .app, locale: .app), date: daysAgo(15), symbol: "fork.knife", palette: .tide),
    ]
  }

  private static func daysAgo(_ days: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
  }
}
