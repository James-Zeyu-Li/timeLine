import SwiftUI
import TimeLineCore
import Combine

struct PlanSheetView: View {
    @EnvironmentObject var timelineStore: TimelineStore
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var libraryStore: LibraryStore
    @EnvironmentObject var daySession: DaySession // Needed for logic
    @EnvironmentObject var engine: BattleEngine   // Needed for timeline placement
    @EnvironmentObject var stateManager: AppStateManager // Needed for persistence
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var viewModel = PlanViewModel()
    @State private var selectedFinishBy: FinishBySelection = .tonight
    @State private var isKeyboardVisible = false
    
    // Feedback State
    @State private var showCommitSuccess = false
    @State private var commitMessage = ""
    @State private var showConflictAlert = false
    
    // Theme Colors (Dark Translucent)
    private let bgGradient = LinearGradient(
        colors: [Color.black.opacity(0.85), Color.black.opacity(0.95)],
        startPoint: .top,
        endPoint: .bottom
    )
    private let primaryText = Color.white.opacity(0.9)
    private let secondaryText = Color.white.opacity(0.6)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !isKeyboardVisible {
                    // Header
                    HStack {
                        Text("Expedition Log")
                            .font(.title2)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundColor(primaryText)
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                    }
                    .padding()
                } else {
                     // Collapsed Header
                     HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                             Image(systemName: "chevron.down")
                                 .font(.system(size: 20, weight: .bold))
                                 .foregroundStyle(Color.white.opacity(0.3))
                        }
                     }
                     .padding(.top, 12)
                     .padding(.trailing)
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // 1. Task Library
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TASK LIBRARY")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundColor(secondaryText)
                                .padding(.leading, 4)
                            
                            ResearchLogDrawer()
                        }
                        .padding(.horizontal)
                        
                        // 2. Today's Plan (Inbox)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("INBOX / DRAFT AREA")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundColor(secondaryText)
                                .padding(.leading, 4)
                            
                            // Magic Input
                            MagicInputBar(text: $viewModel.draftText, onCommit: {
                                viewModel.parseAndAdd(finishBy: selectedFinishBy)
                            })
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                            
                            // Inbox List (Direct from TimelineStore)
                            if timelineStore.inbox.isEmpty {
                                Text("No pending quests.")
                                    .font(.caption)
                                    .foregroundStyle(secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 20)
                            } else {
                                PlanInboxListView(
                                    inboxNodes: timelineStore.inbox,
                                    cardStore: cardStore,
                                    onDelete: { id in
                                        viewModel.deleteInboxItem(id: id)
                                    },
                                    onUpdateFinishBy: { id, finishBy in
                                        viewModel.updateTaskDeadline(nodeId: id, finishBy: finishBy)
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                        
                        // 3. Current Map (Reflects what's actually scheduled)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.vertical)
                }
                .scrollDismissesKeyboard(.interactively)
                
                // Commit Action (Launch Expedition)
                if !timelineStore.inbox.isEmpty {
                    VStack {
                        Divider().overlay(Color.white.opacity(0.1))
                        Button(action: {
                            if engine.state == .fighting || engine.state == .paused {
                                showConflictAlert = true
                            } else {
                                commitAndFeedback()
                            }
                        }) {
                            HStack {
                                Image(systemName: "safari.fill") // Compass/Safari icon
                                Text("Launch Expedition (\(timelineStore.inbox.count) Specimens)")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.8))
                            .foregroundStyle(.white)
                            .cornerRadius(16)
                            .padding()
                        }
                        .alert("Expedition Launched", isPresented: $showCommitSuccess) {
                            Button("OK") { dismiss() }
                        } message: {
                            Text(commitMessage)
                        }
                        .alert("Focus in Progress", isPresented: $showConflictAlert) {
                            Button("Add to Queue") {
                                commitAndFeedback()
                            }
                            Button("Cancel", role: .cancel) { }
                        } message: {
                             Text("An expedition is already in progress. Add these tasks to the end of the queue?")
                        }
                    }
                    .background(.ultraThinMaterial)
                }
            }
            .background(bgGradient)
            .scrollContentBackground(.hidden)
            .onAppear {
                viewModel.configure(
                    timelineStore: timelineStore,
                    cardStore: cardStore,
                    daySession: daySession,
                    engine: engine,
                    stateManager: stateManager
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.spring()) { isKeyboardVisible = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.spring()) { isKeyboardVisible = false }
            }
        }
        .presentationDetents([.fraction(0.9)])
        .presentationCornerRadius(24)
        .presentationBackground(.clear)
    }
    
    private func commitAndFeedback() {
        let count = timelineStore.inbox.count
        
        viewModel.launchExpedition(dismissAction: {})
        
        // Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        commitMessage = "Successfully planted \(count) seeds into the timeline."
        showCommitSuccess = true
        
        // Auto dismiss after 1.5s if user doesn't tap OK
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if showCommitSuccess {
                 dismiss()
            }
        }
    }
    
    private func handleDrop(items: [String], into timeSlot: FinishBySelection) {
        viewModel.handleDrop(items: items, into: timeSlot)
    }
}

// MARK: - Supporting Views

struct PlanInboxListView: View {
    let inboxNodes: [TimelineNode]
    let cardStore: CardTemplateStore
    let onDelete: (UUID) -> Void
    let onUpdateFinishBy: (UUID, FinishBySelection) -> Void
    
    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(inboxNodes) { node in
                if case .battle(let boss) = node.type,
                   let templateId = boss.templateId,
                   let template = cardStore.get(id: templateId) {
                    
                    PlanInboxTaskRow(
                        node: node,
                        template: template,
                        onDelete: { onDelete(node.id) },
                        onUpdateFinishBy: { fb in onUpdateFinishBy(node.id, fb) }
                    )
                    .transition(.opacity)
                }
            }
        }
    }
}

struct PlanInboxTaskRow: View {
    let node: TimelineNode
    let template: CardTemplate
    let onDelete: () -> Void
    let onUpdateFinishBy: (FinishBySelection) -> Void
    
    @State private var showFinishByPicker = false
    
    // Helper to determine current FinishBy selection from template.deadlineAt
    private var currentFinishBy: FinishBySelection {
        if let d = template.deadlineAt {
             // Heuristic to match back to enum if necessary, or just display date
             // For simplify, we default to showing 'Scheduled' or 'None'
             return .pickDate(d)
        }
        return .none
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(template.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                HStack(spacing: 8) {
                    Text(TimeFormatter.formatDuration(template.defaultDuration))
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.6))
                    
                    Button(action: { showFinishByPicker = true }) {
                        HStack(spacing: 2) {
                            if let deadline = template.deadlineAt {
                                Image(systemName: "calendar")
                                Text(deadlineIsToday(deadline) ? "Tonight" : "Scheduled")
                            } else {
                                Image(systemName: "infinity")
                                Text("No Deadline")
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue.opacity(0.2)))
                        .foregroundStyle(Color.blue.opacity(0.8))
                    }
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(.red.opacity(0.7))
                    .padding(8)
                    .background(Circle().fill(.red.opacity(0.1)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
        .sheet(isPresented: $showFinishByPicker) {
            FinishByPickerSheet(
                selectedFinishBy: currentFinishBy,
                onSelection: onUpdateFinishBy
            )
        }
    }
    
    private func deadlineIsToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}


struct FinishByPickerSheet: View {
    let selectedFinishBy: FinishBySelection
    let onSelection: (FinishBySelection) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var customDate = Date()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("设置截止时间")
                    .font(.headline)
                    .padding()
                
                VStack(spacing: 12) {
                    ForEach(FinishBySelection.allCases, id: \.displayName) { option in
                        Button(action: {
                            onSelection(option)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: option.iconName)
                                    .frame(width: 20)
                                Text(option.displayName)
                                Spacer()
                                // Simple check not robust for .pickDate, but sufficient for UI selection
                                if option.displayName == selectedFinishBy.displayName { 
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                            )
                        }
                        .foregroundStyle(.primary)
                    }
                }
                .padding()
                
                Divider()
                
                VStack(spacing: 12) {
                    Text("自定义日期")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    DatePicker(
                        "选择日期",
                        selection: $customDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    
                    Button("设置自定义日期") {
                        onSelection(.pickDate(customDate))
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(8)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("截止时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// Button Style Helper
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ScaleButtonStyle {
    static var scale: ScaleButtonStyle { ScaleButtonStyle() }
}
