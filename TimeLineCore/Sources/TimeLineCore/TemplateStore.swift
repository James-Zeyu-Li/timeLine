import Foundation
import Combine

public class TemplateStore: ObservableObject {
    @Published public var templates: [TaskTemplate] = []
    
    /// Default templates for first-time users or after reset
    public static let defaultTemplates: [TaskTemplate] = [
        // Work Templates
        TaskTemplate(
            title: "Morning Email",
            style: .focus,
            duration: 900,  // 15 min
            category: .work
        ),
        TaskTemplate(
            title: "Deep Work Session",
            style: .focus,
            duration: 3600,  // 1 hour
            category: .work
        ),
        TaskTemplate(
            title: "Quick Meeting",
            style: .focus,
            duration: 1800,  // 30 min
            category: .work
        ),
        
        // Study Templates
        TaskTemplate(
            title: "Study Session",
            style: .focus,
            duration: 2700,  // 45 min
            category: .study
        ),
        TaskTemplate(
            title: "Review Notes",
            style: .focus,
            duration: 1200,  // 20 min
            category: .study
        ),
        
        // Other Templates
        TaskTemplate(
            title: "Gym Workout",
            style: .passive,
            duration: 3600,  // 1 hour
            category: .gym
        ),
        TaskTemplate(
            title: "Short Break",
            style: .passive,
            duration: 600,  // 10 min
            category: .rest
        )
    ]
    
    public init(templates: [TaskTemplate] = []) {
        self.templates = templates
    }
    
    public func add(_ template: TaskTemplate) {
        // Replace if exists (update), or append
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }
    }
    
    public func delete(_ template: TaskTemplate) {
        templates.removeAll { $0.id == template.id }
    }
    
    public func load(from storedTemplates: [TaskTemplate]) {
        self.templates = storedTemplates
    }
    
    /// Loads default templates (for first-time use or after reset)
    public func loadDefaults() {
        self.templates = Self.defaultTemplates
    }
}
