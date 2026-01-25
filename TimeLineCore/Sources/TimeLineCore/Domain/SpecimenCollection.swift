import Foundation

/// Represents the quality of a collected specimen (finished task).
public enum CollectionQuality: String, Codable, Equatable {
    /// Perfect focus, no distractions (High resolution image).
    case perfect
    /// Minor distractions but recovered (Good image).
    case good
    /// Significant distractions or interruptions (Blurry/Sketch).
    case flawed
    /// The subject fled or was barely observed (Feather/Footprint only).
    /// Result of frequent/long distractions exceeding grace period.
    case fled
}

/// Represents a single entry in the Field Journal (a completed task).
public struct CollectedSpecimen: Codable, Identifiable, Equatable {
    public let id: UUID
    public let templateId: UUID? // Link to original card template (Species)
    public let title: String
    public let completedAt: Date
    public let duration: TimeInterval
    public let quality: CollectionQuality
    public let notes: String?
    
    public init(
        id: UUID = UUID(),
        templateId: UUID?,
        title: String,
        completedAt: Date,
        duration: TimeInterval,
        quality: CollectionQuality,
        notes: String? = nil
    ) {
        self.id = id
        self.templateId = templateId
        self.title = title
        self.completedAt = completedAt
        self.duration = duration
        self.quality = quality
        self.notes = notes
    }
}

/// The container for all collected specimens.
/// Acts as the player's "Field Journal".
public struct SpecimenCollection: Codable, Equatable {
    public var specimens: [CollectedSpecimen]
    
    public init(specimens: [CollectedSpecimen] = []) {
        self.specimens = specimens
    }
    
    public mutating func add(_ specimen: CollectedSpecimen) {
        specimens.append(specimen)
    }
    
    /// Returns specimens collected on a specific date (ignoring time).
    public func specimens(for date: Date) -> [CollectedSpecimen] {
        let calendar = Calendar.current
        return specimens.filter { calendar.isDate($0.completedAt, inSameDayAs: date) }
    }
}
