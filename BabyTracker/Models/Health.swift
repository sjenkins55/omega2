import Foundation
import SwiftData

// MARK: - Measurement (Growth)

@Model
final class Measurement {
    @Attribute(.unique) var id: UUID
    var babyID: UUID
    var caregiverID: UUID
    var timestamp: Date
    var notes: String?
    var syncStatus: SyncStatus
    var remoteID: String?
    var createdAt: Date
    var updatedAt: Date

    var type: MeasurementType
    var value: Double
    var unit: MeasurementUnit

    var baby: Baby?

    init(babyID: UUID, caregiverID: UUID, type: MeasurementType, value: Double, unit: MeasurementUnit) {
        self.id = UUID()
        self.babyID = babyID
        self.caregiverID = caregiverID
        self.timestamp = Date()
        self.type = type
        self.value = value
        self.unit = unit
        self.syncStatus = .pending
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum MeasurementType: String, Codable, CaseIterable {
    case weight = "Weight"
    case height = "Height/Length"
    case headCircumference = "Head Circumference"
}

enum MeasurementUnit: String, Codable {
    case kg, lbs, cm, inches
}

// MARK: - Milestone

@Model
final class MilestoneEntry {
    @Attribute(.unique) var id: UUID
    var babyID: UUID
    var caregiverID: UUID
    var timestamp: Date
    var notes: String?
    var syncStatus: SyncStatus
    var remoteID: String?
    var createdAt: Date
    var updatedAt: Date

    var milestoneKey: String?   // maps to MilestoneDefinition.key for curated milestones
    var customTitle: String?
    var achievedAt: Date
    @Attribute(.externalStorage) var photoData: Data?

    var baby: Baby?

    var displayTitle: String { customTitle ?? milestoneKey ?? "Milestone" }

    init(babyID: UUID, caregiverID: UUID, achievedAt: Date = Date(), milestoneKey: String? = nil, customTitle: String? = nil) {
        self.id = UUID()
        self.babyID = babyID
        self.caregiverID = caregiverID
        self.timestamp = achievedAt
        self.achievedAt = achievedAt
        self.milestoneKey = milestoneKey
        self.customTitle = customTitle
        self.syncStatus = .pending
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Vaccine

@Model
final class VaccineEntry {
    @Attribute(.unique) var id: UUID
    var babyID: UUID
    var caregiverID: UUID
    var timestamp: Date
    var notes: String?
    var syncStatus: SyncStatus
    var remoteID: String?
    var createdAt: Date
    var updatedAt: Date

    var vaccineKey: String?     // maps to bundled VaccineDefinition
    var customName: String?
    var administeredAt: Date
    var lotNumber: String?
    var provider: String?
    var reactions: String?

    var baby: Baby?

    var displayName: String { customName ?? vaccineKey ?? "Vaccine" }

    init(babyID: UUID, caregiverID: UUID, administeredAt: Date = Date(), vaccineKey: String? = nil) {
        self.id = UUID()
        self.babyID = babyID
        self.caregiverID = caregiverID
        self.timestamp = administeredAt
        self.administeredAt = administeredAt
        self.vaccineKey = vaccineKey
        self.syncStatus = .pending
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Appointment

@Model
final class Appointment {
    @Attribute(.unique) var id: UUID
    var babyID: UUID
    var caregiverID: UUID
    var timestamp: Date
    var notes: String?
    var syncStatus: SyncStatus
    var remoteID: String?
    var createdAt: Date
    var updatedAt: Date

    var scheduledAt: Date
    var provider: String?
    var appointmentType: AppointmentType
    var nextAppointmentDate: Date?

    var baby: Baby?

    init(babyID: UUID, caregiverID: UUID, scheduledAt: Date, type: AppointmentType = .wellVisit) {
        self.id = UUID()
        self.babyID = babyID
        self.caregiverID = caregiverID
        self.timestamp = scheduledAt
        self.scheduledAt = scheduledAt
        self.appointmentType = type
        self.syncStatus = .pending
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum AppointmentType: String, Codable, CaseIterable {
    case wellVisit = "Well Visit"
    case sick = "Sick Visit"
    case specialist = "Specialist"
    case other = "Other"
}

// MARK: - Medication

@Model
final class Medication {
    @Attribute(.unique) var id: UUID
    var babyID: UUID
    var createdByID: UUID
    var syncStatus: SyncStatus
    var remoteID: String?
    var createdAt: Date
    var updatedAt: Date

    var name: String
    var dose: Double
    var doseUnit: DoseUnit
    var route: MedRoute
    var isScheduled: Bool
    var frequencyHours: Double?  // nil if as-needed
    var startDate: Date
    var endDate: Date?
    var isActive: Bool
    var prescribedBy: String?
    var notes: String?

    @Relationship(deleteRule: .cascade) var doses: [MedicationDose]
    var baby: Baby?

    init(babyID: UUID, createdByID: UUID, name: String, dose: Double, unit: DoseUnit, route: MedRoute) {
        self.id = UUID()
        self.babyID = babyID
        self.createdByID = createdByID
        self.name = name
        self.dose = dose
        self.doseUnit = unit
        self.route = route
        self.isScheduled = false
        self.startDate = Date()
        self.isActive = true
        self.syncStatus = .pending
        self.createdAt = Date()
        self.updatedAt = Date()
        self.doses = []
    }
}

@Model
final class MedicationDose {
    @Attribute(.unique) var id: UUID
    var medicationID: UUID
    var caregiverID: UUID
    var administeredAt: Date
    var skipped: Bool
    var notes: String?
    var syncStatus: SyncStatus
    var remoteID: String?
    var createdAt: Date

    var medication: Medication?

    init(medicationID: UUID, caregiverID: UUID, administeredAt: Date = Date(), skipped: Bool = false) {
        self.id = UUID()
        self.medicationID = medicationID
        self.caregiverID = caregiverID
        self.administeredAt = administeredAt
        self.skipped = skipped
        self.syncStatus = .pending
        self.createdAt = Date()
    }
}

enum DoseUnit: String, Codable, CaseIterable {
    case mg, ml, drops = "drops", puffs = "puffs", tsp = "tsp"
}

enum MedRoute: String, Codable, CaseIterable {
    case oral = "Oral"
    case topical = "Topical"
    case inhaled = "Inhaled"
    case nasal = "Nasal"
    case other = "Other"
}

// MARK: - Illness

@Model
final class Illness {
    @Attribute(.unique) var id: UUID
    var babyID: UUID
    var caregiverID: UUID
    var syncStatus: SyncStatus
    var remoteID: String?
    var createdAt: Date
    var updatedAt: Date

    var onsetDate: Date
    var endDate: Date?
    var symptomsRaw: String    // comma-separated Symptom rawValues for SwiftData compatibility
    var notes: String?

    var baby: Baby?

    var symptoms: [Symptom] {
        get { symptomsRaw.split(separator: ",").compactMap { Symptom(rawValue: String($0)) } }
        set { symptomsRaw = newValue.map(\.rawValue).joined(separator: ",") }
    }

    var isActive: Bool { endDate == nil }

    init(babyID: UUID, caregiverID: UUID, onsetDate: Date = Date()) {
        self.id = UUID()
        self.babyID = babyID
        self.caregiverID = caregiverID
        self.onsetDate = onsetDate
        self.symptomsRaw = ""
        self.syncStatus = .pending
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum Symptom: String, Codable, CaseIterable {
    case fever = "Fever"
    case cough = "Cough"
    case runnyNose = "Runny Nose"
    case congestion = "Congestion"
    case vomiting = "Vomiting"
    case diarrhea = "Diarrhea"
    case rash = "Rash"
    case earPain = "Ear Pain"
    case eyeDischarge = "Eye Discharge"
    case reducedAppetite = "Reduced Appetite"
    case fussiness = "Fussiness"
    case lethargy = "Lethargy"
    case other = "Other"
}
