import SwiftUI
import TimeLineCore


struct TaskSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var libraryStore: LibraryStore
    @Binding var templateToEdit: CardTemplate?
    
    // Node Editing Mode
    var isEditingNode: Bool = false
    var onSaveNode: ((CardTemplate) -> Void)? = nil
    
    @State private var draft = TaskDraft.default
    @State private var didLoad = false
    
    enum RepeatType: String, CaseIterable, Identifiable {
        case none = "None"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        
        var id: String { rawValue }
    }
    
    private struct TaskDraft: Equatable {
        var title: String
        var selectedCategory: TaskCategory
        var taskMode: TaskMode
        var duration: TimeInterval
        var reminderTime: Date
        var leadTimeMinutes: Int
        var repeatType: RepeatType
        var selectedWeekdays: Set<Int>
        var deadlineWindowDays: Int?
        
        static let `default` = TaskDraft(
            title: "",
            selectedCategory: .work,
            taskMode: .focusStrictFixed,
            duration: 1800,
            reminderTime: Date().addingTimeInterval(3600),
            leadTimeMinutes: 0,
            repeatType: .none,
            selectedWeekdays: [],
            deadlineWindowDays: nil
        )
        
        static func fromTemplate(_ template: CardTemplate) -> TaskDraft {
            var draft = TaskDraft.default
            draft.title = template.title
            draft.selectedCategory = template.category
            draft.taskMode = template.taskMode
            draft.duration = template.defaultDuration
            draft.reminderTime = template.remindAt ?? draft.reminderTime
            draft.leadTimeMinutes = template.leadTimeMinutes
            switch template.repeatRule {
            case .none:
                draft.repeatType = .none
                draft.selectedWeekdays = []
            case .daily:
                draft.repeatType = .daily
                draft.selectedWeekdays = []
            case .weekly(let days):
                draft.repeatType = .weekly
                draft.selectedWeekdays = days
            case .monthly(let days):
                draft.repeatType = .monthly
                draft.selectedWeekdays = days
            }
            draft.deadlineWindowDays = template.deadlineWindowDays
            return draft
        }
    }
    
    // Presets
    let durationPresets: [(String, TimeInterval)] = [
        ("15m", 900), ("25m", 1500), ("30m", 1800),
        ("45m", 2700),
        ("1h", 3600), ("90m", 5400), ("2h", 7200)
    ]
    let leadTimePresets: [Int] = [0, 5, 10, 30, 60]
    let deadlineOptions: [Int?] = [nil, 1, 3, 5, 7]
    
    var body: some View {
        NavigationView {
            ZStack {
                // 深色背景
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // 标题和分类区域
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Task Name")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                TextField("What needs to be done?", text: $draft.title)
                                    .font(.system(.title3, design: .rounded))
                                    .padding(16)
                                    .background(Color(white: 0.1))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .accessibilityIdentifier("taskSheetTitleField")
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Category")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                                    ForEach(TaskCategory.allCases, id: \.self) { category in
                                        Button(action: {
                                            draft.selectedCategory = category
                                        }) {
                                            VStack(spacing: 8) {
                                                Image(systemName: category.icon)
                                                    .font(.system(size: 24))
                                                    .foregroundColor(draft.selectedCategory == category ? .white : category.color)
                                                
                                                Text(category.rawValue.capitalized)
                                                    .font(.system(.caption, design: .rounded))
                                                    .fontWeight(.medium)
                                                    .foregroundColor(draft.selectedCategory == category ? .white : .gray)
                                            }
                                            .frame(height: 80)
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                draft.selectedCategory == category ?
                                                    LinearGradient(
                                                        colors: [category.color, category.color.opacity(0.7)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ) :
                                                    LinearGradient(colors: [Color(white: 0.1)], startPoint: .top, endPoint: .bottom)
                                            )
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(
                                                        draft.selectedCategory == category ? category.color : Color(white: 0.2),
                                                        lineWidth: draft.selectedCategory == category ? 2 : 1
                                                    )
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Task Mode
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Task Mode")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                                ForEach(taskModeOptions, id: \.rawValue) { mode in
                                    Button(action: {
                                        draft.taskMode = mode
                                    }) {
                                        Text(taskModeLabel(mode))
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(draft.taskMode == mode ? .bold : .medium)
                                            .foregroundColor(draft.taskMode == mode ? .white : .gray)
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                            .background(
                                                draft.taskMode == mode
                                                ? taskModeTint(mode).opacity(0.35)
                                                : Color(white: 0.1)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(
                                                        draft.taskMode == mode ? taskModeTint(mode) : Color(white: 0.2),
                                                        lineWidth: draft.taskMode == mode ? 2 : 1
                                                    )
                                            )
                                            .cornerRadius(10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        if draft.taskMode == .reminderOnly {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Remind At")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                DatePicker(
                                    "Time",
                                    selection: $draft.reminderTime,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(.orange)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Lead Time")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                                    ForEach(leadTimePresets, id: \.self) { minutes in
                                        Button(action: {
                                            draft.leadTimeMinutes = minutes
                                        }) {
                                            Text(leadTimeLabel(minutes))
                                                .font(.system(.subheadline, design: .rounded))
                                                .fontWeight(draft.leadTimeMinutes == minutes ? .bold : .medium)
                                                .foregroundColor(draft.leadTimeMinutes == minutes ? .white : .gray)
                                                .frame(height: 44)
                                                .frame(maxWidth: .infinity)
                                                .background(
                                                    draft.leadTimeMinutes == minutes ?
                                                        LinearGradient(colors: [.orange, .orange.opacity(0.7)], startPoint: .top, endPoint: .bottom) :
                                                        LinearGradient(colors: [Color(white: 0.1)], startPoint: .top, endPoint: .bottom)
                                                )
                                                .cornerRadius(8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(draft.leadTimeMinutes == minutes ? .orange : Color(white: 0.2), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                            }
                        }

                        if draft.taskMode != .reminderOnly {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Duration")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                                    ForEach(durationPresets, id: \.0) { (label, value) in
                                        Button(action: {
                                            draft.duration = value
                                        }) {
                                            Text(label)
                                                .font(.system(.subheadline, design: .monospaced))
                                                .fontWeight(draft.duration == value ? .bold : .medium)
                                                .foregroundColor(draft.duration == value ? .white : .gray)
                                                .frame(height: 44)
                                                .frame(maxWidth: .infinity)
                                                .background(
                                                    draft.duration == value ?
                                                        LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .top, endPoint: .bottom) :
                                                        LinearGradient(colors: [Color(white: 0.1)], startPoint: .top, endPoint: .bottom)
                                                )
                                                .cornerRadius(8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(draft.duration == value ? .green : Color(white: 0.2), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Complete Within")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 8) {
                                    ForEach(deadlineOptions, id: \.self) { option in
                                        Button(action: {
                                            draft.deadlineWindowDays = option
                                        }) {
                                            Text(deadlineLabel(option))
                                                .font(.system(.caption, design: .rounded))
                                                .fontWeight(draft.deadlineWindowDays == option ? .bold : .medium)
                                                .foregroundColor(draft.deadlineWindowDays == option ? .white : .gray)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 8)
                                                .background(
                                                    draft.deadlineWindowDays == option ?
                                                        Color.orange.opacity(0.35) :
                                                        Color(white: 0.1)
                                                )
                                                .cornerRadius(8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(draft.deadlineWindowDays == option ? Color.orange : Color(white: 0.2), lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        
                        // 重复设置（非节点编辑模式）
                        if !isEditingNode && draft.taskMode != .reminderOnly {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Repeat Schedule")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                // 重复类型选择
                                HStack(spacing: 8) {
                                    ForEach(RepeatType.allCases) { type in
                                        Button(action: {
                                            draft.repeatType = type
                                            if type == .none {
                                                draft.selectedWeekdays.removeAll()
                                            }
                                        }) {
                                            Text(type.rawValue)
                                                .font(.system(.caption, design: .rounded))
                                                .fontWeight(.semibold)
                                                .foregroundColor(draft.repeatType == type ? .white : .gray)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    draft.repeatType == type ?
                                                        Color.purple.opacity(0.3) :
                                                        Color(white: 0.1)
                                                )
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                
                                // 具体重复设置
                                if draft.repeatType == .weekly {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Select Days")
                                            .font(.system(.subheadline))
                                            .foregroundColor(.gray)
                                        
                                        HStack(spacing: 8) {
                                            ForEach(1...7, id: \.self) { day in
                                                let dayName = Calendar.current.shortWeekdaySymbols[day-1]
                                                Button(action: {
                                                    if draft.selectedWeekdays.contains(day) {
                                                        draft.selectedWeekdays.remove(day)
                                                    } else {
                                                        draft.selectedWeekdays.insert(day)
                                                    }
                                                }) {
                                                    Text(String(dayName.prefix(1)))
                                                        .font(.system(.caption, design: .rounded))
                                                        .fontWeight(.bold)
                                                        .foregroundColor(draft.selectedWeekdays.contains(day) ? .white : .gray)
                                                        .frame(width: 36, height: 36)
                                                        .background(
                                                            draft.selectedWeekdays.contains(day) ?
                                                                Color.blue :
                                                                Color(white: 0.1)
                                                        )
                                                        .clipShape(Circle())
                                                }
                                            }
                                        }
                                    }
                                } else if draft.repeatType == .monthly {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Select Days of Month")
                                            .font(.system(.subheadline))
                                            .foregroundColor(.gray)
                                        
                                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                                            ForEach(1...31, id: \.self) { day in
                                                Button(action: {
                                                    if draft.selectedWeekdays.contains(day) {
                                                        draft.selectedWeekdays.remove(day)
                                                    } else {
                                                        draft.selectedWeekdays.insert(day)
                                                    }
                                                }) {
                                                    Text("\(day)")
                                                        .font(.system(.caption2, design: .rounded))
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(draft.selectedWeekdays.contains(day) ? .white : .gray)
                                                        .frame(width: 32, height: 32)
                                                        .background(
                                                            draft.selectedWeekdays.contains(day) ?
                                                                Color.purple :
                                                                Color(white: 0.1)
                                                        )
                                                        .clipShape(Circle())
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(24)
                }
            }
            .navigationTitle(isEditingNode ? "Edit Task" : (templateToEdit == nil ? "New Card" : "Edit Card"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(draft.title.isEmpty ? .gray : .cyan)
                    .disabled(draft.title.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if !didLoad {
                if let template = templateToEdit {
                    draft = TaskDraft.fromTemplate(template)
                }
                didLoad = true
            }
        }
    }
    
    func saveTemplate() {
        let id = templateToEdit?.id ?? UUID()
        let isReminder = draft.taskMode == .reminderOnly
        let rule: RepeatRule
        if isReminder {
            rule = .none
        } else {
            switch draft.repeatType {
            case .none: rule = .none
            case .daily: rule = .daily
            case .weekly: rule = .weekly(days: draft.selectedWeekdays)
            case .monthly: rule = .monthly(days: draft.selectedWeekdays)
            }
        }
        let template = CardTemplate(
            id: id,
            title: draft.title,
            icon: draft.selectedCategory.icon,
            defaultDuration: draft.duration,
            tags: [],
            energyColor: energyToken(for: draft.selectedCategory),
            category: draft.selectedCategory,
            style: isReminder ? .passive : .focus,
            taskMode: draft.taskMode,
            fixedTime: nil,
            repeatRule: rule,
            remindAt: isReminder ? draft.reminderTime : nil,
            leadTimeMinutes: draft.leadTimeMinutes,
            deadlineWindowDays: isReminder ? nil : draft.deadlineWindowDays
        )
        
        if isEditingNode, let onSave = onSaveNode {
             onSave(template)
        } else {
             cardStore.add(template)
             libraryStore.add(templateId: template.id)
        }
        dismiss()
    }
    
    private func energyToken(for category: TaskCategory) -> EnergyColorToken {
        switch category {
        case .work, .study:
            return .focus
        case .gym:
            return .gym
        case .rest:
            return .rest
        case .other:
            return .creative
        }
    }

    private var taskModeOptions: [TaskMode] {
        [.focusStrictFixed, .focusGroupFlexible, .reminderOnly]
    }
    
    private func taskModeLabel(_ mode: TaskMode) -> String {
        switch mode {
        case .focusStrictFixed:
            return "Focus Fixed"
        case .focusGroupFlexible:
            return "Focus Flex"
        case .reminderOnly:
            return "Reminder"
        }
    }
    
    private func taskModeTint(_ mode: TaskMode) -> Color {
        switch mode {
        case .focusStrictFixed:
            return .cyan
        case .focusGroupFlexible:
            return .mint
        case .reminderOnly:
            return .orange
        }
    }

    private func leadTimeLabel(_ minutes: Int) -> String {
        if minutes == 0 {
            return "On Time"
        }
        return "\(minutes)m early"
    }

    private func deadlineLabel(_ option: Int?) -> String {
        guard let option else { return "Off" }
        return "\(option)d"
    }
}
