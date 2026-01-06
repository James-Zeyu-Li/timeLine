import SwiftUI
import TimeLineCore

struct QuickBuilderSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var libraryStore: LibraryStore
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var engine: BattleEngine
    
    let onCreated: (() -> Void)?
    
    init(onCreated: (() -> Void)? = nil) {
        self.onCreated = onCreated
    }
    
    @State private var draft = QuickBuilderDraft.default
    @State private var selectedTaskMode: TaskMode = QuickBuilderDraft.default.taskMode
    @FocusState private var isTitleFocused: Bool
    
    private let topics: [(String, TaskCategory)] = [
        ("Study", .study),
        ("Leetcode", .study),
        ("Java", .study),
        ("Work", .work),
        ("Email", .work),
        ("Gym", .gym),
        ("Stretch", .rest),
        ("Break", .rest)
    ]
    
    private struct QuickBuilderDraft: Equatable {
        var title: String
        var category: TaskCategory
        var duration: QuickDuration
        var taskMode: TaskMode
        var reminderTime: Date
        var leadTimeMinutes: Int
        var deadlineWindowDays: Int?
        
        static let `default` = QuickBuilderDraft(
            title: "Study",
            category: .study,
            duration: .m30,
            taskMode: .focusStrictFixed,
            reminderTime: Date().addingTimeInterval(3600), // Default: 1 hour from now
            leadTimeMinutes: 0,
            deadlineWindowDays: nil
        )
    }

    private let deadlineOptions: [(String, Int?)] = [
        ("Off", nil),
        ("1d", 1),
        ("3d", 3),
        ("5d", 5),
        ("7d", 7)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        sectionTitle("Task Title")
                        
                        TextField("What's next?", text: $draft.title)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white)
                            .focused($isTitleFocused)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                            .submitLabel(.done)
                            .onSubmit {
                                isTitleFocused = false
                            }
                            .accessibilityIdentifier("quickBuilderTitleField")
                        
                        sectionTitle("Quick Picks")
                        flowChips(items: topics, tintFromCategory: true) { item in
                            draft.title = item.0
                            draft.category = item.1
                        } isSelected: { item in
                            draft.title == item.0
                        }
                        
                        sectionTitle("Task Mode")
                        taskModePicker
                        
                        if !recentTemplates.isEmpty {
                            sectionTitle("Recent Cards")
                            recentChips
                        }

                        if selectedTaskMode == .reminderOnly {
                            sectionTitle("Remind At")
                            reminderTimePicker
                            
                            sectionTitle("Lead Time")
                            leadTimeChips
                        }

                        if selectedTaskMode != .reminderOnly {
                            sectionTitle("Duration")
                            chipRow(
                                items: QuickDuration.allCases,
                                tint: .green
                            ) { option in
                                draft.duration = option
                            } isSelected: { option in
                                draft.duration == option
                            } label: { option in
                                option.label
                            }

                            sectionTitle("Complete Within")
                            HStack(spacing: 8) {
                                ForEach(deadlineOptions, id: \.0) { option in
                                    Button(action: {
                                        draft.deadlineWindowDays = option.1
                                    }) {
                                        Text(option.0)
                                            .font(.system(.caption, design: .rounded))
                                            .fontWeight(draft.deadlineWindowDays == option.1 ? .bold : .medium)
                                            .foregroundColor(draft.deadlineWindowDays == option.1 ? .white : .gray)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .background(
                                                draft.deadlineWindowDays == option.1 ?
                                                    Color.orange.opacity(0.35) :
                                                    Color(white: 0.1)
                                            )
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(draft.deadlineWindowDays == option.1 ? Color.orange : Color(white: 0.2), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        Button(action: handlePrimaryAction) {
                            HStack {
                                Spacer()
                                Text("Create Card")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.vertical, 14)
                            .background(Color.cyan.opacity(0.2))
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                        .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("quickBuilderCreateButton")
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Quick Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func handlePrimaryAction() {
        let trimmed = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let style: BossStyle = selectedTaskMode == .reminderOnly ? .passive : .focus
        let remindAt: Date? = selectedTaskMode == .reminderOnly ? draft.reminderTime : nil
        let template = CardTemplate(
            title: trimmed,
            icon: draft.category.icon,
            defaultDuration: draft.duration.duration,
            tags: [draft.category.rawValue],
            energyColor: energyToken(for: draft.category),
            category: draft.category,
            style: style,
            taskMode: selectedTaskMode,
            remindAt: remindAt,
            leadTimeMinutes: draft.leadTimeMinutes,
            deadlineWindowDays: selectedTaskMode == .reminderOnly ? nil : draft.deadlineWindowDays
        )
        cardStore.add(template)
        libraryStore.add(templateId: template.id)
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        if let remindAt = template.remindAt {
            _ = timelineStore.placeCardOccurrenceByTime(
                cardTemplateId: template.id,
                remindAt: remindAt,
                using: cardStore,
                engine: engine
            )
        } else {
            if let lastNode = daySession.nodes.last {
                _ = timelineStore.placeCardOccurrence(
                    cardTemplateId: template.id,
                    anchorNodeId: lastNode.id,
                    using: cardStore
                )
            } else {
                _ = timelineStore.placeCardOccurrenceAtStart(
                    cardTemplateId: template.id,
                    using: cardStore,
                    engine: engine
                )
            }
        }
        onCreated?()
        appMode.enter(.deckOverlay(.cards))
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
    
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(.headline, design: .rounded))
            .fontWeight(.semibold)
            .foregroundColor(.white)
    }
    
    private func chipRow<T: Identifiable>(
        items: [T],
        tint: Color,
        onSelect: @escaping (T) -> Void,
        isSelected: @escaping (T) -> Bool,
        label: @escaping (T) -> String
    ) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            ForEach(items) { item in
                ChipButton(
                    title: label(item),
                    isSelected: isSelected(item),
                    tint: tint
                ) {
                    onSelect(item)
                }
            }
        }
    }
    
    private func flowChips(
        items: [(String, TaskCategory)],
        tintFromCategory: Bool,
        onSelect: @escaping ((String, TaskCategory)) -> Void,
        isSelected: @escaping ((String, TaskCategory)) -> Bool
    ) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
            ForEach(items, id: \.0) { item in
                let tint = tintFromCategory ? item.1.color : .cyan
                ChipButton(
                    title: item.0,
                    isSelected: isSelected(item),
                    tint: tint
                ) {
                    onSelect(item)
                }
            }
        }
    }
    
    private var recentTemplates: [CardTemplate] {
        Array(cardStore.orderedTemplates(includeEphemeral: false).prefix(6))
    }
    
    private var recentChips: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
            ForEach(recentTemplates) { template in
                let isSelected = draft.title == template.title && draft.category == template.category
                ChipButton(
                    title: template.title,
                    isSelected: isSelected,
                    tint: template.category.color
                ) {
                    draft.title = template.title
                    draft.category = template.category
                    draft.duration = durationOption(for: template.defaultDuration)
                    setTaskMode(template.taskMode)
                }
            }
        }
    }
    
    private var taskModePicker: some View {
        Picker(
            "Task Mode",
            selection: Binding(
                get: { selectedTaskMode },
                set: { mode in
                    isTitleFocused = false
                    setTaskMode(mode)
                }
            )
        ) {
            ForEach(taskModeOptions, id: \.rawValue) { mode in
                Text(taskModeLabel(mode)).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("quickBuilderTaskModePicker")
        .accessibilityValue(taskModeLabel(selectedTaskMode))
    }
    
    private var reminderTimePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            
            Text("Reminder will appear at this time")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var leadTimeChips: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
            ForEach([0, 5, 10, 30, 60], id: \.self) { minutes in
                ChipButton(
                    title: leadTimeLabel(minutes),
                    isSelected: draft.leadTimeMinutes == minutes,
                    tint: .orange
                ) {
                    draft.leadTimeMinutes = minutes
                }
            }
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
    
    private func leadTimeLabel(_ minutes: Int) -> String {
        if minutes == 0 {
            return "On Time"
        }
        return "\(minutes)m early"
    }
    
    private func durationOption(for seconds: TimeInterval) -> QuickDuration {
        let target = max(0, seconds)
        let options = QuickDuration.allCases
        let closest = options.min { lhs, rhs in
            abs(lhs.duration - target) < abs(rhs.duration - target)
        }
        return closest ?? .m30
    }

    private func setTaskMode(_ mode: TaskMode) {
        selectedTaskMode = mode
        draft.taskMode = mode
    }
}

private struct ChipButton: View {
    let title: String
    let isSelected: Bool
    let tint: Color
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    isSelected
                    ? tint.opacity(0.35)
                    : Color(white: 0.1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isSelected ? tint : Color(white: 0.2),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "selected" : "unselected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityRemoveTraits(isSelected ? [] : .isSelected)
    }
}

private enum QuickDuration: String, CaseIterable, Identifiable {
    case m15
    case m30
    case h1
    case h3Breaks
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .m15: return "15 min"
        case .m30: return "30 min"
        case .h1: return "1 hour"
        case .h3Breaks: return "3 hours + breaks"
        }
    }
    
    var duration: TimeInterval {
        switch self {
        case .m15: return 900
        case .m30: return 1800
        case .h1: return 3600
        case .h3Breaks: return 10800
        }
    }
}
