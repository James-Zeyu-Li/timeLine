import SwiftUI
import Combine
import TimeLineCore

struct GroupFocusView: View {
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var coordinator: TimelineEventCoordinator
    @EnvironmentObject var stateManager: AppStateManager

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var showExitOptions = false
    @State private var activeIndex: Int = 0
    @State private var members: [GroupMember] = []
    @State private var nodeId: UUID?
    @State private var lastFocusedSeconds: TimeInterval = 0
    @State private var nextReminder: ReminderPreview?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                header

                memberList

                Spacer()

                HStack(spacing: 12) {
                    Button(action: { showExitOptions = true }) {
                        Text("完成今日探险")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.7))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            syncSession()
            lastFocusedSeconds = currentFocusedSeconds
            updateNextReminder(at: Date())
        }
        .onChange(of: daySession.currentNode?.id) { _, _ in
            syncSession()
            lastFocusedSeconds = currentFocusedSeconds
            updateNextReminder(at: Date())
        }
        .onReceive(timer) { input in
            engine.tick(at: input)
            let focused = currentFocusedSeconds
            let delta = max(0, focused - lastFocusedSeconds)
            if delta > 0 {
                coordinator.recordFocusProgress(seconds: delta)
                lastFocusedSeconds = focused
            }
            updateNextReminder(at: input)
        }
        .confirmationDialog(
            "完成今日探险？",
            isPresented: $showExitOptions,
            titleVisibility: .visible
        ) {
            Button("完成今日探险") {
                endExploration()
            }
            Button("Keep Focusing", role: .cancel) { }
        } message: {
            Text("完成后会记录本次探险。")
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("FOCUS GROUP")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundColor(.white.opacity(0.7))
            Text(focusedTimeText)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("Switch tasks anytime")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            if let reminderText = nextReminderText {
                Text(reminderText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.cyan.opacity(0.8))
            }
        }
        .padding(.top, 20)
    }

    private var memberList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tasks")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.7))
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                        GroupMemberRow(
                            template: member.template,
                            isActive: index == activeIndex,
                            onTap: { switchTo(index: index) }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 320)
        }
    }

    private var focusedTimeText: String {
        TimeFormatter.formatTimer(currentFocusedSeconds)
    }

    private var currentFocusedSeconds: TimeInterval {
        guard let boss = engine.currentBoss else { return 0 }
        return max(0, boss.maxHp - boss.currentHp)
    }

    private func syncSession() {
        guard let node = daySession.currentNode else { return }
        guard case .battle(let boss) = node.type,
              let payload = boss.focusGroupPayload else { return }
        nodeId = node.id
        members = payload.memberTemplateIds.map { id in
            GroupMember(id: id, template: cardStore.get(id: id))
        }
        let clampedIndex = min(max(0, payload.activeIndex), max(members.count - 1, 0))
        activeIndex = clampedIndex
        _ = coordinator.ensureFocusGroupSession(for: node)
    }

    private func switchTo(index: Int) {
        guard let nodeId else { return }
        let didSwitch = coordinator.switchFocusGroup(to: index, nodeId: nodeId, at: Date())
        if didSwitch {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                activeIndex = index
            }
        }
    }

    private func endExploration() {
        let summary = coordinator.endFocusGroupSession(at: Date())
        engine.endExploration(summary: summary, at: Date())
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

private struct GroupMemberRow: View {
    let template: CardTemplate?
    let isActive: Bool
    let onTap: () -> Void
    @State private var flipPhase = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: template?.icon ?? "questionmark.circle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(template?.title ?? "Missing Card")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if let template {
                        Text(TimeFormatter.formatDuration(template.defaultDuration))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                Spacer()
                if isActive {
                    Text("ACTIVE")
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? Color.cyan.opacity(0.15) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.cyan.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1)
            )
            .scaleEffect(flipPhase ? 1.02 : 1.0)
            .rotation3DEffect(.degrees(flipPhase ? 8 : 0), axis: (x: 0, y: 1, z: 0))
        }
        .buttonStyle(.plain)
        .onChange(of: isActive) { _, newValue in
            guard newValue else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                flipPhase = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    flipPhase = false
                }
            }
        }
    }
}

private struct GroupMember: Identifiable {
    let id: UUID
    let template: CardTemplate?
}
