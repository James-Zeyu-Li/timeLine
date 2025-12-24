import SwiftUI
import TimeLineCore

struct QuickBuilderSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var templateStore: TemplateStore
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var engine: BattleEngine
    
    @State private var selectedTitle: String = "Study"
    @State private var selectedCategory: TaskCategory = .study
    @State private var selectedDuration: QuickDuration = .m30
    @State private var selectedPlacement: QuickPlacement = .today
    @State private var saveAsCard: Bool = true
    @State private var showingCustomSheet: Bool = false
    @State private var editingTemplate: TaskTemplate? = nil
    
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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        sectionTitle("Pick a task")
                        flowChips(items: topics, tintFromCategory: true) { item in
                            selectedTitle = item.0
                            selectedCategory = item.1
                        } isSelected: { item in
                            selectedTitle == item.0
                        }
                        
                        sectionTitle("Duration")
                        chipRow(
                            items: QuickDuration.allCases,
                            tint: .green
                        ) { option in
                            selectedDuration = option
                        } isSelected: { option in
                            selectedDuration == option
                        } label: { option in
                            option.label
                        }
                        
                        sectionTitle("When")
                        chipRow(
                            items: QuickPlacement.allCases,
                            tint: .cyan
                        ) { option in
                            selectedPlacement = option
                        } isSelected: { option in
                            selectedPlacement == option
                        } label: { option in
                            option.label
                        }
                        
                        Toggle(isOn: $saveAsCard) {
                            Text("Save as Card")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .cyan))
                        .padding(.top, 4)
                        
                        Button(action: handlePrimaryAction) {
                            HStack {
                                Spacer()
                                Text(primaryActionTitle)
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.vertical, 14)
                            .background(Color.cyan.opacity(0.2))
                            .cornerRadius(14)
                        }
                        .buttonStyle(PlainButtonStyle())
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
        .sheet(isPresented: $showingCustomSheet) {
            TaskSheet(templateToEdit: $editingTemplate)
        }
    }
    
    private var primaryActionTitle: String {
        switch selectedPlacement {
        case .today:
            return "Add to Today"
        case .tomorrow:
            return "Send to Inbox"
        case .everyday:
            return "Add + Save"
        case .customize:
            return "Open Custom"
        }
    }
    
    private func handlePrimaryAction() {
        if selectedPlacement == .customize {
            editingTemplate = nil
            showingCustomSheet = true
            return
        }
        
        let style: BossStyle = selectedCategory == .rest ? .passive : .focus
        let template = TaskTemplate(
            title: selectedTitle,
            style: style,
            duration: selectedDuration.duration,
            fixedTime: nil,
            repeatRule: selectedPlacement == .everyday ? .daily : .none,
            category: selectedCategory
        )
        
        if saveAsCard || selectedPlacement == .everyday {
            templateStore.add(template)
        }
        
        switch selectedPlacement {
        case .today, .everyday:
            if selectedDuration.isMultiBlock {
                addMultiBlockTasks(title: selectedTitle, style: style)
            } else {
                spawnTask(from: template)
            }
        case .tomorrow:
            stateManager.inbox.append(template)
        case .customize:
            break
        }
        
        stateManager.requestSave()
        dismiss()
    }
    
    private func addMultiBlockTasks(title: String, style: BossStyle) {
        let bosses = (1...selectedDuration.blockCount).map { index in
            Boss(
                name: "\(title) - \(index)",
                maxHp: selectedDuration.blockDuration,
                style: style,
                category: selectedCategory
            )
        }
        
        let route = RouteGenerator.generateRoute(from: bosses)
        withAnimation(.easeInOut(duration: 0.25)) {
            appendNodes(route)
        }
    }
    
    private func spawnTask(from template: TaskTemplate) {
        let boss = SpawnManager.spawn(from: template)
        let newNode = TimelineNode(
            type: .battle(boss),
            isLocked: true
        )
        withAnimation(.easeInOut(duration: 0.25)) {
            appendNodes([newNode])
        }
    }
    
    private func appendNodes(_ newNodes: [TimelineNode]) {
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        timelineStore.appendNodes(newNodes, engine: engine)
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
        .buttonStyle(PlainButtonStyle())
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
    
    var isMultiBlock: Bool {
        self == .h3Breaks
    }
    
    var blockCount: Int {
        isMultiBlock ? 3 : 1
    }
    
    var blockDuration: TimeInterval {
        isMultiBlock ? 3600 : duration
    }
}

private enum QuickPlacement: String, CaseIterable, Identifiable {
    case today
    case tomorrow
    case everyday
    case customize
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .everyday: return "Everyday"
        case .customize: return "Customize"
        }
    }
}
