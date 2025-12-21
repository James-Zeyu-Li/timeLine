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
    
    public init(title: String, duration: TimeInterval, style: BossStyle = .focus) {
        self.title = title
        self.duration = duration
        self.style = style
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
            BossPreset(title: "Plan Day", duration: 900, style: .focus), // 15m
            BossPreset(title: "Check Email", duration: 900, style: .passive), // 15m
            BossPreset(title: "Deep Work", duration: 3600, style: .focus) // 1h
        ]),
        
        RoutineTemplate(name: "Pomodoro Set", presets: [
            BossPreset(title: "Focus", duration: 1500, style: .focus),  // 25m
            BossPreset(title: "Short Break", duration: 300, style: .passive), // 5m Rest as Passive Task? Or actual Bonfire?
            // Note: Currently we treat Bonfires as auto-generated. 
            // Better to just let RouteGenerator handle breaks, or explicitly schedule them?
            // Let's stick to Tasks here. RouteGenerator creates Bonfires between them.
            BossPreset(title: "Focus", duration: 1500, style: .focus),
            BossPreset(title: "Focus", duration: 1500, style: .focus)
        ]),
        
        RoutineTemplate(name: "Health & Gym", presets: [
            BossPreset(title: "Warm Up", duration: 600, style: .passive), // 10m
            BossPreset(title: "Workout", duration: 2700, style: .passive), // 45m
            BossPreset(title: "Stretch", duration: 600, style: .passive) // 10m
        ])
    ]
}
