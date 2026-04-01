import Foundation
import SwiftData

@Model
final class Baby {
    @Attribute(.unique) var id: UUID
    var name: String
    var dateOfBirth: Date
    var dueDate: Date?         // for corrected age (preemie)
    var sex: BabySex
    var bloodType: String?
    @Attribute(.externalStorage) var photoData: Data?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    // Sync
    var syncStatus: SyncStatus
    var remoteID: String?      // Supabase UUID as string

    // Relationships
    @Relationship(deleteRule: .cascade) var feedEntries: [FeedEntry]
    @Relationship(deleteRule: .cascade) var sleepEntries: [SleepEntry]
    @Relationship(deleteRule: .cascade) var diaperEntries: [DiaperEntry]
    @Relationship(deleteRule: .cascade) var measurements: [Measurement]
    @Relationship(deleteRule: .cascade) var milestones: [MilestoneEntry]
    @Relationship(deleteRule: .cascade) var vaccines: [VaccineEntry]
    @Relationship(deleteRule: .cascade) var appointments: [Appointment]
    @Relationship(deleteRule: .cascade) var medications: [Medication]
    @Relationship(deleteRule: .cascade) var illnesses: [Illness]
    @Relationship(deleteRule: .cascade) var temperatureEntries: [TemperatureEntry]

    init(
        id: UUID = UUID(),
        name: String,
        dateOfBirth: Date,
        dueDate: Date? = nil,
        sex: BabySex = .unspecified
    ) {
        self.id = id
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.dueDate = dueDate
        self.sex = sex
        self.isArchived = false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.syncStatus = .pending
        self.feedEntries = []
        self.sleepEntries = []
        self.diaperEntries = []
        self.measurements = []
        self.milestones = []
        self.vaccines = []
        self.appointments = []
        self.medications = []
        self.illnesses = []
        self.temperatureEntries = []
    }

    /// Age in months, using corrected age for premature babies
    var ageInMonths: Int {
        let reference = dueDate ?? dateOfBirth
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: reference, to: Date())
        return max(0, components.month ?? 0)
    }

    var ageInDays: Int {
        let reference = dueDate ?? dateOfBirth
        return Calendar.current.dateComponents([.day], from: reference, to: Date()).day ?? 0
    }
}

enum BabySex: String, Codable, CaseIterable {
    case male, female, unspecified
}
