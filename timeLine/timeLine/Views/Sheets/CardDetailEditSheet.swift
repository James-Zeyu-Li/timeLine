import SwiftUI
import TimeLineCore

struct CardDetailEditSheet: View {
    let cardTemplateId: UUID
    
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var libraryStore: LibraryStore
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var appMode: AppModeManager

    @State private var draft = TaskDraft.default
    @State private var cardMissing = false
    @State private var didLoad = false
    
    // MARK: - Task Draft Model
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
    
    enum RepeatType: String, CaseIterable, Identifiable {
        case none = "None"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        var id: String { rawValue }
    }

    // Presets
    let durationPresets: [(String, TimeInterval)] = [
        ("15m", 900), ("25m", 1500), ("30m", 1800),
        ("45m", 2700),
        ("1h", 3600), ("90m", 5400), ("2h", 7200)
    ]
    let deadlineOptions: [Int?] = [nil, 1, 3, 5, 7]
    let taskModeOptions: [TaskMode] = [.focusStrictFixed, .focusGroupFlexible, .reminderOnly, .dungeonRaid(enemies: [])]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                if cardMissing {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.gray)
                        Text("Card not found")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.white)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 32) {
                            // Title & Category
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
                                                categoryButton(for: category)
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
                                    ForEach(taskModeOptions, id: \.self) { mode in
                                        Button(action: {
                                            draft.taskMode = mode
                                        }) {
                                            modeButton(for: mode)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(isTaskModeLocked)
                                    }
                                }
                                if isTaskModeLocked {
                                    Text("Locked during active battle.")
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            
                            if draft.taskMode == .reminderOnly {
                                reminderSettingsView
                            }
                            
                            if draft.taskMode != .reminderOnly {
                                durationSettingsView
                                completionWindowView
                            }
                            
                            // Repeat Schedule
                            if draft.taskMode != .reminderOnly {
                                repeatSettingsView
                            }
                            
                            // Backlog Toggle
                            HStack {
                                Text("Save to Backlog")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Spacer()
                                Toggle("", isOn: libraryBinding)
                                    .labelsHidden()
                            }
                            .padding(.vertical, 8)
                            
                            Spacer(minLength: 100)
                        }
                        .padding(24)
                    }
                }
            }
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        appMode.exitCardEdit()
                    }
                    .foregroundColor(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        appMode.exitCardEdit()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(draft.title.isEmpty ? .gray : .cyan)
                    .disabled(draft.title.isEmpty)
                }
            }
        }
        .onAppear {
            loadCardIfNeeded()
        }
    }
    
    // MARK: - Subviews
    
    private func categoryButton(for category: TaskCategory) -> some View {
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
    
    private func modeButton(for mode: TaskMode) -> some View {
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
    
    private var reminderSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            DatePicker(
                "Remind At",
                selection: $draft.reminderTime,
                displayedComponents: [.date, .hourAndMinute]
            )
            .colorScheme(.dark)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Lead Time")
                    .font(.system(.subheadline))
                    .foregroundColor(.white)
                
                Picker("Lead Time", selection: $draft.leadTimeMinutes) {
                    Text("On Time").tag(0)
                    Text("5m early").tag(5)
                    Text("10m early").tag(10)
                    Text("30m early").tag(30)
                    Text("1h early").tag(60)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(16)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
    
    private var durationSettingsView: some View {
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
    }
    
    private var completionWindowView: some View {
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
    
    private var repeatSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Repeat Schedule")
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
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

    // MARK: - Logic & Helpers
    
    private var libraryBinding: Binding<Bool> {
        Binding(
            get: { libraryStore.entry(for: cardTemplateId) != nil },
            set: { isOn in
                if isOn {
                    // We need the template logic to add.
                    // If draft is valid, update store then add to library
                    saveChanges()
                    if let template = cardStore.get(id: cardTemplateId) {
                        libraryStore.add(templateId: template.id)
                    }
                } else {
                    libraryStore.remove(templateId: cardTemplateId)
                }
                stateManager.requestSave()
            }
        )
    }

    private func taskModeLabel(_ mode: TaskMode) -> String {
        switch mode {
        case .focusStrictFixed: return "Focus Fixed"
        case .focusGroupFlexible: return "Focus Flex"
        case .reminderOnly: return "Reminder"
        case .dungeonRaid: return "Dungeon Raid"
        }
    }
    
    private func taskModeTint(_ mode: TaskMode) -> Color {
        switch mode {
        case .focusStrictFixed: return .cyan
        case .focusGroupFlexible: return .mint
        case .reminderOnly: return .orange
        case .dungeonRaid: return .red
        }
    }

    private func deadlineLabel(_ option: Int?) -> String {
        guard let option else { return "Off" }
        return "\(option)d"
    }

    private var isTaskModeLocked: Bool {
        if case .fighting = engine.state, engine.currentBoss?.templateId == cardTemplateId {
            return true
        }
        return false
    }
    
    private func loadCardIfNeeded() {
        guard !didLoad else { return }
        if let card = cardStore.get(id: cardTemplateId) {
            draft = TaskDraft.fromTemplate(card)
            didLoad = true
        } else {
            cardMissing = true
        }
    }
    
    private func saveChanges() {
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
            id: cardTemplateId,
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
        
        cardStore.update(template)
        updateOccurrences(for: template)
    }
    
    private func updateOccurrences(for template: CardTemplate) {
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        for node in daySession.nodes where !node.isCompleted {
            guard case .battle(let boss) = node.type,
                  boss.templateId == template.id else { continue }
            timelineStore.updateNode(id: node.id, payload: template)
        }
    }

    private func energyToken(for category: TaskCategory) -> EnergyColorToken {
        switch category {
        case .work, .study: return .focus
        case .gym: return .gym
        case .rest: return .rest
        case .other: return .creative
        }
    }
}
