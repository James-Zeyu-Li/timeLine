import SwiftUI
import TimeLineCore

struct PlanSheetView: View {
    @EnvironmentObject var timelineStore: TimelineStore
    @EnvironmentObject var cardStore: CardTemplateStore
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var viewModel = PlanViewModel()
    @State private var selectedFinishBy: FinishBySelection = .next3Days
    @State private var showDatePicker = false
    @State private var customDate = Date()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Text("Plan Your Journey")
                        .font(.title2)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.gray.opacity(0.5))
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // MARK: - Magic Input
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Add")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                MagicInputBar(text: $viewModel.draftText, onCommit: {
                                    viewModel.parseAndStage(finishBy: selectedFinishBy)
                                })
                                .padding(.horizontal)
                                
                                // Date Selection
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(FinishBySelection.allCases, id: \.displayName) { option in
                                            DateChip(
                                                option: option,
                                                isSelected: selectedFinishBy == option,
                                                action: { selectedFinishBy = option }
                                            )
                                        }
                                        
                                        Button(action: { showDatePicker = true }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "calendar.circle")
                                                Text("自定义")
                                            }
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(Color(uiColor: .tertiarySystemBackground))
                                            )
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        // MARK: - Quick Access
                        if !viewModel.recentTasks.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recent Scrolls")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(viewModel.recentTasks) { template in
                                            QuickAccessChip(template: template) {
                                                viewModel.stageQuickAccessTask(template, finishBy: selectedFinishBy)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        // MARK: - Grouped Tasks
                        if !viewModel.groupedTasks.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Planned Tasks")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("\(viewModel.stagedTemplates.count) items ready")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal)
                                
                                ForEach(viewModel.groupedTasks) { group in
                                    TaskGroupView(
                                        group: group,
                                        onDeleteTask: { taskId in
                                            viewModel.removeStagedTask(id: taskId)
                                        },
                                        onUpdateFinishBy: { taskId, finishBy in
                                            viewModel.updateTaskFinishBy(id: taskId, finishBy: finishBy)
                                        }
                                    )
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.vertical)
                }
                .scrollDismissesKeyboard(.interactively)
                
                // MARK: - Footer (Commit)
                if !viewModel.stagedTemplates.isEmpty {
                    VStack {
                        Divider()
                        Button(action: {
                            viewModel.commitToTimeline(dismissAction: { dismiss() })
                        }) {
                            HStack {
                                Image(systemName: "map.fill")
                                Text("Add \(viewModel.stagedTemplates.count) Tasks to Map")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .cornerRadius(16)
                            .padding()
                        }
                    }
                    .background(.ultraThinMaterial)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                viewModel.configure(timelineStore: timelineStore, cardStore: cardStore)
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $customDate) { date in
                    selectedFinishBy = .pickDate(date)
                }
            }
        }
        .presentationDetents([.fraction(0.85)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
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
                    .fill(isSelected ? Color.accentColor : Color(uiColor: .tertiarySystemBackground))
            )
            .foregroundStyle(isSelected ? .white : .primary)
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
                    .foregroundStyle(.secondary)
                Text(group.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(group.tasks.count)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.secondary.opacity(0.2)))
                    .foregroundStyle(.secondary)
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
                .fill(Color(uiColor: .secondarySystemBackground).opacity(0.5))
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
                .background(Color.accentColor)
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

struct QuickAccessChip: View {
    let template: CardTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Use first char of title as icon for now if no icon logic
                Text(String(template.title.prefix(1)))
                    .font(.caption)
                    .fontWeight(.black)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.orange)) // ToDo: Theme color
                
                Text(template.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(TimeFormatter.formatDuration(template.defaultDuration))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(.scale)
    }
}

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
                
                HStack(spacing: 8) {
                    Text(TimeFormatter.formatDuration(stagedTask.template.defaultDuration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button(action: { showFinishByPicker = true }) {
                        HStack(spacing: 2) {
                            Image(systemName: stagedTask.finishBy.iconName)
                            Text(stagedTask.finishBy.displayName)
                        }
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.blue.opacity(0.1)))
                        .foregroundStyle(.blue)
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
                .fill(Color(uiColor: .tertiarySystemBackground))
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
