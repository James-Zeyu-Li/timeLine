import SwiftUI
import Combine
import TimeLineCore

struct BattleView: View {
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var coordinator: TimelineEventCoordinator
    // Note: daySession.advance() is now handled by TimelineEventCoordinator
    // which listens to engine.$state changes
    
    // Timer to drive the UI updates (since engine needs explicit ticks)
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var showExitOptions = false
    @State private var lastFocusedSeconds: TimeInterval = 0
    @State private var nextReminder: ReminderPreview?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 动态背景渐变
                RadialGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.05, green: 0.05, blue: 0.1),
                        Color.black
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: geometry.size.width
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // 中央专注区域
                    ZStack {
                        // 背景环形装饰
                        ForEach(0..<3) { index in
                            Circle()
                                .stroke(
                                    Color.white.opacity(0.03 - Double(index) * 0.01),
                                    lineWidth: 1
                                )
                                .frame(
                                    width: 280 + CGFloat(index * 40),
                                    height: 280 + CGFloat(index * 40)
                                )
                                .scaleEffect(1 + sin(Date().timeIntervalSince1970 + Double(index)) * 0.02)
                                .animation(
                                    .easeInOut(duration: 3 + Double(index))
                                    .repeatForever(autoreverses: true),
                                    value: Date().timeIntervalSince1970
                                )
                        }
                        
                        if let boss = engine.currentBoss {
                            
                            if boss.style == .passive {
                                // --- 被动任务UI ---
                                VStack(spacing: 32) {
                                    VStack(spacing: 8) {
                                        Text("REMINDER")
                                            .font(.system(size: 12, weight: .bold))
                                            .tracking(3)
                                            .foregroundColor(.cyan.opacity(0.8))
                                        
                                        Text(boss.name.uppercased())
                                            .font(.system(.title, design: .rounded))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)
                                    }
                                    
                                    Button(action: {
                                        engine.completePassiveTask()
                                    }) {
                                        ZStack {
                                            // 外层光晕
                                            Circle()
                                                .fill(
                                                    RadialGradient(
                                                        colors: [Color.green.opacity(0.3), Color.green.opacity(0)],
                                                        center: .center,
                                                        startRadius: 0,
                                                        endRadius: 80
                                                    )
                                                )
                                                .frame(width: 160, height: 160)
                                            
                                            // 主按钮
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.green.opacity(0.3), Color.green.opacity(0.1)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 120, height: 120)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.green, lineWidth: 2)
                                                )
                                            
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 48, weight: .bold))
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .scaleEffect(1.0)
                                    .animation(.spring(response: 0.3), value: engine.state)
                                    
                                    Text("Tap when completed")
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundColor(.gray)
                                }
                            } else {
                                // --- 专注战斗UI ---
                                VStack(spacing: 24) {
                                    
                                    // 任务信息
                                    VStack(spacing: 8) {
                                        Text("FOCUS SESSION")
                                            .font(.system(size: 12, weight: .bold))
                                            .tracking(3)
                                            .foregroundColor(.red.opacity(0.8))
                                        
                                        Text(boss.name.uppercased())
                                            .font(.system(.title2, design: .rounded))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)

                                        if let reminderText = nextReminderText {
                                            Text(reminderText)
                                                .font(.system(.caption, design: .rounded))
                                                .foregroundColor(.cyan.opacity(0.8))
                                        }
                                    }
                                    
                                    // 主计时器区域
                                    ZStack {
                                        // HP环形进度条
                                        Circle()
                                            .stroke(Color.red.opacity(0.1), lineWidth: 12)
                                            .frame(width: 280, height: 280)
                                        
                                        Circle()
                                            .trim(from: 0, to: progress)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.red, .orange],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                            )
                                            .frame(width: 280, height: 280)
                                            .rotationEffect(.degrees(-90))
                                            .animation(.linear(duration: 1), value: progress)
                                        
                                        // 中央计时器
                                        VStack(spacing: 16) {
                                            Text(TimeFormatter.formatTimer(boss.maxHp - (boss.maxHp - boss.currentHp + engine.wastedTime)))
                                                .font(.system(size: 64, weight: .ultraLight, design: .monospaced))
                                                .foregroundColor(.white)
                                                .shadow(color: .red.opacity(0.3), radius: 20)
                                            
                                            // 浪费时间指示器
                                            if engine.wastedTime > 0 {
                                                HStack(spacing: 8) {
                                                    Circle()
                                                        .fill(Color.red)
                                                        .frame(width: 8, height: 8)
                                                        .scaleEffect(1.2)
                                                        .animation(
                                                            .easeInOut(duration: 0.8)
                                                            .repeatForever(autoreverses: true),
                                                            value: engine.wastedTime
                                                        )
                                                    
                                                    Text("WASTED: \(TimeFormatter.formatTimer(engine.wastedTime))")
                                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                        .foregroundColor(.red)
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.red.opacity(0.15))
                                                        .overlay(
                                                            Capsule()
                                                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                                        )
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 控制按钮区域（仅专注模式）
                    if let boss = engine.currentBoss, boss.style == .focus {
                        HStack(spacing: 50) {
                            // Freeze 按钮
                            Button(action: {
                                handleFreezeTap()
                            }) {
                                VStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(white: 0.1))
                                            .frame(width: 60, height: 60)
                                        
                                        Image(systemName: "snowflake")
                                            .font(.system(size: 20))
                                            .foregroundColor(.cyan)
                                    }
                                    
                                    Text("FREEZE \(engine.freezeTokensRemaining)")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1)
                                        .foregroundColor(.cyan)
                                }
                            }
                            .disabled(!canFreeze)
                            .opacity(canFreeze ? 1.0 : 0.3)
                            
                            // 撤退按钮
                            Button(action: {
                                handleRetreatTap()
                            }) {
                                VStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(white: 0.1))
                                            .frame(width: 60, height: 60)
                                        
                                        Image(systemName: "flag.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Text("RETREAT")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            // 免疫按钮
                            if engine.state == .fighting {
                                Button(action: { engine.grantImmunity() }) {
                                    VStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    engine.isImmune ? 
                                                        Color.blue.opacity(0.2) : 
                                                        Color(white: 0.1)
                                                )
                                                .frame(width: 80, height: 80)
                                                .overlay(
                                                    Circle()
                                                        .stroke(
                                                            engine.isImmune ? Color.blue : Color(white: 0.3),
                                                            lineWidth: 2
                                                        )
                                                )
                                            
                                            if engine.isImmune {
                                                Image(systemName: "shield.fill")
                                                    .font(.system(size: 28))
                                                    .foregroundColor(.blue)
                                            } else {
                                                Image(systemName: "iphone")
                                                    .font(.system(size: 28))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        
                                        Text(engine.isImmune ? "PROTECTED" : "USE PHONE")
                                            .font(.system(size: 10, weight: .bold))
                                            .tracking(1)
                                            .foregroundColor(engine.isImmune ? .blue : .white)
                                    }
                                }
                                .disabled(engine.immunityCount <= 0 && !engine.isImmune)
                                .opacity((engine.immunityCount <= 0 && !engine.isImmune) ? 0.3 : 1.0)
                            }
                        }
                        .padding(.bottom, 80)
                    } else {
                        Color.clear.frame(height: 160)
                    }
                }
                
                // 调试跳过按钮
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            engine.forceCompleteTask()
                        }) {
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.gray.opacity(0.4))
                                .padding(16)
                        }
                    }
                    Spacer()
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onReceive(timer) { input in
            engine.tick(at: input)
            let focused = currentFocusedSeconds
            let delta = max(0, focused - lastFocusedSeconds)
            if delta > 0 {
                coordinator.recordFocusProgress(seconds: delta)
                lastFocusedSeconds = focused
            }
            updateNextReminder(at: input)
            // Note: Victory/retreat handling moved to TimelineEventCoordinator
        }
        .onAppear {
            lastFocusedSeconds = currentFocusedSeconds
            updateNextReminder(at: Date())
        }
        .onChange(of: engine.currentBoss?.id) { _, _ in
            lastFocusedSeconds = currentFocusedSeconds
            updateNextReminder(at: Date())
        }
        .confirmationDialog(
            exitDialogTitle,
            isPresented: $showExitOptions,
            titleVisibility: .visible
        ) {
            if exitOptions.contains(.undoStart) {
                Button("Undo Start") {
                    exitController.handle(.undoStart, taskMode: currentTaskMode)
                }
            }
            Button(endAndRecordLabel) {
                exitController.handle(.endAndRecord, taskMode: currentTaskMode)
            }
            Button("Keep Focusing", role: .cancel) {
                exitController.handle(.keepFocusing, taskMode: currentTaskMode)
            }
        } message: {
            Text(exitDialogMessage)
        }
    }
    
    var progress: CGFloat {
        guard let boss = engine.currentBoss else { return 0 }
        return CGFloat(boss.currentHp / boss.maxHp)
    }

    private var currentFocusedSeconds: TimeInterval {
        guard let boss = engine.currentBoss else { return 0 }
        return max(0, boss.maxHp - boss.currentHp)
    }

    private var currentTaskMode: TaskMode {
        guard let node = daySession.currentNode else { return .focusStrictFixed }
        return node.effectiveTaskMode { id in
            cardStore.get(id: id)
        }
    }

    private var exitOptions: [BattleExitOption] {
        BattleExitPolicy.options(
            elapsedSeconds: engine.currentSessionElapsed(),
            taskMode: currentTaskMode
        )
    }

    private var exitController: BattleExitController {
        BattleExitController(engine: engine, stateSaver: stateManager)
    }

    private var canFreeze: Bool {
        guard engine.state == .fighting, let boss = engine.currentBoss, boss.style == .focus else { return false }
        return engine.freezeTokensRemaining > 0
    }
    
    private var exitDialogTitle: String {
        switch currentTaskMode {
        case .focusGroupFlexible:
            return "End exploring?"
        case .focusStrictFixed, .reminderOnly:
            return "Exit session?"
        }
    }
    
    private var exitDialogMessage: String {
        switch currentTaskMode {
        case .focusGroupFlexible:
            return "End exploring will record this session."
        case .focusStrictFixed:
            return "Undo Start is only available within 60 seconds. Otherwise, exit will be recorded as incomplete."
        case .reminderOnly:
            return "Exit will be recorded as incomplete."
        }
    }
    
    private var endAndRecordLabel: String {
        switch currentTaskMode {
        case .focusGroupFlexible:
            return "End Exploring"
        case .focusStrictFixed, .reminderOnly:
            return "End & Record"
        }
    }

    private func handleRetreatTap() {
        switch currentTaskMode {
        case .focusGroupFlexible, .focusStrictFixed:
            showExitOptions = true
        case .reminderOnly:
            engine.retreat()
        }
    }

    private func handleFreezeTap() {
        if engine.freeze() {
            stateManager.requestSave()
            Haptics.impact(.medium)
        } else {
            Haptics.impact(.light)
        }
    }

    private var nextReminderText: String? {
        guard let nextReminder else { return nil }
        guard let remaining = CountdownFormatter.formatRemaining(seconds: nextReminder.remainingSeconds) else { return nil }
        return "距离 \(nextReminder.taskName) 还有 \(remaining)"
    }

    private func updateNextReminder(at date: Date) {
        guard coordinator.pendingReminder == nil else {
            nextReminder = nil
            return
        }
        nextReminder = ReminderScheduler.nextUpcoming(nodes: daySession.nodes, at: date)
    }
}
