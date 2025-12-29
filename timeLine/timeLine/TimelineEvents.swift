import Foundation

// MARK: - Timeline UI Events
/// Events emitted by TimelineEventCoordinator, consumed by UI for banners/transitions.
/// These are "instantaneous facts" - UI shows a banner and it auto-dismisses.
/// Direction: Coordinator → UI (never the reverse).
public enum TimelineUIEvent: Equatable {
    case victory(taskName: String, focusedMinutes: Int)
    case retreat(taskName: String, wastedMinutes: Int)
    case incompleteExit(taskName: String, focusedSeconds: TimeInterval, remainingSeconds: TimeInterval?)
    case bonfireComplete
    case bonfireSuggested(reason: String, bonfireId: UUID?)
}

// Note: TimelineEventsAdapter has been replaced by TimelineEventCoordinator
// which provides unified event emission with deduplication and safe advancement.
