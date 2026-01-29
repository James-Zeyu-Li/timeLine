import Foundation
#if os(iOS)
import ActivityKit
#endif

@available(iOS 26.0, *)
public class LiveActivityManager {
#if os(iOS)
    private var currentActivity: Activity<FocusSessionAttributes>?
#endif
    
    public init() {}
    
    public func startActivity(boss: Boss, at time: Date) {
#if os(iOS)
        endAllActivities()
        let attributes = FocusSessionAttributes(
            title: boss.name,
            modeName: boss.style == .focus ? "Observing" : "Expedition"
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
#endif
    }

    public func ensureActivity(boss: Boss, at time: Date) {
#if os(iOS)
        if currentActivity != nil { return }
        if let existing = Activity<FocusSessionAttributes>.activities.first {
            currentActivity = existing
            return
        }
        startActivity(boss: boss, at: time)
#endif
    }
    
    public func endActivity() {
#if os(iOS)
        guard let activity = currentActivity else {
            endAllActivities()
            return
        }
        
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
#endif
    }

    public func endAllActivities() {
#if os(iOS)
        let activities = Activity<FocusSessionAttributes>.activities
        guard !activities.isEmpty else { return }
        
        Task {
            let finalContentState = FocusSessionAttributes.ContentState(
                startTime: Date(),
                endTime: nil,
                isPaused: false
            )
            for activity in activities {
                await activity.end(
                    ActivityContent(state: finalContentState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
            print("[LiveActivityManager] Ended All Activities")
        }
        self.currentActivity = nil
#endif
    }
}
