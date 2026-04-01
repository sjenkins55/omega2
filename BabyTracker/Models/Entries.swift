import Foundation
import SwiftData

// MARK: - Feed Entry

@Model
final class FeedEntry {
    @Attribute(.unique) var id: UUID
    var babyID: UUID
    var caregiverID: UUID
    var timestamp: Date
    var notes: String?
    var syncStatus: SyncStatus
    var remoteID: String?
    var createdAt: Date
    var updatedAt: Date

    var feedType: FeedType
    // Breast
    var leftDurationSeconds: Double?
    var rightDurationSeconds: Double?
    var lastSide: BreastSide?
    // Bottle
    var volumeMl: Double?
    var milkType: MilkType?
    var formulaBrand: String?
    // Solids
    var foodName: String?
    var hadReaction: Bool?
    var textureStage: TextureStage?
    // Pump
    var pumpLeftMl: Double?
    var pumpRightMl: Double?
    var pumpStorage: PumpStorage?

    var baby: Baby?

    init(babyID: UUID, caregiverID: UUID, feedType: FeedType, timestamp: Date = Date()) {
        self.id = UUID()
        self.babyID = babyID
        self.caregiverID = caregiverID
        self.timestamp = timestamp
        self.feedType = feedType
        self.syncStatus = .pending
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var totalDurationSeconds: Double {
        (leftDurationSeconds ?? 0) + (rightDurationSeconds ?? 0)
    }
}

enum FeedType: String, Codable, CaseIterable {
    case breast, bottle, solids, pump
}

enum BreastSide: String, Codable {
    case left, right, both
}

enum MilkType: String, Codable, CaseIterable {
    case breast = "Breast Milk"
    case formula = "Formula"
    case mixed = "Mixed"
}

enum TextureStage: String, Codable, CaseIterable {
    case puree = "Puree"
    case mashed = "Mashed"
    case soft = "Soft Pieces"
    case fingerFood = "Finger Food"
    case table = "Table Food"
}

enum PumpStorage: String, Codable, CaseIterable {
    case fridge = "Refrigerator"
    case freezer = "Freezer"
    case used = "Used Immediately"
}

// MARK: - Sleep Entry

@Model
final class SleepEntry {
    @Attribute(.unique) var id: UUID
    var babyID: UUID
    var caregiverID: UUID
    var timestamp: Date        // start time
    var notes: String?
    var syncStatus: SyncStatus
    var remoteID: String?
    var createdAt: Date
    var updatedAt: Date

    var startTime: Date
    var endTime: Date?
    var sleepType: SleepType
    var location: SleepLocation
    var qualityRating: Int?    // 1-5, optional

    var baby: Baby?

    var durationSeconds: Double? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }

    var isOngoing: Bool { endTime == nil }

    init(babyID: UUID, caregiverID: UUID, startTime: Date = Date(), sleepType: SleepType = .nap) {
        self.id = UUID()
        self.babyID = babyID
        self.caregiverID = caregiverID
        self.timestamp = startTime
        self.startTime = startTime
        self.sleepType = sleepType
        self.location = .crib
        self.syncStatus = .pending
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum SleepType: String, Codable, CaseIterable {
    case nap = "Nap"
    case nighttime = "Nighttime"
}

enum SleepLocation: String, Codable, CaseIterable {
    case crib = "Crib"
    case bassinet = "Bassinet"
    case contactNap = "Contact Nap"
    case stroller = "Stroller"
    case carSeat = "Car Seat"
    case bed = "Bed"
    case other = "Other"
}

// MARK: - Diaper Entry

@Model
final class DiaperEntry {
    @Attribute(.unique) var id: UUID
    var babyID: UUID
    var caregiverID: UUID
    var timestamp: Date
    var notes: String?
    var syncStatus: SyncStatus
    var remoteID: String?
    var createdAt: Date
    var updatedAt: Date

    var diaperType: DiaperType
    var stoolColor: StoolColor?
    var stoolConsistency: StoolConsistency?
    var brand: String?

    var baby: Baby?

    init(babyID: UUID, caregiverID: UUID, diaperType: DiaperType, timestamp: Date = Date()) {
        self.id = UUID()
        self.babyID = babyID
        self.caregiverID = caregiverID
        self.timestamp = timestamp
        self.diaperType = diaperType
        self.syncStatus = .pending
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum DiaperType: String, Codable, CaseIterable {
    case wet = "Wet"
    case dirty = "Dirty"
    case both = "Wet + Dirty"
    case dry = "Dry"
}

enum StoolColor: String, Codable, CaseIterable {
    case yellow = "Yellow"
    case mustard = "Mustard"
    case brown = "Brown"
    case green = "Green"
    case orange = "Orange"
    case red = "Red"       // flag — blood
    case black = "Black"   // flag — meconium or blood
    case white = "White"   // flag — bile duct
}

enum StoolConsistency: String, Codable, CaseIterable {
    case watery = "Watery"
    case loose = "Loose"
    case seedy = "Seedy"
    case pasty = "Pasty"
    case formed = "Formed"
    case hard = "Hard"
}

// MARK: - Temperature Entry

@Model
final class TemperatureEntry {
    @Attribute(.unique) var id: UUID
    var babyID: UUID
    var caregiverID: UUID
    var timestamp: Date
    var notes: String?
    var syncStatus: SyncStatus
    var remoteID: String?
    var createdAt: Date
    var updatedAt: Date

    var valueFahrenheit: Double   // always store as F, convert on display
    var method: TempMethod

    var baby: Baby?

    var valueCelsius: Double { (valueFahrenheit - 32) * 5 / 9 }
    var isFever: Bool { valueFahrenheit >= 100.4 }

    init(babyID: UUID, caregiverID: UUID, valueFahrenheit: Double, method: TempMethod, timestamp: Date = Date()) {
        self.id = UUID()
        self.babyID = babyID
        self.caregiverID = caregiverID
        self.timestamp = timestamp
        self.valueFahrenheit = valueFahrenheit
        self.method = method
        self.syncStatus = .pending
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum TempMethod: String, Codable, CaseIterable {
    case rectal = "Rectal"
    case axillary = "Armpit"
    case temporal = "Temporal"
    case ear = "Ear"
    case oral = "Oral"
}
