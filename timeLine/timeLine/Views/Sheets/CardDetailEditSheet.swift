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

    @State var draft = TaskDraft.default
    @State var cardMissing = false
    @State var didLoad = false
    
    // Presets
    let durationPresets: [(String, TimeInterval)] = [
        ("15m", 900), ("25m", 1500), ("30m", 1800),
        ("45m", 2700),
        ("1h", 3600), ("90m", 5400), ("2h", 7200)
    ]
    let deadlineOptions: [Int?] = [nil, 1, 3, 5, 7]
    let taskModeOptions: [TaskMode] = [.focusStrictFixed, .focusGroupFlexible, .reminderOnly]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                PixelTheme.cream.ignoresSafeArea()
                
                if cardMissing {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(PixelTheme.textSecondary)
                        Text("Card not found")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(PixelTheme.textPrimary)
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
                                        .foregroundColor(PixelTheme.textPrimary)
                                    
                                    TextField("What needs to be done?", text: $draft.title)
                                        .font(.system(.title3, design: .rounded))
                                        .padding(16)
                                        .background(PixelTheme.cardBackground)
                                        .cornerRadius(12)
                                        .foregroundColor(PixelTheme.textPrimary)
                                }
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Category")
                                        .font(.system(.headline, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundColor(PixelTheme.textPrimary)
                                    
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
                                    .foregroundColor(PixelTheme.textPrimary)
                                
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
                                    Text("Locked during active session.")
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundColor(PixelTheme.textSecondary)
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
                                    .foregroundColor(PixelTheme.textPrimary)
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
                    .foregroundColor(PixelTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        appMode.exitCardEdit()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(draft.title.isEmpty ? PixelTheme.textSecondary : PixelTheme.primary)
                    .disabled(draft.title.isEmpty)
                }
            }
        }
        .onAppear {
            loadCardIfNeeded()
        }
    }
}
