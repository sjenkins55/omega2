import Foundation

// MARK: - WHO Growth Percentile Data
// Source: WHO Child Growth Standards (public domain)
// Values are weight-for-age (kg) and length-for-age (cm) percentiles
// for boys and girls from 0–24 months at P3, P15, P50, P85, P97.

struct WHOPercentileTable {

    struct AgePoint {
        let ageMonths: Int
        let p3: Double
        let p15: Double
        let p50: Double
        let p85: Double
        let p97: Double
    }

    // Weight-for-age (kg)
    static let weightBoys: [AgePoint] = [
        AgePoint(ageMonths: 0,  p3: 2.5,  p15: 2.9,  p50: 3.3,  p85: 3.9,  p97: 4.4),
        AgePoint(ageMonths: 1,  p3: 3.4,  p15: 3.9,  p50: 4.5,  p85: 5.1,  p97: 5.8),
        AgePoint(ageMonths: 2,  p3: 4.4,  p15: 5.0,  p50: 5.6,  p85: 6.3,  p97: 7.1),
        AgePoint(ageMonths: 3,  p3: 5.1,  p15: 5.7,  p50: 6.4,  p85: 7.2,  p97: 8.0),
        AgePoint(ageMonths: 4,  p3: 5.6,  p15: 6.2,  p50: 7.0,  p85: 7.8,  p97: 8.7),
        AgePoint(ageMonths: 5,  p3: 6.0,  p15: 6.7,  p50: 7.5,  p85: 8.4,  p97: 9.3),
        AgePoint(ageMonths: 6,  p3: 6.4,  p15: 7.1,  p50: 7.9,  p85: 8.8,  p97: 9.8),
        AgePoint(ageMonths: 7,  p3: 6.7,  p15: 7.4,  p50: 8.3,  p85: 9.2,  p97: 10.3),
        AgePoint(ageMonths: 8,  p3: 6.9,  p15: 7.7,  p50: 8.6,  p85: 9.6,  p97: 10.7),
        AgePoint(ageMonths: 9,  p3: 7.1,  p15: 7.9,  p50: 8.9,  p85: 9.9,  p97: 11.0),
        AgePoint(ageMonths: 10, p3: 7.4,  p15: 8.2,  p50: 9.2,  p85: 10.2, p97: 11.4),
        AgePoint(ageMonths: 11, p3: 7.6,  p15: 8.4,  p50: 9.4,  p85: 10.5, p97: 11.7),
        AgePoint(ageMonths: 12, p3: 7.7,  p15: 8.6,  p50: 9.6,  p85: 10.8, p97: 12.0),
        AgePoint(ageMonths: 15, p3: 8.2,  p15: 9.1,  p50: 10.3, p85: 11.5, p97: 12.8),
        AgePoint(ageMonths: 18, p3: 8.7,  p15: 9.7,  p50: 10.9, p85: 12.2, p97: 13.7),
        AgePoint(ageMonths: 21, p3: 9.2,  p15: 10.2, p50: 11.5, p85: 12.9, p97: 14.5),
        AgePoint(ageMonths: 24, p3: 9.7,  p15: 10.8, p50: 12.2, p85: 13.6, p97: 15.3),
    ]

    static let weightGirls: [AgePoint] = [
        AgePoint(ageMonths: 0,  p3: 2.4,  p15: 2.8,  p50: 3.2,  p85: 3.7,  p97: 4.2),
        AgePoint(ageMonths: 1,  p3: 3.2,  p15: 3.6,  p50: 4.2,  p85: 4.8,  p97: 5.5),
        AgePoint(ageMonths: 2,  p3: 3.9,  p15: 4.5,  p50: 5.1,  p85: 5.8,  p97: 6.6),
        AgePoint(ageMonths: 3,  p3: 4.5,  p15: 5.2,  p50: 5.8,  p85: 6.6,  p97: 7.5),
        AgePoint(ageMonths: 4,  p3: 5.0,  p15: 5.7,  p50: 6.4,  p85: 7.3,  p97: 8.2),
        AgePoint(ageMonths: 5,  p3: 5.4,  p15: 6.1,  p50: 6.9,  p85: 7.8,  p97: 8.8),
        AgePoint(ageMonths: 6,  p3: 5.7,  p15: 6.5,  p50: 7.3,  p85: 8.2,  p97: 9.3),
        AgePoint(ageMonths: 7,  p3: 6.0,  p15: 6.8,  p50: 7.6,  p85: 8.6,  p97: 9.8),
        AgePoint(ageMonths: 8,  p3: 6.3,  p15: 7.0,  p50: 7.9,  p85: 9.0,  p97: 10.2),
        AgePoint(ageMonths: 9,  p3: 6.5,  p15: 7.3,  p50: 8.2,  p85: 9.3,  p97: 10.5),
        AgePoint(ageMonths: 10, p3: 6.7,  p15: 7.5,  p50: 8.5,  p85: 9.6,  p97: 10.9),
        AgePoint(ageMonths: 11, p3: 6.9,  p15: 7.7,  p50: 8.7,  p85: 9.9,  p97: 11.2),
        AgePoint(ageMonths: 12, p3: 7.0,  p15: 7.9,  p50: 8.9,  p85: 10.1, p97: 11.5),
        AgePoint(ageMonths: 15, p3: 7.6,  p15: 8.5,  p50: 9.6,  p85: 10.9, p97: 12.4),
        AgePoint(ageMonths: 18, p3: 8.1,  p15: 9.1,  p50: 10.2, p85: 11.6, p97: 13.2),
        AgePoint(ageMonths: 21, p3: 8.6,  p15: 9.7,  p50: 10.9, p85: 12.4, p97: 14.1),
        AgePoint(ageMonths: 24, p3: 9.0,  p15: 10.2, p50: 11.5, p85: 13.1, p97: 14.9),
    ]

    // Length-for-age (cm)
    static let lengthBoys: [AgePoint] = [
        AgePoint(ageMonths: 0,  p3: 46.1, p15: 47.9, p50: 49.9, p85: 51.8, p97: 53.4),
        AgePoint(ageMonths: 1,  p3: 50.8, p15: 52.8, p50: 54.7, p85: 56.7, p97: 58.5),
        AgePoint(ageMonths: 2,  p3: 54.4, p15: 56.4, p50: 58.4, p85: 60.4, p97: 62.2),
        AgePoint(ageMonths: 3,  p3: 57.3, p15: 59.4, p50: 61.4, p85: 63.5, p97: 65.5),
        AgePoint(ageMonths: 4,  p3: 59.7, p15: 61.8, p50: 63.9, p85: 66.0, p97: 68.0),
        AgePoint(ageMonths: 6,  p3: 63.3, p15: 65.5, p50: 67.6, p85: 69.8, p97: 71.9),
        AgePoint(ageMonths: 9,  p3: 68.0, p15: 70.1, p50: 72.3, p85: 74.5, p97: 76.5),
        AgePoint(ageMonths: 12, p3: 71.7, p15: 73.9, p50: 76.1, p85: 78.4, p97: 80.5),
        AgePoint(ageMonths: 15, p3: 75.0, p15: 77.3, p50: 79.8, p85: 82.3, p97: 84.5),
        AgePoint(ageMonths: 18, p3: 78.1, p15: 80.5, p50: 83.2, p85: 85.9, p97: 88.1),
        AgePoint(ageMonths: 21, p3: 80.9, p15: 83.4, p50: 86.2, p85: 89.0, p97: 91.4),
        AgePoint(ageMonths: 24, p3: 83.5, p15: 86.1, p50: 89.1, p85: 92.0, p97: 94.5),
    ]

    static let lengthGirls: [AgePoint] = [
        AgePoint(ageMonths: 0,  p3: 45.6, p15: 47.3, p50: 49.1, p85: 51.0, p97: 52.7),
        AgePoint(ageMonths: 1,  p3: 49.8, p15: 51.7, p50: 53.7, p85: 55.6, p97: 57.4),
        AgePoint(ageMonths: 2,  p3: 53.0, p15: 55.0, p50: 57.1, p85: 59.1, p97: 60.9),
        AgePoint(ageMonths: 3,  p3: 55.6, p15: 57.7, p50: 59.8, p85: 61.9, p97: 63.9),
        AgePoint(ageMonths: 4,  p3: 57.8, p15: 59.9, p50: 62.1, p85: 64.3, p97: 66.2),
        AgePoint(ageMonths: 6,  p3: 61.2, p15: 63.5, p50: 65.7, p85: 68.0, p97: 70.1),
        AgePoint(ageMonths: 9,  p3: 65.6, p15: 67.9, p50: 70.1, p85: 72.4, p97: 74.5),
        AgePoint(ageMonths: 12, p3: 69.2, p15: 71.5, p50: 74.0, p85: 76.5, p97: 78.6),
        AgePoint(ageMonths: 15, p3: 72.8, p15: 75.3, p50: 77.8, p85: 80.4, p97: 82.7),
        AgePoint(ageMonths: 18, p3: 76.0, p15: 78.5, p50: 81.2, p85: 83.9, p97: 86.3),
        AgePoint(ageMonths: 21, p3: 79.0, p15: 81.6, p50: 84.4, p85: 87.3, p97: 89.8),
        AgePoint(ageMonths: 24, p3: 81.7, p15: 84.4, p50: 87.4, p85: 90.4, p97: 93.0),
    ]

    /// Interpolate a percentile value for a given age in months.
    static func interpolate(table: [AgePoint], ageMonths: Double, percentile: KeyPath<AgePoint, Double>) -> Double {
        guard !table.isEmpty else { return 0 }
        if ageMonths <= Double(table.first!.ageMonths) { return table.first![keyPath: percentile] }
        if ageMonths >= Double(table.last!.ageMonths)  { return table.last![keyPath: percentile] }

        for i in 0..<(table.count - 1) {
            let lo = table[i], hi = table[i + 1]
            if ageMonths >= Double(lo.ageMonths) && ageMonths <= Double(hi.ageMonths) {
                let t = (ageMonths - Double(lo.ageMonths)) / Double(hi.ageMonths - lo.ageMonths)
                return lo[keyPath: percentile] + t * (hi[keyPath: percentile] - lo[keyPath: percentile])
            }
        }
        return 0
    }

    /// Compute what percentile a measurement falls at for a given age.
    /// Returns a value 0–100.
    static func computePercentile(value: Double, ageMonths: Double, table: [AgePoint]) -> Double {
        let p3  = interpolate(table: table, ageMonths: ageMonths, percentile: \.p3)
        let p15 = interpolate(table: table, ageMonths: ageMonths, percentile: \.p15)
        let p50 = interpolate(table: table, ageMonths: ageMonths, percentile: \.p50)
        let p85 = interpolate(table: table, ageMonths: ageMonths, percentile: \.p85)
        let p97 = interpolate(table: table, ageMonths: ageMonths, percentile: \.p97)

        let bands: [(Double, Double, Double)] = [
            (0,   p3,  3),
            (p3,  p15, 15),
            (p15, p50, 50),
            (p50, p85, 85),
            (p85, p97, 97),
            (p97, p97 * 2, 99.9),
        ]
        for (lo, hi, pct) in bands {
            if value < hi && value >= lo {
                let prev = pct == 3 ? 0.0 : bands.first(where: { $0.2 < pct })?.2 ?? 0
                let frac = hi > lo ? (value - lo) / (hi - lo) : 0
                return prev + frac * (pct - prev)
            }
        }
        return value < p3 ? 1 : 99.9
    }
}

// MARK: - CDC Milestone Definitions

struct MilestoneDefinition: Identifiable, Hashable {
    let id: String          // unique key, matches MilestoneEntry.milestoneKey
    let title: String
    let detail: String
    let category: MilestoneCategory
    let ageMonthsMin: Int
    let ageMonthsMax: Int

    static let all: [MilestoneDefinition] = [
        // 2 months
        MilestoneDefinition(id: "social_smile",       title: "First social smile",           detail: "Smiles at people",                              category: .social,    ageMonthsMin: 1,  ageMonthsMax: 3),
        MilestoneDefinition(id: "coos",               title: "Makes cooing sounds",          detail: "Makes sounds other than crying",                category: .language,  ageMonthsMin: 1,  ageMonthsMax: 3),
        MilestoneDefinition(id: "tracks_face",        title: "Tracks faces",                 detail: "Follows faces and objects with eyes",           category: .cognitive, ageMonthsMin: 1,  ageMonthsMax: 3),
        MilestoneDefinition(id: "head_up_tummy",      title: "Lifts head on tummy",          detail: "Holds head up during tummy time",               category: .motor,     ageMonthsMin: 1,  ageMonthsMax: 3),

        // 4 months
        MilestoneDefinition(id: "laughs",             title: "Laughs",                       detail: "Laughs out loud",                               category: .social,    ageMonthsMin: 3,  ageMonthsMax: 5),
        MilestoneDefinition(id: "holds_head_steady",  title: "Holds head steady",            detail: "Holds head up without support",                 category: .motor,     ageMonthsMin: 3,  ageMonthsMax: 5),
        MilestoneDefinition(id: "pushes_up_elbows",   title: "Pushes up on elbows",          detail: "Pushes onto elbows/hands on tummy",             category: .motor,     ageMonthsMin: 3,  ageMonthsMax: 5),
        MilestoneDefinition(id: "babbles",            title: "Babbles",                      detail: "Makes sounds like 'oooh' and 'ahhh'",           category: .language,  ageMonthsMin: 3,  ageMonthsMax: 6),
        MilestoneDefinition(id: "reaches_toy",        title: "Reaches for toy",              detail: "Reaches for a toy with one hand",               category: .motor,     ageMonthsMin: 3,  ageMonthsMax: 6),

        // 6 months
        MilestoneDefinition(id: "rolls_over",         title: "Rolls over",                   detail: "Rolls from tummy to back and back to tummy",    category: .motor,     ageMonthsMin: 4,  ageMonthsMax: 7),
        MilestoneDefinition(id: "sits_with_support",  title: "Sits with support",            detail: "Sits with little support",                      category: .motor,     ageMonthsMin: 5,  ageMonthsMax: 7),
        MilestoneDefinition(id: "recognizes_name",    title: "Recognizes own name",          detail: "Responds to own name",                          category: .language,  ageMonthsMin: 5,  ageMonthsMax: 8),
        MilestoneDefinition(id: "solids_ready",       title: "Shows interest in food",       detail: "Shows interest in solid foods",                 category: .cognitive, ageMonthsMin: 4,  ageMonthsMax: 6),

        // 9 months
        MilestoneDefinition(id: "sits_alone",         title: "Sits without support",         detail: "Sits on own without support",                   category: .motor,     ageMonthsMin: 6,  ageMonthsMax: 10),
        MilestoneDefinition(id: "crawls",             title: "Crawls",                       detail: "Gets to sitting position by self; may crawl",   category: .motor,     ageMonthsMin: 7,  ageMonthsMax: 11),
        MilestoneDefinition(id: "stranger_anxiety",   title: "Stranger anxiety",             detail: "Clingy with familiar adults; fearful of strangers", category: .social, ageMonthsMin: 6,  ageMonthsMax: 10),
        MilestoneDefinition(id: "mama_dada",          title: "Says mama/dada",               detail: "Says 'mama' or 'dada' meaningfully",            category: .language,  ageMonthsMin: 7,  ageMonthsMax: 12),
        MilestoneDefinition(id: "pincer_grasp",       title: "Pincer grasp",                 detail: "Picks up small objects with finger and thumb",  category: .motor,     ageMonthsMin: 8,  ageMonthsMax: 12),

        // 12 months
        MilestoneDefinition(id: "first_steps",        title: "First steps",                  detail: "Takes a few steps on own",                      category: .motor,     ageMonthsMin: 9,  ageMonthsMax: 14),
        MilestoneDefinition(id: "first_word",         title: "First word",                   detail: "Says first word besides mama/dada",             category: .language,  ageMonthsMin: 10, ageMonthsMax: 15),
        MilestoneDefinition(id: "waves_bye",          title: "Waves bye-bye",                detail: "Waves goodbye",                                 category: .social,    ageMonthsMin: 9,  ageMonthsMax: 13),
        MilestoneDefinition(id: "object_permanence",  title: "Finds hidden objects",         detail: "Looks for things that are hidden",              category: .cognitive, ageMonthsMin: 8,  ageMonthsMax: 12),

        // 18 months
        MilestoneDefinition(id: "walks_well",         title: "Walks steadily",               detail: "Walks well on own",                             category: .motor,     ageMonthsMin: 12, ageMonthsMax: 18),
        MilestoneDefinition(id: "ten_words",          title: "Says 10+ words",               detail: "Says at least 10 words",                        category: .language,  ageMonthsMin: 15, ageMonthsMax: 20),
        MilestoneDefinition(id: "points_to_show",     title: "Points to show things",        detail: "Points to show you something interesting",      category: .social,    ageMonthsMin: 12, ageMonthsMax: 18),

        // 24 months
        MilestoneDefinition(id: "two_word_phrases",   title: "Two-word phrases",             detail: "Uses two-word phrases (e.g. 'more milk')",      category: .language,  ageMonthsMin: 18, ageMonthsMax: 24),
        MilestoneDefinition(id: "runs",               title: "Runs",                         detail: "Runs with coordination",                        category: .motor,     ageMonthsMin: 18, ageMonthsMax: 24),
        MilestoneDefinition(id: "pretend_play",       title: "Pretend play",                 detail: "Engages in pretend/make-believe play",          category: .cognitive, ageMonthsMin: 18, ageMonthsMax: 24),
    ]

    static func upcoming(for ageMonths: Int) -> [MilestoneDefinition] {
        all.filter { $0.ageMonthsMin >= ageMonths && $0.ageMonthsMin <= ageMonths + 3 }
    }
}

enum MilestoneCategory: String, Codable, CaseIterable {
    case motor = "Motor"
    case language = "Language"
    case social = "Social"
    case cognitive = "Cognitive"

    var color: String { // SwiftUI Color name for use in views
        switch self {
        case .motor:    return "green"
        case .language: return "blue"
        case .social:   return "pink"
        case .cognitive: return "orange"
        }
    }

    var icon: String {
        switch self {
        case .motor:    return "figure.walk"
        case .language: return "text.bubble.fill"
        case .social:   return "heart.fill"
        case .cognitive: return "brain.head.profile"
        }
    }
}

// MARK: - CDC/ACIP Vaccine Schedule

struct VaccineDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let abbreviation: String
    let recommendedAgeMonths: [Int]  // each entry = one dose
    let description: String

    /// All recommended childhood vaccines per CDC ACIP 2024 schedule
    static let all: [VaccineDefinition] = [
        VaccineDefinition(id: "hepb",   name: "Hepatitis B",              abbreviation: "HepB",    recommendedAgeMonths: [0, 1, 6],                description: "Protects against hepatitis B virus"),
        VaccineDefinition(id: "rotav",  name: "Rotavirus",                abbreviation: "RV",      recommendedAgeMonths: [2, 4, 6],                description: "Protects against rotavirus diarrhea"),
        VaccineDefinition(id: "dtap",   name: "Diphtheria, Tetanus, Pertussis", abbreviation: "DTaP", recommendedAgeMonths: [2, 4, 6, 15, 48],   description: "Protects against diphtheria, tetanus, whooping cough"),
        VaccineDefinition(id: "hib",    name: "Haemophilus influenzae type b", abbreviation: "Hib", recommendedAgeMonths: [2, 4, 6, 12],          description: "Protects against bacterial meningitis"),
        VaccineDefinition(id: "pcv",    name: "Pneumococcal conjugate",   abbreviation: "PCV15/20", recommendedAgeMonths: [2, 4, 6, 12],          description: "Protects against pneumococcal disease"),
        VaccineDefinition(id: "ipv",    name: "Inactivated Poliovirus",   abbreviation: "IPV",     recommendedAgeMonths: [2, 4, 6, 48],            description: "Protects against polio"),
        VaccineDefinition(id: "covid",  name: "COVID-19",                  abbreviation: "COVID-19", recommendedAgeMonths: [6],                   description: "Protects against COVID-19"),
        VaccineDefinition(id: "flu",    name: "Influenza (Flu)",           abbreviation: "IIV",     recommendedAgeMonths: [6, 18, 30, 42, 54],    description: "Annual flu vaccine"),
        VaccineDefinition(id: "mmr",    name: "Measles, Mumps, Rubella",  abbreviation: "MMR",     recommendedAgeMonths: [12, 48],                 description: "Protects against measles, mumps, rubella"),
        VaccineDefinition(id: "var",    name: "Varicella (Chickenpox)",   abbreviation: "VAR",     recommendedAgeMonths: [12, 48],                 description: "Protects against chickenpox"),
        VaccineDefinition(id: "hepa",   name: "Hepatitis A",              abbreviation: "HepA",    recommendedAgeMonths: [12, 18],                 description: "Protects against hepatitis A virus"),
    ]

    /// Group doses by recommended age band for display
    static var byAgeBand: [(label: String, months: Int, vaccines: [(vaccine: VaccineDefinition, doseNumber: Int)])] {
        let bands: [(String, Int)] = [
            ("At Birth", 0), ("1–2 Months", 1), ("2 Months", 2), ("4 Months", 4),
            ("6 Months", 6), ("9 Months", 9), ("12 Months", 12), ("15 Months", 15),
            ("18 Months", 18), ("24 Months", 24), ("4–6 Years", 48),
        ]
        return bands.compactMap { (label, months) in
            let doses = all.compactMap { vaccine -> (VaccineDefinition, Int)? in
                guard let idx = vaccine.recommendedAgeMonths.firstIndex(of: months) else { return nil }
                return (vaccine, idx + 1)
            }
            return doses.isEmpty ? nil : (label, months, doses)
        }
    }
}
