import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
// ActivityKit removed from import to avoid build issues (wrapped in Manager): - Session Result Event
/// Emitted when a battle session ends. Contains all data needed for UI/Stats.
/// This is the "atomic" event that carries session context.
public enum SessionEndReason: String, Codable, Equatable {
    case victory
    case retreat
    case incompleteExit
    case completedExploration
}

public struct SessionResult: Equatable {
    public let bossName: String
    public let focusedSeconds: TimeInterval
    public let wastedSeconds: TimeInterval
    public let endReason: SessionEndReason
    public let remainingSecondsAtExit: TimeInterval?
    public let focusGroupSummary: FocusGroupSessionSummary?

    public static func completedExploration(
        bossName: String,
        focusedSeconds: TimeInterval,
        wastedSeconds: TimeInterval,
        summary: FocusGroupSessionSummary?
    ) -> SessionResult {
        SessionResult(
            bossName: bossName,
            focusedSeconds: focusedSeconds,
            wastedSeconds: wastedSeconds,
            endReason: .completedExploration,
            remainingSecondsAtExit: nil,
            focusGroupSummary: summary
        )
    }
}

@MainActor
public class BattleEngine: ObservableObject {
    @Published public var state: BattleState = .idle
    // Live Activity Manager (Type Erased for Availability)
    private var liveActivityManager: Any?
    
    // Dependencies
    // private let timelineStore: TimelineStore // Removed due to missing type definition in Core
    @Published public var currentBoss: Boss?
    private let masterClock: MasterClockService
    
    // Internal state for time tracking
    private var startTime: Date?
    private var elapsedBeforeCurrentSession: TimeInterval = 0
    private var lastActiveTime: Date = Date()
    private let idleThreshold: TimeInterval = 300 // 5 minutes
    
    // Phase 4: Distraction Logic
    @Published public var isImmune: Bool = false
    @Published public var immunityCount: Int = 1
    @Published public var wastedTime: TimeInterval = 0
    @Published public var shadowAccumulated: TimeInterval = 0 // "Shadow" mechanic (unaccounted time)

    // Freeze (real-world interruption)
    public let maxFreezeTokens = 3
    @Published public var freezeTokensUsed: Int = 0
    @Published public var freezeHistory: [FreezeRecord] = []
    
    public var freezeTokensRemaining: Int {
        max(0, maxFreezeTokens - freezeTokensUsed)
    }
    
    // Total focused time recorded in previous sessions of the day
    @Published public var totalFocusedHistoryToday: TimeInterval = 0
    
    // Long-term history
    @Published public var history: [DailyFunctionality] = []
    
    // Phase 2: Naturalist Mechanics
    @Published public var stamina = StaminaSystem()
    @Published public var specimenCollection = SpecimenCollection()
    
    // MARK: - Session Complete Publisher
    /// Emits when a session ends (victory or retreat). Use this for event-driven architecture.
    private let sessionCompleteSubject = PassthroughSubject<SessionResult, Never>()
    public var onSessionComplete: AnyPublisher<SessionResult, Never> {
        sessionCompleteSubject.eraseToAnyPublisher()
    }
    
    public var totalFocusedToday: TimeInterval {
        var total = totalFocusedHistoryToday
        // Only add active session progress if we are currently fighting
        if (state == .fighting || state == .paused || state == .frozen), let boss = currentBoss {
            let currentFocused = boss.maxHp - boss.currentHp
            total += currentFocused
        }
        return total
    }
    
    /// Returns the remaining time for the current task/rest session.
    /// Used for accurate time estimation in Timeline UI.
    public var remainingTime: TimeInterval? {
        if state == .fighting, let boss = currentBoss, let start = startTime {
            let elapsed = Date().timeIntervalSince(start) + elapsedBeforeCurrentSession
            return max(0, boss.maxHp - elapsed)
        } else if (state == .paused || state == .frozen), let boss = currentBoss {
            let effectiveCombatTime = max(0, elapsedBeforeCurrentSession - wastedTime)
            return max(0, boss.maxHp - effectiveCombatTime)
        } else if state == .resting {
            // For bonfire, we need to track duration differently
            // For now, return nil as resting doesn't have a fixed duration in current model
            return nil
        }
        
        return nil
    }
    
    // Track when we went into background to calculate wasted time
    private var distractionStartTime: Date?
    private var freezeStartTime: Date?
    
    // Phase 19: Ambient Companion
    @Published public var shouldShow50MinCue: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    // Idempotent guard for finalizeSession
    private var hasFinalized = false
    private var endReasonOverride: SessionEndReason?
    private var remainingSecondsAtExit: TimeInterval?
    private var focusGroupSummaryOverride: FocusGroupSessionSummary?
    
    public init(masterClock: MasterClockService) {
        self.masterClock = masterClock
        
        // Subscribe to Master Clock for Observation Cues
        masterClock.$currentTime
            .sink { [weak self] _ in
                self?.checkObservationCues()
            }
            .store(in: &cancellables)
    }
    
    private func checkObservationCues() {
        guard state == .fighting else {
            if shouldShow50MinCue { shouldShow50MinCue = false }
            return
        }
        
        let duration = currentSessionElapsed()
        // Trigger cue at 50 minutes (3000 seconds)
        if duration >= 3000 && !shouldShow50MinCue {
            shouldShow50MinCue = true
            // Haptic feedack could go here
        }
    }
    
    public func currentSessionElapsed() -> TimeInterval {
        guard let start = startTime else { return elapsedBeforeCurrentSession }
        // If paused, just return elapsed
        if state == .paused { return elapsedBeforeCurrentSession }
        
        // Calculate total time including current active session
        // Note: We use Date() here or masterClock.currentTime? 
        // Using Date() for immediate consistency, masterClock is for ticks.
        return Date().timeIntervalSince(start) + elapsedBeforeCurrentSession
    }
    
    public func startBattle(boss: Boss, at time: Date = Date()) {
        self.currentBoss = boss
        self.elapsedBeforeCurrentSession = 0
        self.startTime = time
        self.state = .fighting
        // Reset Phase 4 stats
        self.wastedTime = 0
        self.immunityCount = 1 
        self.isImmune = false
        self.hasFinalized = false
        self.endReasonOverride = nil
        self.remainingSecondsAtExit = nil
        self.focusGroupSummaryOverride = nil
        self.freezeStartTime = nil
        print("[Engine] Battle Started: \(boss.name) at \(time)")
        
        // Start Live Activity
        // Start Live Activity
        if #available(iOS 26.0, *) {
            if liveActivityManager == nil {
                liveActivityManager = LiveActivityManager()
            }
            (liveActivityManager as? LiveActivityManager)?.startActivity(boss: boss, at: time)
        }
    }
    
    public func pause(at time: Date = Date()) {
        guard state == .fighting, let start = startTime else { return }
        let sessionElapsed = time.timeIntervalSince(start)
        self.elapsedBeforeCurrentSession += sessionElapsed
        self.startTime = nil
        self.state = .paused
        print("[Engine] Paused. Total elapsed: \(self.elapsedBeforeCurrentSession)")
    }
    
    public func resume(at time: Date = Date()) {
        guard state == .paused else { return }
        self.startTime = time
        self.state = .fighting
        print("[Engine] Resumed at \(time)")
    }

    public func freeze(at time: Date = Date()) -> Bool {
        guard state == .fighting, let boss = currentBoss, boss.style == .focus else { return false }
        guard freezeTokensUsed < maxFreezeTokens else { return false }
        finalizeDistraction(at: time)
        pause(at: time)
        freezeStartTime = time
        freezeTokensUsed += 1
        state = .frozen
        print("[Engine] Frozen at \(time)")
        return true
    }

    public func resumeFromFreeze(at time: Date = Date()) {
        guard state == .frozen else { return }
        if let start = freezeStartTime {
            let duration = max(0, time.timeIntervalSince(start))
            let record = FreezeRecord(
                startedAt: start,
                endedAt: time,
                duration: duration,
                bossName: currentBoss?.name
            )
            freezeHistory.append(record)
        }
        freezeStartTime = nil
        startTime = time
        state = .fighting
        print("[Engine] Resumed from Freeze at \(time)")
    }
    
    public func retreat(at time: Date = Date()) {
        if state == .fighting, let boss = currentBoss {
            finalizeDistraction(at: time)
            if boss.style == .focus, let remaining = remainingTime(at: time) {
                var updatedBoss = boss
                updatedBoss.currentHp = remaining
                currentBoss = updatedBoss
                remainingSecondsAtExit = remaining
            }
        }
        endReasonOverride = .incompleteExit
        self.state = .retreat
        self.startTime = nil
        self.distractionStartTime = nil
        print("[Engine] Retreat")
        finalizeSession()
    }

    public func endExploration(summary: FocusGroupSessionSummary? = nil, at time: Date = Date()) {
        if state == .fighting, let boss = currentBoss {
            finalizeDistraction(at: time)
            if boss.style == .focus, let remaining = remainingTime(at: time) {
                var updatedBoss = boss
                updatedBoss.currentHp = remaining
                currentBoss = updatedBoss
            }
        }
        let resolvedSummary = resolveExplorationSummary(
            provided: summary,
            at: time
        )
        endReasonOverride = .completedExploration
        focusGroupSummaryOverride = resolvedSummary
        remainingSecondsAtExit = nil
        state = .retreat
        startTime = nil
        distractionStartTime = nil
        print("[Engine] Exploration Ended")
        finalizeSession()
    }

    public func abortSession() {
        guard state == .fighting || state == .paused || state == .frozen else { return }
        state = .idle
        currentBoss = nil
        startTime = nil
        elapsedBeforeCurrentSession = 0
        wastedTime = 0
        isImmune = false
        immunityCount = 1
        distractionStartTime = nil
        freezeStartTime = nil
        hasFinalized = false
        endReasonOverride = nil
        remainingSecondsAtExit = nil
        focusGroupSummaryOverride = nil
        print("[Engine] Session Aborted (no record)")
    }

    public func currentSessionElapsed(at time: Date = Date()) -> TimeInterval? {
        switch state {
        case .fighting:
            guard let start = startTime else { return nil }
            return elapsedBeforeCurrentSession + time.timeIntervalSince(start)
        case .paused, .frozen:
            return elapsedBeforeCurrentSession
        default:
            return nil
        }
    }
    
    /// Starts a rest period (Bonfire).
    /// Unlike battles, rest periods don't track wasted time - they're mandatory breaks.
    public func startRest(duration: TimeInterval = 900) {
        self.state = .resting
        self.startTime = Date()
        self.elapsedBeforeCurrentSession = 0
        self.stamina.refill() // Refill canteen
        print("[Engine] Resting at Scenic Spot. Canteen refilled.")
    }
    
    /// Ends the current rest period and returns to idle state.
    /// Called when user completes their break.
    public func endRest() {
        self.state = .idle
        self.startTime = nil
        print("[Engine] Finished Resting")
    }
    
    // MARK: - Phase 4: Lifecycle & Immunity
    
    public func grantImmunity() {
        guard immunityCount > 0 else { return }
        immunityCount -= 1
        isImmune = true
        print("[Engine] Immunity Granted. Remaining: \(immunityCount)")
    }
    
    public func handleBackgrounding(at time: Date = Date()) {
        guard state == .fighting else { return }
        
        if isImmune {
            print("[Engine] Backgrounded with Immunity. Boss continues taking damage.")
        } else {
            // Not Immune: Start counting wasted time
            distractionStartTime = time
            print("[Engine] Backgrounded (Distracted). Boss damage PAUSED. Timer continues.")
        }
    }
    
    public func handleForegrounding(at time: Date = Date()) {
        guard state == .fighting else { return }
        
        if isImmune {
            // Consumed the immunity token
            isImmune = false
            print("[Engine] Foregrounded. Immunity consumed.")
        } else {
            // Was distracted
            if let start = distractionStartTime {
                let distractedDuration = time.timeIntervalSince(start)
                
                // Grace Period Logic (Naturalist: The "Shh..." moment)
                // If the user returns quickly (e.g. < 10s), the bird is not scared.
                let gracePeriod: TimeInterval = 10.0
                
                if distractedDuration < gracePeriod {
                    print("[Engine] Grace Period Saved! Duration: \(distractedDuration)s < \(gracePeriod)s. Bird stays.")
                    // Do NOT add to wastedTime
                } else {
                    wastedTime += distractedDuration
                    print("[Engine] Bird Scared! Wasted: \(distractedDuration)s. Total Wasted: \(wastedTime)s")
                }
                
                distractionStartTime = nil
            }
        }
    }
    
    /// Updates the engine state based on the current time.
    /// Should be called periodically (e.g. from a Timer).
    public func tick(at time: Date = Date()) {
        guard state == .fighting, let boss = currentBoss, let start = startTime else { return }
        
        // Passive/Flexible Task Logic
        // We track time but don't enforce maxHp limits or auto-fail.
        // Proceed to calculate time...
        
        // Calculate total time elapsed (The Clock)
        let currentSessionElapsed = time.timeIntervalSince(start)
        let totalElapsed = elapsedBeforeCurrentSession + currentSessionElapsed
        
        // Calculate Wasted Time (if currently distracted, add pending distraction)
        var currentWasted = wastedTime
        if let distStart = distractionStartTime {
            currentWasted += time.timeIntervalSince(distStart)
        }
        
        // Effective Combat Time = Total Time - Wasted Time
        let effectiveCombatTime = totalElapsed - currentWasted
        
        // Update HP based on Effective Time
        var newHp = boss.maxHp - effectiveCombatTime
        
        // Check for Time Out (Timer > MaxHP) - regardless of HP
        // If you wasted too much time, you might run out of time while Boss still has HP!
        // That is a FAIL / RETREAT condition technically, or just "Time's Up"
        // For V0, let's keep it simple: Victory is only when HP <= 0.
        // If Time runs out but HP > 0, what happens? 
        // Let's say maxHp is the "Time Limit".
        // So Remaining Time = maxHp - totalElapsed.
        
        // Check for Time Out (Timer > MaxHP) - regardless of HP
        // Passive tasks (Flexible) do NOT timeout.
        if boss.style != .passive && totalElapsed >= boss.maxHp {
             // Time Over!
             if newHp <= 0 {
                 // Clean win
                 self.state = .victory
                 print("[Engine] Victory!")
             } else {
                 // Time ran out but Boss alive (Too much wasted time)
                 // Treat as Retreat/Defeat for now? Or just Stop?
                 self.state = .retreat // Let's call it retreat for now as "Failed"
                 endReasonOverride = .retreat
                 remainingSecondsAtExit = max(0, newHp)
                 print("[Engine] Time Over! Boss survived. You wasted too much time.")
             }
             self.startTime = nil
             self.distractionStartTime = nil
        } else if newHp <= 0 {
            // Killed before time limit
            newHp = 0
            self.state = .victory
            self.startTime = nil
            self.distractionStartTime = nil
            print("[Engine] Victory!")
        }
        
        // Check for Shadow Accumulation (Idle Time)
        // If we are fighting, we are active.
        lastActiveTime = time
        
        // Update boss model
        var updatedBoss = boss
        updatedBoss.currentHp = newHp
        self.currentBoss = updatedBoss
        
        // If session just ended, record the progress
        if state == .victory || state == .retreat {
            finalizeSession()
        }
    }
    
    public func updateShadow(at time: Date) {
        // Called by MasterClock if not fighting
        guard state == .idle else { return }
        
        // If user hasn't fought or rested for > threshold
        let timeSinceActive = time.timeIntervalSince(lastActiveTime)
        if timeSinceActive > idleThreshold {
             // Accumulate Shadow (visual pressure)
             shadowAccumulated = timeSinceActive - idleThreshold
        }
    }
    
    public func completePassiveTask() {
        guard state == .fighting, let boss = currentBoss, boss.style == .passive else { return }
        self.state = .victory
        self.startTime = nil
        print("[Engine] Passive Task Completed!")
        finalizeSession()
    }
    
    // MARK: - Debug / Testing
    public func forceCompleteTask() {
        guard state == .fighting, let boss = currentBoss else { return }
        print("[Engine] Force Completing Task: \(boss.name)")
        
        // Instant kill
        var updatedBoss = boss
        updatedBoss.currentHp = 0
        self.currentBoss = updatedBoss
        
        // Trigger victory logic
        self.state = .victory
        self.startTime = nil
        finalizeSession()
    }
    
    private func finalizeSession() {
        guard !hasFinalized else { return }
        hasFinalized = true
        
        guard let boss = currentBoss else { return }
        
        // Calculate focused time for this session
        // Calculate focused time for this session
        let focusedThisSession: TimeInterval
        if boss.style == .passive {
             // For passive tasks, focused time is the Effective Combat Time so far
             // Recalculate based on current state (similar to tick)
             if let start = startTime {
                 let currentElapsed = Date().timeIntervalSince(start)
                 let totalElapsed = elapsedBeforeCurrentSession + currentElapsed
                 // Subtract wasted time
                 var currentWasted = wastedTime
                 if let distStart = distractionStartTime {
                     currentWasted += Date().timeIntervalSince(distStart)
                 }
                 focusedThisSession = max(0, totalElapsed - currentWasted)
             } else {
                 // Paused or Frozen or Idle
                 let effective = max(0, elapsedBeforeCurrentSession - wastedTime)
                 focusedThisSession = effective
             }
        } else {
             focusedThisSession = max(0, boss.maxHp - boss.currentHp)
        }
        
        // Emit session complete event BEFORE clearing boss
        let result: SessionResult
        let endReason = endReasonOverride ?? (state == .victory ? .victory : .retreat)
        let remaining: TimeInterval?
        switch endReason {
        case .victory, .completedExploration:
            remaining = nil
        case .retreat, .incompleteExit:
            remaining = remainingSecondsAtExit ?? max(0, boss.currentHp)
        }
        let summary = endReason == .completedExploration ? focusGroupSummaryOverride : nil
        result = SessionResult(
            bossName: boss.name,
            focusedSeconds: focusedThisSession,
            wastedSeconds: wastedTime,
            endReason: endReason,
            remainingSecondsAtExit: remaining,
            focusGroupSummary: summary
        )
        sessionCompleteSubject.send(result)
        print("[Engine] Emitting SessionResult: \(result)")
        
        // Phase 21: Haptic feedback for completion ceremony
        #if os(iOS)
        Task { @MainActor in
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
        #endif
        
        totalFocusedHistoryToday += focusedThisSession
        
        // Consume stamina
        stamina.consume(duration: focusedThisSession)
        
        // Add to Field Journal (Specimen Collection)
        // Determine quality based on wasted time AND endReason
        let quality: CollectionQuality
        // If ended due to long absence (retreat after >5m), mark as Fled
        if endReason == .incompleteExit && wastedTime >= 300 {
            quality = .fled
        } else if wastedTime <= 0 {
            quality = .perfect
        } else if wastedTime < 60 {
            quality = .good
        } else if wastedTime < 300 {
            quality = .flawed
        } else {
            quality = .fled
        }
        
        let specimen = CollectedSpecimen(
            templateId: nil, // TODO: Needs CardTemplate awareness in Boss or pass it in
            title: boss.name,
            completedAt: Date(),
            duration: focusedThisSession,
            quality: quality
        )
        specimenCollection.add(specimen)
        print("[Engine] Collected Specimen: \(specimen.title) (\(specimen.quality))")
        
        // Update long-term history
        let sessionStats = DailyFunctionality(
            date: Date(),
            totalFocusedTime: focusedThisSession,
            totalWastedTime: wastedTime,
            sessionsCount: 1
        )
        self.history = StatsAggregator.updateHistory(history: self.history, session: sessionStats)
        
        // Clear current boss to prevent double-finalizing if tick is called again
        self.currentBoss = nil 
        self.endReasonOverride = nil
        self.remainingSecondsAtExit = nil
        self.focusGroupSummaryOverride = nil
        print("[Engine] Session Finalized. Added \(focusedThisSession)s to daily total. History now has \(history.count) days.")
        
        // End Live Activity
        // End Live Activity
        if #available(iOS 26.0, *) {
           (liveActivityManager as? LiveActivityManager)?.endActivity()
        }
    }

    private func finalizeDistraction(at time: Date) {
        if let start = distractionStartTime {
            let distractedDuration = time.timeIntervalSince(start)
            wastedTime += distractedDuration
            distractionStartTime = nil
        }
    }
    
    private func remainingTime(at time: Date) -> TimeInterval? {
        guard state == .fighting, let boss = currentBoss, boss.style == .focus, let start = startTime else { return nil }
        let currentSessionElapsed = time.timeIntervalSince(start)
        let totalElapsed = elapsedBeforeCurrentSession + currentSessionElapsed
        var currentWasted = wastedTime
        if let distStart = distractionStartTime {
            currentWasted += time.timeIntervalSince(distStart)
        }
        let effectiveCombatTime = totalElapsed - currentWasted
        return max(0, boss.maxHp - effectiveCombatTime)
    }

    private func resolveExplorationSummary(
        provided: FocusGroupSessionSummary?,
        at time: Date
    ) -> FocusGroupSessionSummary? {
        if let provided = provided {
            return provided
        }
        guard let boss = currentBoss, let payload = boss.focusGroupPayload else { return nil }
        let focusedSeconds: TimeInterval
        if boss.style == .passive {
            focusedSeconds = state == .victory ? boss.maxHp : 0
        } else {
            focusedSeconds = max(0, boss.maxHp - boss.currentHp)
        }
        let startTime = time.addingTimeInterval(-focusedSeconds)
        let coordinator = FocusGroupSessionCoordinator(
            memberTemplateIds: payload.memberTemplateIds,
            startTime: startTime,
            activeIndex: payload.activeIndex
        )
        return coordinator.endExploration(at: time)
    }
    // MARK: - Persistence
    
    public func snapshot() -> BattleSnapshot? {
        // We can always snapshot if we want to save history, even if no active boss
        // But for BattleSnapshot, it usually implies an active battle.
        // Let's modify it to be more robust.
        return BattleSnapshot(
            boss: currentBoss ?? Boss(name: "Idle", maxHp: 0),
            state: state,
            startTime: startTime ?? Date(),
            elapsedBeforeLastSave: elapsedBeforeCurrentSession,
            wastedTime: wastedTime,
            isImmune: isImmune,
            immunityCount: immunityCount,
            distractionStartTime: distractionStartTime,
            freezeTokensUsed: freezeTokensUsed,
            freezeHistory: freezeHistory,
            freezeStartTime: freezeStartTime,
            totalFocusedHistoryToday: totalFocusedHistoryToday,
            history: history,
            stamina: stamina,
            specimenCollection: specimenCollection
        )
    }
    
    public func restore(from snapshot: BattleSnapshot) {
        // If it was just an idle save, boss name will be "Idle"
        if snapshot.boss.name != "Idle" {
            self.currentBoss = snapshot.boss
        }
        self.state = snapshot.state
        self.elapsedBeforeCurrentSession = snapshot.elapsedBeforeLastSave
        self.startTime = snapshot.state == .fighting || snapshot.state == .resting ? snapshot.startTime : nil
        self.wastedTime = snapshot.wastedTime
        self.isImmune = snapshot.isImmune
        self.immunityCount = snapshot.immunityCount
        self.distractionStartTime = snapshot.distractionStartTime
        self.freezeTokensUsed = snapshot.freezeTokensUsed ?? 0
        self.freezeHistory = snapshot.freezeHistory ?? []
        self.freezeStartTime = snapshot.state == .frozen ? snapshot.freezeStartTime : nil
        self.totalFocusedHistoryToday = snapshot.totalFocusedHistoryToday ?? 0
        self.history = snapshot.history ?? []
        self.stamina = snapshot.stamina ?? StaminaSystem()
        self.specimenCollection = snapshot.specimenCollection ?? SpecimenCollection()
        
        print("[Engine] State Restored. History Count: \(history.count)")
    }
    
    public func reconcile(lastSeenAt: Date, now: Date = Date()) {
        guard state == .fighting else { return }
        
        let timeDead = now.timeIntervalSince(lastSeenAt)
        print("[Engine] App was dead for \(timeDead)s")
        
        if isImmune {
            print("[Engine] Immune during death. Time counts as Progress.")
            isImmune = false 
            print("[Engine] Immunity consumed on restore.")
        } else if timeDead < 30 {
            print("[Engine] Grace Period (<30s). Time counts as Progress/Ignored.")
            // Do not add to wastedTime. Effectively treats it as valid focus or neutral.
        } else if timeDead > 300 {
             print("[Engine] Absence > 5 mins. Auto-Ending session.")
             // If user left for too long, just end the session.
             // We don't want to accumulate massive shadow.
             retreat() // This sets endReason = .incompleteExit
             // Actually, incompleteExit might be better
        } else {
            print("[Engine] NOT Immune and > Grace Period but < 5 mins. Time counts as WASTED.")
            wastedTime += timeDead
        }
    }

    
    // MARK: - Live Activity Setup

    
    // Live Activity helper methods removed (moved to LiveActivityManager)
}
