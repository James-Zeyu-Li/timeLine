import Foundation
import Combine


public class BattleEngine: ObservableObject {
    @Published public var state: BattleState = .idle
    @Published public var currentBoss: Boss?
    
    // Internal state for time tracking
    private var startTime: Date?
    private var elapsedBeforeCurrentSession: TimeInterval = 0
    
    // Phase 4: Distraction Logic
    @Published public var isImmune: Bool = false
    @Published public var immunityCount: Int = 1
    @Published public var wastedTime: TimeInterval = 0
    
    // Total focused time recorded in previous sessions of the day
    @Published public var totalFocusedHistoryToday: TimeInterval = 0
    
    // Long-term history
    @Published public var history: [DailyFunctionality] = []
    
    public var totalFocusedToday: TimeInterval {
        var total = totalFocusedHistoryToday
        // Only add active session progress if we are currently fighting
        if state == .fighting, let boss = currentBoss {
            let currentFocused = boss.maxHp - boss.currentHp
            total += currentFocused
        }
        return total
    }
    
    // Track when we went into background to calculate wasted time
    private var distractionStartTime: Date?
    
    // Idempotent guard for finalizeSession
    private var hasFinalized = false
    
    public init() {}
    
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
        print("[Engine] Battle Started: \(boss.name) at \(time)")
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
    
    public func retreat() {
        self.state = .retreat
        self.startTime = nil
        print("[Engine] Retreat")
    }
    
    public func startRest() {
        self.state = .resting
        print("[Engine] Resting at Bonfire")
    }
    
    public func endRest() {
        self.state = .idle
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
                wastedTime += distractedDuration
                distractionStartTime = nil
                print("[Engine] Foregrounded. Wasted: \(distractedDuration)s. Total Wasted: \(wastedTime)s")
            }
        }
    }
    
    /// Updates the engine state based on the current time.
    /// Should be called periodically (e.g. from a Timer).
    public func tick(at time: Date = Date()) {
        guard state == .fighting, let boss = currentBoss, let start = startTime else { return }
        
        // Passive Task Logic: Time passes but no damage/fail conditions
        if boss.style == .passive {
             // For passive tasks, we simply track time elapsed if we want, 
             // but we do NOT tick down HP or fail on time out in the same strict way.
             // Actually, "Total Time" usually increases for Passive/Stopwatch style?
             // But for Timeline consistency, let's keep the MaxHP as the "Allocated Time".
             // We just won't AUTO-FAIL.
             return
        }
        
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
        
        if totalElapsed >= boss.maxHp {
             // Time Over!
             if newHp <= 0 {
                 // Clean win
                 self.state = .victory
                 print("[Engine] Victory!")
             } else {
                 // Time ran out but Boss alive (Too much wasted time)
                 // Treat as Retreat/Defeat for now? Or just Stop?
                 self.state = .retreat // Let's call it retreat for now as "Failed"
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
        
        // Update boss model
        var updatedBoss = boss
        updatedBoss.currentHp = newHp
        self.currentBoss = updatedBoss
        
        // If session just ended, record the progress
        if state == .victory || state == .retreat {
            finalizeSession()
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
        // For passive tasks, assume full duration was focused if completed, or 0?
        // Let's award full duration for consistency in stats.
        let focusedThisSession: TimeInterval
        if boss.style == .passive {
             focusedThisSession = state == .victory ? boss.maxHp : 0
        } else {
             focusedThisSession = max(0, boss.maxHp - boss.currentHp)
        }
        
        totalFocusedHistoryToday += focusedThisSession
        
        // Update long-term history
        let sessionStats = DailyFunctionality(
            date: Date(),
            totalFocusedTime: focusedThisSession,
            totalWastedTime: wastedTime, // Wasted time might be relevant even for Passive if we tracked it? For now 0 is fine if we skip logic.
            sessionsCount: 1
        )
        self.history = StatsAggregator.updateHistory(history: self.history, session: sessionStats)
        
        // Clear current boss to prevent double-finalizing if tick is called again
        self.currentBoss = nil 
        print("[Engine] Session Finalized. Added \(focusedThisSession)s to daily total. History now has \(history.count) days.")
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
            totalFocusedHistoryToday: totalFocusedHistoryToday,
            history: history
        )
    }
    
    public func restore(from snapshot: BattleSnapshot) {
        // If it was just an idle save, boss name will be "Idle"
        if snapshot.boss.name != "Idle" {
            self.currentBoss = snapshot.boss
        }
        self.state = snapshot.state
        self.elapsedBeforeCurrentSession = snapshot.elapsedBeforeLastSave
        self.startTime = snapshot.startTime
        self.wastedTime = snapshot.wastedTime
        self.isImmune = snapshot.isImmune
        self.immunityCount = snapshot.immunityCount
        self.distractionStartTime = snapshot.distractionStartTime
        self.totalFocusedHistoryToday = snapshot.totalFocusedHistoryToday ?? 0
        self.history = snapshot.history ?? []
        
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
        } else {
            print("[Engine] NOT Immune. Time counts as WASTED.")
            wastedTime += timeDead
        }
    }
}
