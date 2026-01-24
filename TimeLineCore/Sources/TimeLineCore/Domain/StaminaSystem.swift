import Foundation

/// Manages the "Naturalist" resources: Stamina and Hydration.
/// Replaces the concept of "Fatigue" with "Resource Depletion".
public struct StaminaSystem: Codable, Equatable {
    
    // MARK: - Properties
    
    /// Current hydration level from 0.0 (Empty) to 1.0 (Full).
    /// Represents the player's ability to continue "hiking" (focusing).
    public var hydration: Double
    
    /// Total distance traveled today (in seconds of focus).
    public var totalDistanceTraveled: TimeInterval
    
    /// Number of consecutive focus sessions without a significant rest.
    public var consecutiveSessions: Int
    
    /// Last time the player visited a "Scenic Spot" (Rest).
    public var lastRestTime: Date?
    
    /// Configuration for consumption rates.
    public struct Configuration {
        /// Hydration consumed per minute of focus.
        /// Default: 1.0 / 120 minutes = ~0.0083 per minute (Empty after 2 hours)
        public static let consumptionRatePerMinute: Double = 1.0 / 120.0
        
        /// Threshold below which the player is considered "Thirsty" (needs rest).
        public static let thirstThreshold: Double = 0.2
    }
    
    // MARK: - Init
    
    public init() {
        self.hydration = 1.0 // Start full
        self.totalDistanceTraveled = 0
        self.consecutiveSessions = 0
        self.lastRestTime = nil
    }
    
    // MARK: - Actions
    
    /// Consumes resources based on focus duration.
    /// - Parameter duration: The duration of the completed focus session in seconds.
    public mutating func consume(duration: TimeInterval) {
        let minutes = duration / 60.0
        let consumption = minutes * Configuration.consumptionRatePerMinute
        
        // Reduce hydration, clamping to 0
        self.hydration = max(0, self.hydration - consumption)
        
        // Update travel stats
        self.totalDistanceTraveled += duration
        self.consecutiveSessions += 1
    }
    
    /// Refills resources (e.g., at a Scenic Spot).
    public mutating func refill() {
        self.hydration = 1.0
        self.consecutiveSessions = 0
        self.lastRestTime = Date()
    }
    
    // MARK: - Status Checks
    
    /// Returns true if the player needs to rest (hydration low).
    public var isThirsty: Bool {
        return hydration <= Configuration.thirstThreshold
    }
    
    /// Returns true if the player has been hiking for too long without a break.
    /// (e.g. 3 consecutive sessions)
    public var isOverworked: Bool {
        return consecutiveSessions >= 3
    }
    
    /// Checks if a Scenic Spot should be suggested.
    public var shouldSuggestScenicSpot: Bool {
        return isThirsty || isOverworked
    }
    
    /// Returns a localized prompt for the current state.
    public var currentPrompt: String? {
        if isThirsty {
            return "Your canteen is running low. Find a Scenic Spot?"
        } else if isOverworked {
            return "You've hiked a long way. Take a moment to rest?"
        }
        return nil
    }
}
