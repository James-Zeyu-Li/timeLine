import Foundation

public struct FocusGroupSegment: Equatable {
    public let templateId: UUID
    public let startedAt: Date
    public let endedAt: Date

    public var duration: TimeInterval {
        max(0, endedAt.timeIntervalSince(startedAt))
    }
}

public struct FocusGroupSessionSummary: Equatable {
    public let allocations: [UUID: TimeInterval]
    public let totalFocusedSeconds: TimeInterval
    public let startedAt: Date
    public let segments: [FocusGroupSegment]
}

public final class FocusGroupSessionCoordinator {
    public let memberTemplateIds: [UUID]
    public private(set) var activeIndex: Int
    
    private var allocations: [UUID: TimeInterval]
    private let startTime: Date
    private var focusedCursor: TimeInterval
    private var lastSwitchAtFocused: TimeInterval
    private var isEnded = false
    private var segments: [FocusGroupSegment]
    
    public init(
        memberTemplateIds: [UUID],
        startTime: Date = Date(),
        activeIndex: Int = 0,
        focusedSeconds: TimeInterval = 0
    ) {
        self.memberTemplateIds = FocusGroupSessionCoordinator.uniqueIds(from: memberTemplateIds)
        let clampedIndex = min(max(0, activeIndex), max(self.memberTemplateIds.count - 1, 0))
        self.activeIndex = clampedIndex
        self.allocations = [:]
        self.startTime = startTime
        self.focusedCursor = max(0, focusedSeconds)
        self.lastSwitchAtFocused = self.focusedCursor
        self.segments = []

        if self.focusedCursor > 0, let activeId = activeTemplateId {
            allocations[activeId, default: 0] += self.focusedCursor
            segments.append(
                FocusGroupSegment(
                    templateId: activeId,
                    startedAt: startTime,
                    endedAt: startTime.addingTimeInterval(self.focusedCursor)
                )
            )
        }
    }
    
    @discardableResult
    public func switchTo(index: Int, at time: Date = Date()) -> Bool {
        guard !isEnded else { return false }
        guard index >= 0, index < memberTemplateIds.count else { return false }
        guard index != activeIndex else { return false }
        
        closeSegment()
        activeIndex = index
        lastSwitchAtFocused = focusedCursor
        return true
    }

    public func recordFocused(seconds: TimeInterval) {
        guard !isEnded else { return }
        let delta = max(0, seconds)
        guard delta > 0, let activeId = activeTemplateId else { return }
        focusedCursor += delta
        allocations[activeId, default: 0] += delta
    }
    
    public func endExploration(at time: Date = Date()) -> FocusGroupSessionSummary {
        if !isEnded {
            closeSegment()
            isEnded = true
        }
        let total = allocations.values.reduce(0, +)
        return FocusGroupSessionSummary(
            allocations: allocations,
            totalFocusedSeconds: total,
            startedAt: startTime,
            segments: segments
        )
    }
    
    private func closeSegment() {
        guard let activeId = activeTemplateId else { return }
        let delta = max(0, focusedCursor - lastSwitchAtFocused)
        guard delta > 0 else { return }
        let startedAt = startTime.addingTimeInterval(lastSwitchAtFocused)
        let endedAt = startTime.addingTimeInterval(focusedCursor)
        segments.append(
            FocusGroupSegment(
                templateId: activeId,
                startedAt: startedAt,
                endedAt: endedAt
            )
        )
    }
    
    private var activeTemplateId: UUID? {
        guard activeIndex >= 0, activeIndex < memberTemplateIds.count else { return nil }
        return memberTemplateIds[activeIndex]
    }
    
    private static func uniqueIds(from ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        var result: [UUID] = []
        for id in ids where !seen.contains(id) {
            seen.insert(id)
            result.append(id)
        }
        return result
    }
}
