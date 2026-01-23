import Foundation
import ActivityKit

@available(iOS 26.0, *)
public class LiveActivityManager {
    private var currentActivity: Activity<FocusSessionAttributes>?
    
    public init() {}
    
    public func startActivity(boss: Boss, at time: Date) {
        let attributes = FocusSessionAttributes(
            title: boss.name,
            modeName: boss.style == .focus ? "Strict Focus" : "Focus Group"
        )
        
        let endTime = boss.style == .focus ? time.addingTimeInterval(boss.maxHp) : nil
        let contentState = FocusSessionAttributes.ContentState(
            startTime: time,
            endTime: endTime,
            isPaused: false
        )
        
        do {
            let activity = try Activity<FocusSessionAttributes>.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil)
            )
            self.currentActivity = activity
            print("[LiveActivityManager] Started Activity: \(activity.id)")
        } catch {
            print("[LiveActivityManager] Failed to start Activity: \(error)")
        }
    }
    
    public func endActivity() {
        guard let activity = currentActivity else { return }
        
        // We can't easily access the original start time unless we stored it or passed it.
        // For ending, usually irrelevant as activity dismisses.
        // But let's create a final state.
        let finalContentState = FocusSessionAttributes.ContentState(
            startTime: Date(), // Placeholder, won't show
            endTime: nil,
            isPaused: false
        )
        
        Task {
            await activity.end(
                ActivityContent(state: finalContentState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            print("[LiveActivityManager] Ended Activity")
        }
        self.currentActivity = nil
    }
}
