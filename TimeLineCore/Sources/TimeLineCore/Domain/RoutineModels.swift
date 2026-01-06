import Foundation

public enum BossStyle: String, Codable {
    case focus
    case passive
}

public struct BossPreset: Codable, Identifiable {
    public var id = UUID()
    public let title: String
    public let duration: TimeInterval
    public let style: BossStyle
    public let category: TaskCategory
    
    public init(title: String, duration: TimeInterval, style: BossStyle = .focus, category: TaskCategory = .work) {
        self.title = title
        self.duration = duration
        self.style = style
        self.category = category
    }
}

public struct RoutineTemplate: Codable, Identifiable {
    public var id = UUID()
    public let name: String
    public let presets: [BossPreset]
    
    public init(name: String, presets: [BossPreset]) {
        self.name = name
        self.presets = presets
    }
}

public struct RoutineProvider {
    public static let defaults: [RoutineTemplate] = [
        RoutineTemplate(name: "Morning Flow", presets: [
            BossPreset(title: "Plan Day", duration: 900, style: .focus, category: .work), // 15m
            BossPreset(title: "Check Email", duration: 600, style: .passive, category: .work), // 10m
            BossPreset(title: "Deep Work", duration: 3600, style: .focus, category: .work) // 1h
        ]),
        
        RoutineTemplate(name: "Study Session", presets: [
            BossPreset(title: "Review Notes", duration: 900, style: .focus, category: .study), // 15m
            BossPreset(title: "Active Learning", duration: 2700, style: .focus, category: .study), // 45m
            BossPreset(title: "Practice Problems", duration: 1800, style: .focus, category: .study) // 30m
        ]),
        
        RoutineTemplate(name: "Pomodoro Set", presets: [
            BossPreset(title: "Focus Block 1", duration: 1500, style: .focus, category: .work),  // 25m
            BossPreset(title: "Focus Block 2", duration: 1500, style: .focus, category: .work),  // 25m
            BossPreset(title: "Focus Block 3", duration: 1500, style: .focus, category: .work),  // 25m
            BossPreset(title: "Focus Block 4", duration: 1500, style: .focus, category: .work)   // 25m
        ]),
        
        RoutineTemplate(name: "Health & Fitness", presets: [
            BossPreset(title: "Warm Up", duration: 600, style: .passive, category: .gym), // 10m
            BossPreset(title: "Workout", duration: 2700, style: .passive, category: .gym), // 45m
            BossPreset(title: "Cool Down", duration: 600, style: .passive, category: .gym) // 10m
        ]),
        
        RoutineTemplate(name: "Creative Work", presets: [
            BossPreset(title: "Brainstorm", duration: 900, style: .focus, category: .other), // 15m
            BossPreset(title: "Create", duration: 3600, style: .focus, category: .other), // 1h
            BossPreset(title: "Review & Polish", duration: 1200, style: .focus, category: .other) // 20m
        ])
    ]
}
