import Foundation

public struct RestSuggestionEvent: Equatable {
    public let focusedSeconds: TimeInterval
    public let thresholdSeconds: TimeInterval

    public init(focusedSeconds: TimeInterval, thresholdSeconds: TimeInterval) {
        self.focusedSeconds = focusedSeconds
        self.thresholdSeconds = thresholdSeconds
    }
}

public final class RestPromptService {
    public let thresholdSeconds: TimeInterval

    private var focusedSinceReset: TimeInterval = 0
    private var hasSuggested = false

    public init(thresholdSeconds: TimeInterval = 50 * 60) {
        self.thresholdSeconds = thresholdSeconds
    }

    /// Records additional focused time and emits a suggestion when threshold is crossed.
    @discardableResult
    public func recordFocus(seconds: TimeInterval) -> RestSuggestionEvent? {
        guard seconds > 0 else { return nil }
        focusedSinceReset += seconds
        guard !hasSuggested, focusedSinceReset >= thresholdSeconds else { return nil }
        hasSuggested = true
        return RestSuggestionEvent(
            focusedSeconds: focusedSinceReset,
            thresholdSeconds: thresholdSeconds
        )
    }

    /// Reset after user chooses to continue (restart the 50m timer).
    public func resetAfterContinue() {
        focusedSinceReset = 0
        hasSuggested = false
    }

    /// Reset after user takes a rest or session ends.
    public func resetAfterRest() {
        focusedSinceReset = 0
        hasSuggested = false
    }
}
