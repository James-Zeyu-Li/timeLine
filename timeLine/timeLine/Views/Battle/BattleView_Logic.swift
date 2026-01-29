import SwiftUI
import Foundation
import TimeLineCore

extension BattleView {
    var progress: CGFloat {
        guard let boss = engine.currentBoss else { return 0 }
        return CGFloat(boss.currentHp / boss.maxHp)
    }

    var currentFocusedSeconds: TimeInterval {
        guard let boss = engine.currentBoss else { return 0 }
        return max(0, boss.maxHp - boss.currentHp)
    }

    var currentTaskMode: TaskMode {
        guard let node = daySession.currentNode else { return .focusStrictFixed }
        return node.effectiveTaskMode { id in
            cardStore.get(id: id)
        }
    }
    
    // MARK: - Dual Mode Timer Properties
    
    /// Whether this is a flexible mode (stopwatch) or strict mode (countdown)
    var isFlexibleMode: Bool {
        switch currentTaskMode {
        case .focusGroupFlexible:
            return true
        case .focusStrictFixed, .reminderOnly:
            return false
        }
    }
    
    /// Ring progress: Strict mode uses boss HP ratio, Flexible uses 50min target
    var ringProgress: CGFloat {
        guard let boss = engine.currentBoss else { return 0 }
        if isFlexibleMode {
            // Flexible: Progress towards 50 minutes (3000s)
            return min(1.0, CGFloat(engine.currentSessionElapsed()) / 3000.0)
        } else {
            // Strict: Countdown progress (remaining / max)
            return CGFloat(boss.currentHp / boss.maxHp)
        }
    }
    
    /// Ring colors: Cyan for flexible, Red-Orange for strict countdown
    var ringColors: [Color] {
        isFlexibleMode ? [.blue, .cyan] : [.red, .orange]
    }
    
    /// Ring background color
    var ringBackgroundColor: Color {
        isFlexibleMode ? .white : .red
    }
    
    /// Timer label text
    var timerLabel: String {
        isFlexibleMode ? "OBSERVED" : "REMAINING"
    }
    
    /// Timer label color
    var timerLabelColor: Color {
        isFlexibleMode ? .cyan : .red
    }
    
    /// Timer display: Flexible shows elapsed, Strict shows remaining
    var timerDisplay: String {
        guard let boss = engine.currentBoss else { return "00:00" }
        if isFlexibleMode {
            return TimeFormatter.formatTimer(engine.currentSessionElapsed())
        } else {
            // Remaining time = currentHp (which decreases as time passes)
            let remaining = max(0, boss.currentHp - engine.wastedTime)
            return TimeFormatter.formatTimer(remaining)
        }
    }

    var exitOptions: [BattleExitOption] {
        BattleExitPolicy.options(
            elapsedSeconds: engine.currentSessionElapsed(),
            taskMode: currentTaskMode
        )
    }

    var exitController: BattleExitController {
        BattleExitController(engine: engine, stateSaver: stateManager)
    }

    var canFreeze: Bool {
        guard engine.state == .fighting, let boss = engine.currentBoss, boss.style == .focus else { return false }
        return engine.freezeTokensRemaining > 0
    }
    
    var exitDialogTitle: String {
        switch currentTaskMode {
        case .focusGroupFlexible:
            return "End exploring?"
        case .focusStrictFixed, .reminderOnly:
            return "Exit session?"
        }
    }
    
    var exitDialogMessage: String {
        switch currentTaskMode {
        case .focusGroupFlexible:
            return "End exploring will record this session."
        case .focusStrictFixed:
            return "Undo Start is only available within 60 seconds. Otherwise, exit will be recorded as incomplete."
        case .reminderOnly:
            return "Exit will be recorded as incomplete."
        }
    }
    
    var endAndRecordLabel: String {
        switch currentTaskMode {
        case .focusGroupFlexible:
            return "End Exploring"
        case .focusStrictFixed, .reminderOnly:
            return "End & Record"
        }
    }

    func handleRetreatTap() {
        switch currentTaskMode {
        case .focusGroupFlexible, .focusStrictFixed:
            showExitOptions = true
        case .reminderOnly:
            engine.retreat()
        }
    }

    func handleFreezeTap() {
        if engine.freeze() {
            stateManager.requestSave()
            Haptics.impact(.medium)
        } else {
            Haptics.impact(.light)
        }
    }

    var nextReminderText: String? {
        guard let nextReminder else { return nil }
        guard let remaining = CountdownFormatter.formatRemaining(seconds: nextReminder.remainingSeconds) else { return nil }
        return "距离 \(nextReminder.taskName) 还有 \(remaining)"
    }

    func updateNextReminder(at date: Date) {
        guard coordinator.pendingReminder == nil else {
            nextReminder = nil
            return
        }
        nextReminder = ReminderScheduler.nextUpcoming(nodes: daySession.nodes, at: date)
    }
}
