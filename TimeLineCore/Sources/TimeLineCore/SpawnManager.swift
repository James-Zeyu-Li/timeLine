import Foundation

public struct SpawnManager {
    
    // MARK: - Spawning Logic
    
    /// Creates a playable Boss (Task) from a Template
    public static func spawn(from template: TaskTemplate) -> Boss {
        // Determine style
        let style: BossStyle = (template.style == .passive) ? .passive : .focus
        
        // Determine duration
        // Use template.duration or default to 30m (1800s)
        let duration = template.duration ?? 1800
        
        return Boss(
            name: template.title,
            maxHp: duration,
            style: style,
            category: template.category,
            templateId: template.id
        )
    }
    
    // MARK: - Repeat & Ledger Logic
    
    /// Returns a list of tasks that should be auto-spawned for a specific date,
    /// filtering out any that have already been spawned (checked via ledger).
    public static func processRepeats(
        templates: [TaskTemplate],
        for date: Date,
        ledger: Set<String>
    ) -> (tasks: [Boss], newKeys: [String]) {
        
        var spawnedTasks: [Boss] = []
        var newKeys: [String] = []
        
        // Format date primarily for the ledger key (YYYY-MM-DD)
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM-dd"
        // Ensure fixed timezone for deterministic keys? 
        // Actually, user is local, so current calendar is fine.
        let dateString = keyFormatter.string(from: date)
        
        for template in templates {
            if template.repeatRule.matches(date: date) {
                // Generate Spawn Key
                let key = "\(template.id.uuidString)_\(dateString)"
                
                // Check Ledger
                if !ledger.contains(key) {
                    let boss = spawn(from: template)
                    spawnedTasks.append(boss)
                    newKeys.append(key)
                }
            }
        }
        
        return (spawnedTasks, newKeys)
    }
}
