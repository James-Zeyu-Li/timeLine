import Foundation
import TimeLineCore

enum BattleExitOption: Equatable {
    case undoStart
    case endAndRecord
    case keepFocusing
}

struct BattleExitPolicy {
    static let undoStartWindow: TimeInterval = 60
    
    static func allowsUndoStart(elapsedSeconds: TimeInterval?) -> Bool {
        guard let elapsed = elapsedSeconds else { return false }
        return elapsed <= undoStartWindow
    }
    
    static func options(elapsedSeconds: TimeInterval?, taskMode: TaskMode) -> [BattleExitOption] {
        var options: [BattleExitOption] = []
        // Treat dungeonRaid same as focusGroupFlexible (no simple undo start)
        if taskMode != .focusGroupFlexible && taskMode.id != "dungeonRaid", allowsUndoStart(elapsedSeconds: elapsedSeconds) {
            options.append(.undoStart)
        }
        options.append(.endAndRecord)
        options.append(.keepFocusing)
        return options
    }
}

@MainActor
struct BattleExitController {
    let engine: BattleEngine
    let stateSaver: StateSaver
    
    func handle(
        _ option: BattleExitOption,
        taskMode: TaskMode,
        focusGroupSummary: FocusGroupSessionSummary? = nil
    ) {
        switch option {
        case .undoStart:
            engine.abortSession()
            stateSaver.requestSave()
        case .endAndRecord:
            if taskMode == .focusGroupFlexible || taskMode.id == "dungeonRaid" {
                engine.endExploration(summary: focusGroupSummary)
            } else {
                engine.retreat()
            }
        case .keepFocusing:
            break
        }
    }
}
