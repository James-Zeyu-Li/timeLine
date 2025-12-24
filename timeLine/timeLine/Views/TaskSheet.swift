import SwiftUI
import TimeLineCore


struct TaskSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var templateStore: TemplateStore
    @Binding var templateToEdit: TaskTemplate?
    
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
        ("15m", 900), ("25m", 1500), ("30m", 1800),
        ("45m", 2700),
        ("1h", 3600), ("90m", 5400), ("2h", 7200)
    ]
    
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
                                
                                TextField("What needs to be done?", text: $title)
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
                                            selectedCategory = category
                                        }) {
                                            VStack(spacing: 8) {
                                                Image(systemName: category.icon)
                                                    .font(.system(size: 24))
                                                    .foregroundColor(selectedCategory == category ? .white : category.color)
                                                
                                                Text(category.rawValue.capitalized)
                                                    .font(.system(.caption, design: .rounded))
                                                    .fontWeight(.medium)
                                                    .foregroundColor(selectedCategory == category ? .white : .gray)
                                            }
                                            .frame(height: 80)
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                selectedCategory == category ?
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
                                                        selectedCategory == category ? category.color : Color(white: 0.2),
                                                        lineWidth: selectedCategory == category ? 2 : 1
                                                    )
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 执行模式选择
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Execution Mode")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                Button(action: { selectedStyle = .focus }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(selectedStyle == .focus ? .white : .yellow)
                                        
                                        Text("Focus")
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(.semibold)
                                        
                                        Text("Timer-based")
                                            .font(.system(.caption2))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(16)
                                    .background(
                                        selectedStyle == .focus ?
                                            LinearGradient(colors: [.yellow.opacity(0.3), .orange.opacity(0.2)], startPoint: .top, endPoint: .bottom) :
                                            LinearGradient(colors: [Color(white: 0.1)], startPoint: .top, endPoint: .bottom)
                                    )
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedStyle == .focus ? .yellow : Color(white: 0.2), lineWidth: 2)
                                    )
                                }
                                .foregroundColor(selectedStyle == .focus ? .white : .gray)
                                
                                Button(action: { selectedStyle = .passive }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(selectedStyle == .passive ? .white : .cyan)
                                        
                                        Text("Passive")
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(.semibold)
                                        
                                        Text("Checkbox")
                                            .font(.system(.caption2))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(16)
                                    .background(
                                        selectedStyle == .passive ?
                                            LinearGradient(colors: [.cyan.opacity(0.3), .blue.opacity(0.2)], startPoint: .top, endPoint: .bottom) :
                                            LinearGradient(colors: [Color(white: 0.1)], startPoint: .top, endPoint: .bottom)
                                    )
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedStyle == .passive ? .cyan : Color(white: 0.2), lineWidth: 2)
                                    )
                                }
                                .foregroundColor(selectedStyle == .passive ? .white : .gray)
                            }
                        }
                        
                        // 时长选择（仅专注模式）
                        if selectedStyle == .focus {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Duration")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                                    ForEach(durationPresets, id: \.0) { (label, value) in
                                        Button(action: {
                                            duration = value
                                        }) {
                                            Text(label)
                                                .font(.system(.subheadline, design: .monospaced))
                                                .fontWeight(duration == value ? .bold : .medium)
                                                .foregroundColor(duration == value ? .white : .gray)
                                                .frame(height: 44)
                                                .frame(maxWidth: .infinity)
                                                .background(
                                                    duration == value ?
                                                        LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .top, endPoint: .bottom) :
                                                        LinearGradient(colors: [Color(white: 0.1)], startPoint: .top, endPoint: .bottom)
                                                )
                                                .cornerRadius(8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(duration == value ? .green : Color(white: 0.2), lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 重复设置（非节点编辑模式）
                        if !isEditingNode {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Repeat Schedule")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                // 重复类型选择
                                HStack(spacing: 8) {
                                    ForEach(RepeatType.allCases) { type in
                                        Button(action: {
                                            repeatType = type
                                            if type == .none {
                                                selectedWeekdays.removeAll()
                                            }
                                        }) {
                                            Text(type.rawValue)
                                                .font(.system(.caption, design: .rounded))
                                                .fontWeight(.semibold)
                                                .foregroundColor(repeatType == type ? .white : .gray)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    repeatType == type ?
                                                        Color.purple.opacity(0.3) :
                                                        Color(white: 0.1)
                                                )
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                
                                // 具体重复设置
                                if repeatType == .weekly {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Select Days")
                                            .font(.system(.subheadline))
                                            .foregroundColor(.gray)
                                        
                                        HStack(spacing: 8) {
                                            ForEach(1...7, id: \.self) { day in
                                                let dayName = Calendar.current.shortWeekdaySymbols[day-1]
                                                Button(action: {
                                                    if selectedWeekdays.contains(day) {
                                                        selectedWeekdays.remove(day)
                                                    } else {
                                                        selectedWeekdays.insert(day)
                                                    }
                                                }) {
                                                    Text(String(dayName.prefix(1)))
                                                        .font(.system(.caption, design: .rounded))
                                                        .fontWeight(.bold)
                                                        .foregroundColor(selectedWeekdays.contains(day) ? .white : .gray)
                                                        .frame(width: 36, height: 36)
                                                        .background(
                                                            selectedWeekdays.contains(day) ?
                                                                Color.blue :
                                                                Color(white: 0.1)
                                                        )
                                                        .clipShape(Circle())
                                                }
                                            }
                                        }
                                    }
                                } else if repeatType == .monthly {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Select Days of Month")
                                            .font(.system(.subheadline))
                                            .foregroundColor(.gray)
                                        
                                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                                            ForEach(1...31, id: \.self) { day in
                                                Button(action: {
                                                    if selectedWeekdays.contains(day) {
                                                        selectedWeekdays.remove(day)
                                                    } else {
                                                        selectedWeekdays.insert(day)
                                                    }
                                                }) {
                                                    Text("\(day)")
                                                        .font(.system(.caption2, design: .rounded))
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(selectedWeekdays.contains(day) ? .white : .gray)
                                                        .frame(width: 32, height: 32)
                                                        .background(
                                                            selectedWeekdays.contains(day) ?
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
                    .foregroundColor(title.isEmpty ? .gray : .cyan)
                    .disabled(title.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
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
