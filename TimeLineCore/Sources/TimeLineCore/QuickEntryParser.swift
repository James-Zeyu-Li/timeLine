import Foundation

public struct QuickEntryParser {
    
    // MARK: - Regex Patterns
    // Catch tags like @focus, @passive, @work, @study
    private static let tagPattern = #"@(\w+)"#
    
    // Catch duration like 30m, 1h, 90min, 1.5h
    // Groups: 1=Value, 2=Unit
    private static let durationPattern = #"(\d+(\.\d+)?)\s*(m|min|h|hr)"#
    
    public static func parse(input: String) -> TaskTemplate? {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedInput.isEmpty { return nil }
        
        var workingText = trimmedInput
        
        // 1. Extract Tags
        var style: BossStyle = .focus
        var category: TaskCategory = .work
        
        // Process tags
        let tagRegex = try! NSRegularExpression(pattern: tagPattern, options: .caseInsensitive)
        let tagMatches = tagRegex.matches(in: workingText, range: NSRange(workingText.startIndex..., in: workingText))
        
        // Iterate tags in reverse to allow easy range removal
        for match in tagMatches.reversed() {
            if let range = Range(match.range, in: workingText) {
                let fullTag = String(workingText[range]) // e.g., "@focus"
                let tagName = String(workingText[Range(match.range(at: 1), in: workingText)!]).lowercased()
                
                // Parse Style
                if tagName == "focus" { style = .focus }
                else if tagName == "passive" { style = .passive }
                
                // Parse Category
                else if let matchedCat = TaskCategory(rawValue: tagName) {
                    category = matchedCat
                }
                
                // Remove tag from title candidates
                workingText.removeSubrange(range)
            }
        }
        
        // 2. Extract Duration
        var duration: TimeInterval = 1500 // Default 25m
        var durationFound = false
        
        let durRegex = try! NSRegularExpression(pattern: durationPattern, options: .caseInsensitive)
        // Find FIRST duration match
        if let match = durRegex.firstMatch(in: workingText, range: NSRange(workingText.startIndex..., in: workingText)) {
            if let range = Range(match.range, in: workingText),
               let valRange = Range(match.range(at: 1), in: workingText),
               let unitRange = Range(match.range(at: 3), in: workingText) {
                
                let valueStr = String(workingText[valRange])
                let unitStr = String(workingText[unitRange]).lowercased()
                
                if let value = Double(valueStr) {
                    if unitStr.starts(with: "h") {
                        duration = value * 3600
                    } else {
                        duration = value * 60
                    }
                    durationFound = true
                }
                
                // Remove duration from text
                workingText.removeSubrange(range)
            }
        }
        
        // 3. Finalize Title
        // Collapse multiple spaces
        let title = workingText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if title.isEmpty { return nil }
        
        // Smart defaults: if no duration found and style is passive, default to 0?
        // But TaskTemplate.duration is optional.
        // Let's stick to spec: "default 25m" if not specified.
        
        return TaskTemplate(
            id: UUID(),
            title: title,
            style: style,
            duration: duration, 
            fixedTime: nil,
            repeatRule: .none, // Quick Entry is strictly one-off
            category: category
        )
    }
}
