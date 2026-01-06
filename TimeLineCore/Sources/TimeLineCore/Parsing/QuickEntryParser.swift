import Foundation

public struct QuickEntryParser {
    
    public enum QuickEntryPlacement: String, Codable {
        case today
        case inbox
    }
    
    public struct QuickEntryResult {
        public let template: CardTemplate
        public let placement: QuickEntryPlacement
        public let suggestedTime: DateComponents?
    }
    
    // MARK: - Regex Patterns
    // Catch tags like @focus, @passive, @work, @study
    private static let tagPattern = #"@(\w+)"#
    
    // Catch duration like 30m, 1h, 90min, 1.5h
    // Groups: 1=Value, 2=Unit
    private static let durationPattern = #"(\d+(\.\d+)?)\s*(m|min|h|hr)"#
    
    public static func parseDetailed(input: String, defaultTonightHour: Int = 20) -> QuickEntryResult? {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedInput.isEmpty { return nil }
        
        var workingText = trimmedInput
        var placement: QuickEntryPlacement = .today
        var suggestedTime: DateComponents? = nil
        var repeatRule: RepeatRule = .none
        
        // 1. Extract Tags
        var style: BossStyle = .focus
        var category: TaskCategory = .work

        // 0. Extract simple time keywords
        if workingText.contains("每天") {
            repeatRule = .daily
            workingText = workingText.replacingOccurrences(of: "每天", with: "")
        }
        if workingText.contains("明天") {
            placement = .inbox
            workingText = workingText.replacingOccurrences(of: "明天", with: "")
        }
        if workingText.contains("今晚") {
            var components = DateComponents()
            components.hour = defaultTonightHour
            components.minute = 0
            suggestedTime = components
            workingText = workingText.replacingOccurrences(of: "今晚", with: "")
        }
        
        // Process tags
        let tagRegex = try! NSRegularExpression(pattern: tagPattern, options: .caseInsensitive)
        let tagMatches = tagRegex.matches(in: workingText, range: NSRange(workingText.startIndex..., in: workingText))
        
        // Iterate tags in reverse to allow easy range removal
        for match in tagMatches.reversed() {
            if let range = Range(match.range, in: workingText) {
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
        let durRegex = try! NSRegularExpression(pattern: durationPattern, options: .caseInsensitive)
        let durationMatches = durRegex.matches(in: workingText, range: NSRange(workingText.startIndex..., in: workingText))
        if !durationMatches.isEmpty {
            var totalSeconds: TimeInterval = 0
            for match in durationMatches {
                guard let valRange = Range(match.range(at: 1), in: workingText),
                      let unitRange = Range(match.range(at: 3), in: workingText) else {
                    continue
                }
                let valueStr = String(workingText[valRange])
                let unitStr = String(workingText[unitRange]).lowercased()
                guard let value = Double(valueStr) else { continue }
                if unitStr.starts(with: "h") {
                    totalSeconds += value * 3600
                } else {
                    totalSeconds += value * 60
                }
            }

            if totalSeconds > 0 {
                duration = totalSeconds
            }

            for match in durationMatches.reversed() {
                if let range = Range(match.range, in: workingText) {
                    workingText.removeSubrange(range)
                }
            }
        }
        
        // 3. Finalize Title
        // Collapse multiple spaces
        let title = workingText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if title.isEmpty { return nil }
        
        // Smart defaults: if no duration found and style is passive, default to 0?
        // Let's stick to spec: "default 25m" if not specified.
        
        let template = CardTemplate(
            id: UUID(),
            title: title,
            icon: category.icon,
            defaultDuration: duration,
            tags: [],
            energyColor: energyToken(for: category),
            category: category,
            style: style,
            fixedTime: suggestedTime,
            repeatRule: repeatRule
        )
        
        return QuickEntryResult(
            template: template,
            placement: placement,
            suggestedTime: suggestedTime
        )
    }
    
    public static func parse(input: String) -> CardTemplate? {
        return parseDetailed(input: input)?.template
    }

    private static func energyToken(for category: TaskCategory) -> EnergyColorToken {
        switch category {
        case .work, .study:
            return .focus
        case .gym:
            return .gym
        case .rest:
            return .rest
        case .other:
            return .creative
        }
    }
}
