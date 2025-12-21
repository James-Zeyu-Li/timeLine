import Foundation
import Combine

public class TemplateStore: ObservableObject {
    @Published public var templates: [TaskTemplate] = []
    
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
}
