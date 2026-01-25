import Foundation
import Combine

/// The heartbeat of the game world. 
/// Manages current time, day progress (sun cycle), and emits ticks for game loop updates.
@MainActor
public class MasterClockService: ObservableObject {
    // MARK: - Published State
    @Published public private(set) var currentTime: Date = Date()
    @Published public private(set) var dayProgress: Double = 0.0 // 0.0 (Start of Day) to 1.0 (End of Day)
    @Published public private(set) var timeOfDay: TimeOfDay = .day
    
    // MARK: - Configuration
    private let dayStartHour: Int = 6  // 06:00
    private let dayEndHour: Int = 24   // 24:00 (Midnight)
    private var timer: AnyCancellable?
    
    public enum TimeOfDay: String {
        case dawn    // 06:00 - 09:00
        case day     // 09:00 - 17:00
        case dusk    // 17:00 - 20:00
        case night   // 20:00 - 06:00
        
        public var colorHex: String {
            switch self {
            case .dawn: return "#FF9E80" // Warm Orange
            case .day: return "#80D8FF"  // Bright Blue
            case .dusk: return "#B39DDB" // Purple
            case .night: return "#1A237E" // Deep Blue
            }
        }
    }
    
    // MARK: - Init
    public init() {
        startTicking()
    }
    
    // MARK: - Logic
    private func startTicking() {
        // Update immediately
        tick()
        
        // Tick every minute to save resources, or every second if we need seconds display
        // Using 5 seconds for now to balance responsiveness and battery
        timer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    private func tick() {
        let now = Date()
        self.currentTime = now
        self.dayProgress = calculateDayProgress(at: now)
        self.timeOfDay = determineTimeOfDay(at: now)
    }
    
    private func calculateDayProgress(at date: Date) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        // Convert current time to total minutes from midnight
        let currentMinutes = (hour * 60) + minute
        
        // Start and End in minutes
        let startMinutes = dayStartHour * 60
        let endMinutes = dayEndHour * 60
        let totalDayMinutes = endMinutes - startMinutes
        
        if currentMinutes < startMinutes {
            return 0.0 // Too early
        } else if currentMinutes >= endMinutes {
            return 1.0 // Too late
        } else {
            let elapsed = Double(currentMinutes - startMinutes)
            return elapsed / Double(totalDayMinutes)
        }
    }
    
    private func determineTimeOfDay(at date: Date) -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: date)
        
        switch hour {
        case 6..<9: return .dawn
        case 9..<17: return .day
        case 17..<20: return .dusk
        default: return .night
        }
    }
    
    // MARK: - Debug / Testing
    public func warpTime(to date: Date) {
        // Pauses automatic ticking to simulate time
        timer?.cancel()
        self.currentTime = date
        self.dayProgress = calculateDayProgress(at: date)
        self.timeOfDay = determineTimeOfDay(at: date)
    }
    
    public func resume() {
        startTicking()
    }
}
