import SwiftUI
import TimeLineCore

struct TaskSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var templateStore: TemplateStore
    @Binding var templateToEdit: TaskTemplate? // Passed from parent
    
    // Node Editing Mode
    var isEditingNode: Bool = false
    var onSaveNode: ((TaskTemplate) -> Void)? = nil
    
    // Form State
    @State private var title: String = ""
    @State private var selectedCategory: TaskCategory = .work
    @State private var selectedStyle: BossStyle = .focus
    @State private var duration: TimeInterval = 1800 // 30m
    
    // Repeat State
    @State private var repeatType: RepeatType = .none
    @State private var selectedWeekdays: Set<Int> = []
    
    enum RepeatType: String, CaseIterable, Identifiable {
        case none = "None"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        
        var id: String { rawValue }
    }
    
    // Presets
    let durationPresets: [(String, TimeInterval)] = [
        ("15m", 900), ("30m", 1800), ("45m", 2700),
        ("1h", 3600), ("90m", 5400), ("2h", 7200)
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("What to do?", text: $title)
                        .font(.headline)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(TaskCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue.capitalized, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    
                    Picker("Style", selection: $selectedStyle) {
                        Text("Focus (Timer)").tag(BossStyle.focus)
                        Text("Passive (Checkbox)").tag(BossStyle.passive)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Duration")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(durationPresets, id: \.0) { (label, value) in
                                Button(action: {
                                    duration = value
                                }) {
                                    Text(label)
                                        .fontWeight(duration == value ? .bold : .regular)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                        .background(duration == value ? Color.accentColor : Color.gray.opacity(0.2))
                                        .foregroundColor(duration == value ? .white : .primary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                
                if !isEditingNode {
                    Section(header: Text("Repeat")) {
                        Picker("Repeat", selection: $repeatType) {
                            ForEach(RepeatType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        // ... Weekly/Monthly Pickers ...
                        if repeatType == .weekly {
                             HStack {
                                ForEach(1...7, id: \.self) { day in
                                    let dayName = Calendar.current.shortWeekdaySymbols[day-1].prefix(1)
                                    Button(action: {
                                        if selectedWeekdays.contains(day) {
                                            selectedWeekdays.remove(day)
                                        } else {
                                            selectedWeekdays.insert(day)
                                        }
                                    }) {
                                        Text(String(dayName))
                                            .font(.caption)
                                            .frame(width: 30, height: 30)
                                            .background(selectedWeekdays.contains(day) ? Color.blue : Color.gray.opacity(0.2))
                                            .foregroundColor(selectedWeekdays.contains(day) ? .white : .primary)
                                            .clipShape(Circle())
                                    }
                                }
                            }
                        } else if repeatType == .monthly {
                                // Monthly Day Picker (1-31 grid)
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                                    ForEach(1...31, id: \.self) { day in
                                        Button(action: {
                                            if selectedWeekdays.contains(day) { // reusing selectedWeekdays for days set
                                                selectedWeekdays.remove(day)
                                            } else {
                                                selectedWeekdays.insert(day)
                                            }
                                        }) {
                                            Text("\(day)")
                                                .font(.caption2)
                                                .frame(width: 24, height: 24)
                                                .background(selectedWeekdays.contains(day) ? Color.purple : Color.gray.opacity(0.2))
                                                .foregroundColor(selectedWeekdays.contains(day) ? .white : .primary)
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                    }
                }
            }
            .navigationTitle(isEditingNode ? "Edit Task" : (templateToEdit == nil ? "New Card" : "Edit Card"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .onAppear {
            if let template = templateToEdit {
                // Populate fields
                title = template.title
                selectedCategory = template.category
                selectedStyle = template.style
                duration = template.duration ?? 1800
                
                switch template.repeatRule {
                case .none: repeatType = .none
                case .daily: repeatType = .daily
                case .weekly(let days): 
                    repeatType = .weekly
                    selectedWeekdays = days
                case .monthly(let days):
                     repeatType = .monthly
                     selectedWeekdays = days
                }
            }
        }
    }
    
    func saveTemplate() {
        var rule: RepeatRule = .none
        switch repeatType {
        case .none: rule = .none
        case .daily: rule = .daily
        case .weekly: rule = .weekly(days: selectedWeekdays)
        case .monthly: rule = .monthly(days: selectedWeekdays)
        }
        
        let id = templateToEdit?.id ?? UUID()
        let template = TaskTemplate(
            id: id,
            title: title,
            style: selectedStyle,
            duration: duration,
            fixedTime: nil, // V0 assumes duration based
            repeatRule: rule,
            category: selectedCategory
        )
        
        if isEditingNode, let onSave = onSaveNode {
             onSave(template)
        } else {
             templateStore.add(template)
        }
        dismiss()
    }
}
