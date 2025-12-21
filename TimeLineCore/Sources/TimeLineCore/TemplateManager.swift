import Foundation

public struct TemplateManager {
    
    // MARK: - Spawning Logic
    
    /// Creates a playable Boss (Task) from a Template
    public static func spawn(from template: TaskTemplate) -> Boss {
        // Determine style
        let style: BossStyle = (template.style == .passive) ? .passive : .focus
        
        // Determine duration
        // If scheduled/fixedTime, use default duration or 0? 
        // Logic: Scheduled tasks might just be checkboxes (passive)
        // If they have a duration, use it. If not (e.g. fixed time only), default to 30m?
        // Let's use template.duration or default to 30m (1800s)
        let duration = template.duration ?? 1800
        
        return Boss(
            name: template.title,
            maxHp: duration,
            style: style,
            templateId: template.id
        )
    }
    
    // MARK: - Repeat Logic
    
    /// Returns a list of tasks that should be auto-spawned for a specific date
    public static func processRepeats(templates: [TaskTemplate], for date: Date) -> [Boss] {
        var spawnedTasks: [Boss] = []
        
        for template in templates {
            if template.repeatRule.matches(date: date) {
                let boss = spawn(from: template)
                spawnedTasks.append(boss)
            }
        }
        
        return spawnedTasks
    }
}
