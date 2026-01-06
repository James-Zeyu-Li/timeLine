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
    private var lastSwitchAt: Date
    private let startTime: Date
    private var isEnded = false
    private var segments: [FocusGroupSegment]
    
    public init(
        memberTemplateIds: [UUID],
        startTime: Date = Date(),
        activeIndex: Int = 0
    ) {
        self.memberTemplateIds = FocusGroupSessionCoordinator.uniqueIds(from: memberTemplateIds)
        let clampedIndex = min(max(0, activeIndex), max(self.memberTemplateIds.count - 1, 0))
        self.activeIndex = clampedIndex
        self.allocations = [:]
        self.lastSwitchAt = startTime
        self.startTime = startTime
        self.segments = []
    }
    
    @discardableResult
    public func switchTo(index: Int, at time: Date = Date()) -> Bool {
        guard !isEnded else { return false }
        guard index >= 0, index < memberTemplateIds.count else { return false }
        guard index != activeIndex else { return false }
        
        accumulateTime(until: time)
        activeIndex = index
        lastSwitchAt = time
        return true
    }
    
    public func endExploration(at time: Date = Date()) -> FocusGroupSessionSummary {
        if !isEnded {
            accumulateTime(until: time)
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
    
    private func accumulateTime(until time: Date) {
        guard let activeId = activeTemplateId else { return }
        let delta = max(0, time.timeIntervalSince(lastSwitchAt))
        if delta > 0 {
            segments.append(
                FocusGroupSegment(
                    templateId: activeId,
                    startedAt: lastSwitchAt,
                    endedAt: time
                )
            )
        }
        allocations[activeId, default: 0] += delta
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
