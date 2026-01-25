import SwiftUI
import TimeLineCore
import Combine

struct PlanSheetView: View {
    @EnvironmentObject var timelineStore: TimelineStore
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var libraryStore: LibraryStore
    @EnvironmentObject var daySession: DaySession // Needed for logic
    @EnvironmentObject var engine: BattleEngine   // Needed for timeline placement
    @EnvironmentObject var stateManager: AppStateManager // Needed for draft persistence
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var viewModel = PlanViewModel()
    @State private var selectedFinishBy: FinishBySelection = .tonight // Default to first visible Habitat
    @State private var isKeyboardVisible = false
    
    // Feedback State
    @State private var showCommitSuccess = false
    @State private var commitMessage = ""
    @State private var showConflictAlert = false
    // No more local state needed for picker, logic moved to VM

    
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
                        
                        // 2. Today's Plan
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TODAY'S PLAN")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundColor(secondaryText)
                                .padding(.leading, 4)
                            
                            // Magic Input (Seed Tuner) still useful for quick entries
                            MagicInputBar(text: $viewModel.draftText, onCommit: {
                                viewModel.parseAndStage(finishBy: selectedFinishBy)
                            })
                            .padding(.horizontal)
                            
                            // Habitat Blocks (Time Slots)
                            // TODO: Create proper Habitat enum. Currently reusing FinishBySelection as grouping key.
                            // Visual Mapping: "Morning Clearing" → .tonight, "Deep Forest" → .tomorrow
                            
                            VStack(spacing: 16) {
                                ForEach(FinishBySelection.allCases.filter { $0 != .none }, id: \.self) { option in
                                    HabitatBlockView(
                                        title: habitatTitle(for: option),
                                        timeRange: habitatTimeRange(for: option),
                                        items: viewModel.stagedTemplates.filter { $0.finishBy == option },
                                        onDrop: { items in
                                            handleDrop(items: items, into: option)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // 3. Current Map (Reflects what's actually scheduled)
                        // Maybe show a mini-map or summary? 
                        // For now keep it focusing on "Planning" (Staging)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.vertical)
                }
                .scrollDismissesKeyboard(.interactively)
                
                // Commit Action (Launch Expedition)
                if !viewModel.stagedTemplates.isEmpty {
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
                                Text("Launch Expedition (\(viewModel.stagedTemplates.count) Specimens)")
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
        let count = viewModel.stagedTemplates.count
        let duration = viewModel.formattedTotalDuration
        
        viewModel.commitToTimeline(dismissAction: {})
        
        // Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        commitMessage = "Successfully planted \(count) seeds (\(duration)) into the timeline."
        showCommitSuccess = true
        
        // Auto dismiss after 1.5s if user doesn't tap OK
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if showCommitSuccess {
                 dismiss()
            }
        }
    }
    
    private func handleDrop(items: [String], into timeSlot: FinishBySelection) {
        guard let itemString = items.first else { return }
        if itemString.hasPrefix("TEMPLATE:") {
             let uuidString = String(itemString.dropFirst(9))
             if let templateId = UUID(uuidString: uuidString),
                let template = cardStore.get(id: templateId) {
                 viewModel.stageQuickAccessTask(template, finishBy: timeSlot)
             }
        }
    }

    // MARK: - Habitat Helpers
    
    private func habitatTitle(for option: FinishBySelection) -> String {
        switch option {
        case .tonight: return "Tonight"
        case .tomorrow: return "Tomorrow"
        case .next3Days: return "Next 3 Days"
        case .thisWeek: return "This Week"
        case .none: return "Backlog"
        case .pickDate(let date): 
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    private func habitatTimeRange(for option: FinishBySelection) -> String {
        switch option {
        case .tonight: return "Until 23:59"
        case .tomorrow: return "+24 Hours"
        case .next3Days: return "+3 Days"
        case .thisWeek: return "+7 Days"
        case .none: return "No Deadline"
        case .pickDate: return "Scheduled"
        }
    }
}

// MARK: - Supporting Views

struct DateChip: View {
    let option: FinishBySelection
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: option.iconName)
                Text(option.displayName)
            }
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue.opacity(0.6) : Color.white.opacity(0.1))
            )
            .foregroundStyle(isSelected ? .white : .white.opacity(0.8))
        }
    }
}

struct TaskGroupView: View {
    let group: TaskGroup
    let onDeleteTask: (UUID) -> Void
    let onUpdateFinishBy: (UUID, FinishBySelection) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForGroup(group.title))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Text(group.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("\(group.tasks.count)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            LazyVStack(spacing: 6) {
                ForEach(group.tasks) { stagedTask in
                    DraftTaskRow(
                        stagedTask: stagedTask,
                        onDelete: { onDeleteTask(stagedTask.id) },
                        onUpdateFinishBy: { finishBy in
                            onUpdateFinishBy(stagedTask.id, finishBy)
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity).animation(.spring(response: 0.3, dampingFraction: 0.7)),
                        removal: .opacity.animation(.easeOut(duration: 0.2))
                    ))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func iconForGroup(_ title: String) -> String {
        switch title {
        case "今晚": return "moon.stars.fill"
        case "明天": return "sun.max.fill"
        case "未来3天": return "calendar.badge.clock"
        case "本周内": return "calendar"
        case "无截止": return "infinity"
        default: return "calendar.circle"
        }
    }
}

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("选择截止日期")
                    .font(.headline)
                    .padding()
                
                DatePicker(
                    "截止日期",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Button("确定") {
                    onDateSelected(selectedDate)
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
                .padding()
                
                Spacer()
            }
            .navigationTitle("自定义日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Subviews

// QuickAccessChip struct removed - replaced by TaskMiniChip usage

struct DraftTaskRow: View {
    let stagedTask: StagedTask
    let onDelete: () -> Void
    let onUpdateFinishBy: (FinishBySelection) -> Void
    
    @State private var showFinishByPicker = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stagedTask.template.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                HStack(spacing: 8) {
                    Text(TimeFormatter.formatDuration(stagedTask.template.defaultDuration))
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.6))
                    
                    Button(action: { showFinishByPicker = true }) {
                        HStack(spacing: 2) {
                            Image(systemName: stagedTask.finishBy.iconName)
                            Text(stagedTask.finishBy.displayName)
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
                selectedFinishBy: stagedTask.finishBy,
                onSelection: onUpdateFinishBy
            )
        }
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
                                if selectedFinishBy == option {
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

// Button Style Helper (No changes needed, but ensuring it's here)
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
