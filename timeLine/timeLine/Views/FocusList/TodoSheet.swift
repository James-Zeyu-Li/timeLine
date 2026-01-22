import SwiftUI
import TimeLineCore

struct TodoSheet: View {
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var libraryStore: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var rows: [FocusRow] = [FocusRow()]
    @State private var selectedLibraryIds: Set<UUID> = []
    @State private var errorMessage: String?
    
    // Drag Support
    // Drag Support
    @EnvironmentObject var appMode: AppModeManager
    // Fix: Use @ObservedObject + explicit init to prevent crash from environment loss
    @ObservedObject var dragCoordinator: DragDropCoordinator
    
    @State private var draggingFocusRowId: UUID?
    @State private var showActiveBattleConfirm = false
    @State private var durationPickerTarget: RowPickerTarget?
    @State private var finishPickerTarget: RowPickerTarget?
    @State private var finishPickerDate = Date()
    @FocusState private var focusedRowId: UUID?

    private enum FinishBySelection: Equatable {
        case tonight
        case tomorrow
        case next3Days
        case thisWeek
        case none
        case pickDate(Date)
    }

    private struct FocusRow: Identifiable, Equatable {
        let id: UUID
        var title: String
        var durationMinutes: Int?
        var durationFromInput: Bool
        var finishBy: FinishBySelection

        init() {
            id = UUID()
            title = ""
            durationMinutes = nil
            durationFromInput = false
            finishBy = .next3Days
        }
    }

    private struct RowPickerTarget: Identifiable {
        let id: UUID
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            statusLine
            rowsList
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(PixelTheme.vitality)
            }
            actionBar
        }
        .padding(20)
        .background(
            // 温馨的草地背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    PixelTheme.cream,
                    PixelTheme.forest.opacity(0.1)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
                .onAppear {
            if focusedRowId == nil {
                focusedRowId = rows.first?.id
            }
        }
        .confirmationDialog(
            "结束当前专注？",
            isPresented: $showActiveBattleConfirm,
            titleVisibility: .visible
        ) {
            Button("结束并开始新专注", role: .destructive) {
                startFocus()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("你正在进行专注任务。开始新的专注会结束当前任务。")
        }
        .sheet(item: $durationPickerTarget) { target in
            DurationPickerSheet(
                currentMinutes: durationMinutes(for: target.id),
                onSelect: { minutes in
                    setDuration(target.id, minutes: minutes)
                    durationPickerTarget = nil
                }
            )
        }
        .sheet(item: $finishPickerTarget) { target in
            finishByPickerSheet(rowId: target.id)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // 添加像素风格的小图标
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(PixelTheme.forest)
                
                Text("任务清单")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(PixelTheme.textPrimary)
                
                Spacer()
                
                Button("整理格式") {
                    cleanDurationFormats()
                }
                .font(.system(.caption, design: .rounded))
                .foregroundColor(PixelTheme.forest)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(PixelTheme.forest.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(PixelTheme.forest.opacity(0.3), lineWidth: 1)
                        )
                )
                .buttonStyle(.plain)
            }
            
            Text("🌱 每行一个任务，设置时长与截止时间")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(PixelTheme.textPrimary.opacity(0.7))
            
            Text("💡 输入如 Math 45m 会自动填充时长（稍后可整理格式）")
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(PixelTheme.textPrimary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(PixelTheme.cardBackground.opacity(0.9))
                .shadow(color: PixelTheme.woodMedium.opacity(0.2), radius: 4, x: 2, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(PixelTheme.forest.opacity(0.3), lineWidth: 2)
                )
        )
    }

    private var statusLine: some View {
        let validCount = validRows.count
        let libraryCount = selectedLibraryIds.count
        guard validCount > 0 || libraryCount > 0 else { return AnyView(EmptyView()) }
        let missingCount = missingDurationCount
        let summary = "📝 任务 \(validCount) · ⏰ 缺时长 \(missingCount) · ✅ 已选 \(libraryCount)"
        return AnyView(
            HStack {
                Text(summary)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(PixelTheme.textPrimary.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(PixelTheme.cream.opacity(0.8))
                            .overlay(
                                Capsule()
                                    .stroke(PixelTheme.forest.opacity(0.2), lineWidth: 1)
                            )
                    )
                Spacer()
            }
        )
    }

    private var rowsList: some View {
        List {
            // Task input rows section
            Section {
                taskInputRows
                addTaskButton
            }

            // Library sections
            libraryRowsSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(minHeight: 200, maxHeight: 520)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(PixelTheme.cardBackground.opacity(0.6))
                .shadow(color: PixelTheme.woodMedium.opacity(0.2), radius: 6, x: 3, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(PixelTheme.forest.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    private var libraryRowsSection: some View {
        ForEach(librarySections, id: \.title) { section in
            if !section.rows.isEmpty {
                Section {
                    ForEach(section.rows) { row in
                        LibraryRowView(
                            data: row,
                            isSelected: selectedLibraryIds.contains(row.id),
                            onToggle: { toggleLibrarySelection(row.id, isExpired: row.entry.deadlineStatus == .expired) }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    sectionHeader(for: section.title)
                }
            }
        }
    }
    
    private var taskInputRows: some View {
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
            makeFocusRowView(index: index, row: row)
        }
    }

    private func makeFocusRowView(index: Int, row: FocusRow) -> some View {
        FocusRowView(
            title: titleBinding(for: row),
            parsedDuration: parsedDurationLabel(for: row),
            durationTitle: durationButtonTitle(for: row),
            finishByTitle: finishByTitle(for: row),
            onDurationTap: { durationPickerTarget = RowPickerTarget(id: row.id) },
            onFinishTap: { openFinishPicker(for: row.id) },
            onSubmit: { handleSubmit(for: row.id) },
            onDragStart: { startDrag(for: row) },
            isDragged: draggingFocusRowId == row.id,
            dragOffset: (draggingFocusRowId == row.id) ? dragCoordinator.dragOffset : .zero,
            focusedRowId: $focusedRowId,
            rowId: row.id,
            rowIndex: index
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteRow(row.id)
            } label: {
                Label("删除", systemImage: "trash")
            }
            .tint(Color(red: 0.941, green: 0.502, blue: 0.188)) // 活力橘
        }
    }
    
    private var addTaskButton: some View {
        Button {
            addRowAndFocus()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(PixelTheme.forest)
                Text("添加任务")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(PixelTheme.forest)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(PixelTheme.forest.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(PixelTheme.forest.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    )
            )
        }
        .accessibilityIdentifier("focusListAddRow")
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    private func sectionHeader(for title: String) -> some View {
        HStack {
            Image(systemName: sectionIcon(for: title))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(PixelTheme.forest)
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(PixelTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(PixelTheme.cardBackground.opacity(0.8))
                .shadow(color: PixelTheme.woodMedium.opacity(0.1), radius: 2, x: 1, y: 1)
        )
    }
    


    private var actionBar: some View {
        HStack(spacing: 12) {
            cancelButton
            
            // Save to Library button (收藏种子)
            if canSaveToLibrary {
                saveToLibraryButton
            }

            // Add to Timeline button (种植到农场)
            if canAddToTimeline {
                addToTimelineButton
            }

            startButton
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(PixelTheme.cardBackground.opacity(0.9))
                .shadow(color: PixelTheme.woodMedium.opacity(0.2), radius: 4, x: 2, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(PixelTheme.forest.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    private var cancelButton: some View {
        Button("取消") {
            dismiss()
        }
        .font(.system(.caption, design: .rounded))
        .fontWeight(.semibold)
        .foregroundColor(PixelTheme.textPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(PixelTheme.cardBackground.opacity(0.8))
                .overlay(
                    Capsule()
                        .stroke(PixelTheme.woodMedium.opacity(0.3), lineWidth: 1)
                )
        )
        .onChange(of: appMode.isDragging) { _, isDragging in
             if !isDragging { draggingFocusRowId = nil }
        }
        .onChange(of: dragCoordinator.draggedNodeId) { _, id in
            if id == nil { draggingFocusRowId = nil }
        }
        .accessibilityIdentifier("focusListCancelButton")
    }
    
    private var saveToLibraryButton: some View {
        Button("🌱 收藏种子") {
            saveToLibrary()
        }
        .font(.system(.caption, design: .rounded))
        .fontWeight(.semibold)
        .foregroundColor(PixelTheme.textInverted)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(PixelTheme.vitality)
                .shadow(color: PixelTheme.vitality.opacity(0.3), radius: 3, x: 2, y: 2)
        )
        .accessibilityIdentifier("focusListSaveButton")
    }
    
    private var addToTimelineButton: some View {
        Button("🌾 种植到农场") {
            addToTimeline()
        }
        .font(.system(.caption, design: .rounded))
        .fontWeight(.semibold)
        .foregroundColor(PixelTheme.textInverted)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(PixelTheme.forest)
                .shadow(color: PixelTheme.forest.opacity(0.3), radius: 3, x: 2, y: 2)
        )
        .accessibilityIdentifier("focusListAddToTimelineButton")
    }
    
    private var startButton: some View {
        Button(startButtonTitle) {
            if isActiveBattle {
                showActiveBattleConfirm = true
            } else {
                startFocus()
            }
        }
        .font(.system(.caption, design: .rounded))
        .fontWeight(.bold)
        .foregroundColor(PixelTheme.textInverted)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(
                    canStart ?
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.2, green: 0.8, blue: 0.8),
                            Color(red: 0.1, green: 0.7, blue: 0.9)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        gradient: Gradient(colors: [PixelTheme.textSecondary.opacity(0.3), PixelTheme.textSecondary.opacity(0.2)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: canStart ? Color.cyan.opacity(0.4) : Color.clear, radius: 4, x: 2, y: 2)
        )
        .disabled(!canStart)
        .accessibilityIdentifier("focusListStartButton")
    }

    private var validRows: [FocusRow] {
        rows.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var missingDurationCount: Int {
        validRows.filter { $0.durationMinutes == nil }.count
    }

    private var canStart: Bool {
        !validRows.isEmpty || !selectedLibraryIds.isEmpty
    }
    
    private var canSaveToLibrary: Bool {
        !validRows.isEmpty
    }
    
    private var canAddToTimeline: Bool {
        !validRows.isEmpty && validRows.allSatisfy { $0.durationMinutes != nil }
    }


    private var startButtonTitle: String {
        if totalSelectionCount > 1 {
            return "🌟 开始探险队"
        } else {
            return "⚡ 开始专注"
        }
    }

    private var isActiveBattle: Bool {
        switch engine.state {
        case .fighting, .paused, .frozen:
            return true
        default:
            return false
        }
    }

    private func handleSubmit(for rowId: UUID) {
        guard let index = rows.firstIndex(where: { $0.id == rowId }) else { return }
        let nextIndex = rows.index(after: index)
        if nextIndex >= rows.count {
            addRowAndFocus()
        } else {
            focusedRowId = rows[nextIndex].id
        }
    }

    private func addRowAndFocus() {
        let newRow = FocusRow()
        rows.append(newRow)
        focusedRowId = newRow.id
    }

    private func deleteRow(_ rowId: UUID) {
        rows.removeAll { $0.id == rowId }
        if rows.isEmpty {
            addRowAndFocus()
        }
    }

    private func titleBinding(for row: FocusRow) -> Binding<String> {
        Binding(
            get: {
                row.title
            },
            set: { newValue in
                updateRowTitle(row.id, newValue: newValue)
            }
        )
    }

    private func updateRowTitle(_ rowId: UUID, newValue: String) {
        guard let index = rows.firstIndex(where: { $0.id == rowId }) else { return }
        rows[index].title = newValue
        let parsedMinutes = inlineDurationMinutes(from: newValue)
        if let parsedMinutes {
            if rows[index].durationMinutes == nil || rows[index].durationFromInput {
                rows[index].durationMinutes = parsedMinutes
                rows[index].durationFromInput = true
            }
        } else if rows[index].durationFromInput {
            rows[index].durationMinutes = nil
            rows[index].durationFromInput = false
        }
    }

    private func parsedDurationLabel(for row: FocusRow) -> String? {
        guard row.durationFromInput, let minutes = row.durationMinutes else { return nil }
        return shortDurationLabel(minutes: minutes)
    }

    private func durationMinutes(for rowId: UUID) -> Int? {
        rows.first(where: { $0.id == rowId })?.durationMinutes
    }

    private func setDuration(_ rowId: UUID, minutes: Int?) {
        guard let index = rows.firstIndex(where: { $0.id == rowId }) else { return }
        rows[index].durationMinutes = minutes
        rows[index].durationFromInput = false
    }

    private func durationButtonTitle(for row: FocusRow) -> String {
        guard let minutes = row.durationMinutes else { return "—" }
        return shortDurationLabel(minutes: minutes)
    }

    private func finishByTitle(for row: FocusRow) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        switch row.finishBy {
        case .tonight:
            return "Tonight"
        case .tomorrow:
            return "Tomorrow"
        case .next3Days:
            return "Next 3 Days"
        case .thisWeek:
            return "This Week"
        case .none:
            return "None"
        case .pickDate(let date):
            let startNow = calendar.startOfDay(for: now)
            let startDate = calendar.startOfDay(for: date)
            let dayDiff = calendar.dateComponents([.day], from: startNow, to: startDate).day ?? 0
            
            if dayDiff < 0 {
                return Self.shortDateFormatter.string(from: date)
            } else if dayDiff == 0 {
                return "Today"
            } else if dayDiff == 1 {
                return "Tomorrow"
            } else if dayDiff <= 7 {
                return "in \(dayDiff) days"
            } else {
                return Self.shortDateFormatter.string(from: date)
            }
        }
    }

    private func openFinishPicker(for rowId: UUID) {
        if let selection = rows.first(where: { $0.id == rowId })?.finishBy,
           case .pickDate(let date) = selection {
            finishPickerDate = date
        } else {
            finishPickerDate = Date()
        }
        finishPickerTarget = RowPickerTarget(id: rowId)
    }

    private func finishByPickerSheet(rowId: UUID) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 标题区域
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(PixelTheme.forest)
                    
                    Text("设置截止时间")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(PixelTheme.textPrimary)
                }
                .padding(.top, 16)
                
                // 快捷选项
                VStack(spacing: 12) {
                    ForEach([
                        ("今晚", FinishBySelection.tonight, "moon.stars.fill"),
                        ("明天", FinishBySelection.tomorrow, "sun.max.fill"),
                        ("未来3天", FinishBySelection.next3Days, "calendar.badge.clock"),
                        ("本周内", FinishBySelection.thisWeek, "calendar"),
                        ("无截止", FinishBySelection.none, "infinity")
                    ], id: \.0) { title, selection, icon in
                        Button(action: {
                            setFinishBy(rowId, selection: selection)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: icon)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(PixelTheme.textInverted)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(PixelTheme.forest)
                                    )
                                
                                Text(title)
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(PixelTheme.textPrimary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(PixelTheme.woodMedium.opacity(0.6))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(PixelTheme.cardBackground.opacity(0.8))
                                    .shadow(color: PixelTheme.woodMedium.opacity(0.15), radius: 2, x: 1, y: 1)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(PixelTheme.forest.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                Divider()
                    .background(PixelTheme.woodMedium.opacity(0.3))

                // 自定义日期选择器
                VStack(spacing: 12) {
                    Text("自定义日期")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(PixelTheme.textPrimary)
                    
                    DatePicker(
                        "选择日期",
                        selection: $finishPickerDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(PixelTheme.cardBackground.opacity(0.8))
                    )

                    Button("设置日期") {
                        setFinishBy(rowId, selection: .pickDate(finishPickerDate))
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(PixelTheme.textInverted)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(PixelTheme.vitality)
                            .shadow(color: PixelTheme.vitality.opacity(0.4), radius: 4, x: 2, y: 2)
                    )
                }
                .padding(.horizontal, 16)
                
                Spacer()
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        PixelTheme.cream,
                        PixelTheme.forest.opacity(0.1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("截止时间")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func setFinishBy(_ rowId: UUID, selection: FinishBySelection) {
        guard let index = rows.firstIndex(where: { $0.id == rowId }) else { return }
        rows[index].finishBy = selection
        finishPickerTarget = nil
    }

    private func saveToLibrary() {
        let activeRows = validRows
        guard !activeRows.isEmpty else {
            errorMessage = "没有可保存的任务，请检查输入格式。"
            return
        }

        let savedIds = materializeTemplatesForLibrary(from: activeRows)
        guard !savedIds.isEmpty else {
            errorMessage = "部分任务解析失败，请检查输入格式。"
            return
        }

        // Add to library
        for templateId in savedIds {
            libraryStore.add(templateId: templateId)
        }
        
        stateManager.requestSave()
        
        // Clear form and dismiss
        rows = [FocusRow()]
        focusedRowId = rows.first?.id
        dismiss()
    }

    private func addToTimeline() {
        let activeRows = validRows
        guard !activeRows.isEmpty else {
            errorMessage = "没有可添加的任务，请检查输入格式。"
            return
        }
        
        // Validate all rows have duration for timeline insertion
        // Allow nil duration (Flexible Task)
        // guard activeRows.allSatisfy({ $0.durationMinutes != nil }) else { ... }

        let generatedIds = materializeTemplates(from: activeRows)
        guard !generatedIds.isEmpty else {
            errorMessage = "部分任务解析失败，请检查输入格式。"
            return
        }

        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        var insertedCount = 0
        
        for templateId in generatedIds {
            guard cardStore.get(id: templateId) != nil else { continue }
            
            // ALWAYS insert at the front (Next Up) logic as requested.
            // Ignored deadline-based time insertion to prioritize "doing it now".
            let newId: UUID?
            
            if let currentNode = daySession.currentNode {
                // If session is active (or has a current node), insert immediately AFTER it (Next)
                newId = timelineStore.placeCardOccurrence(
                    cardTemplateId: templateId,
                    anchorNodeId: currentNode.id,
                    placement: .after,
                    using: cardStore
                )
            } else if let firstUpcoming = daySession.nodes.first(where: { !$0.isCompleted }) {
                // If idle but has upcoming nodes, insert BEFORE the first upcoming (Top of list)
                newId = timelineStore.placeCardOccurrence(
                    cardTemplateId: templateId,
                    anchorNodeId: firstUpcoming.id,
                    placement: .before,
                    using: cardStore
                )
            } else {
                // Empty or all completed - Append to end
                newId = timelineStore.placeCardOccurrenceAtStart(
                    cardTemplateId: templateId,
                    using: cardStore,
                    engine: engine
                )
            }
            
            if newId != nil {
                insertedCount += 1
            }
        }
        
        if insertedCount > 0 {
            stateManager.requestSave()
            
            // Clear form and dismiss
            rows = [FocusRow()]
            focusedRowId = rows.first?.id
            dismiss()
        } else {
            errorMessage = "无法插入任务到时间线，请检查时间冲突。"
        }
    }

    private func startFocus() {
        let activeRows = validRows
        let libraryIds = selectedLibraryIds.filter { cardStore.get(id: $0) != nil }
        guard !activeRows.isEmpty || !libraryIds.isEmpty else {
            errorMessage = "没有可创建的任务，请检查输入格式。"
            return
        }

        print("DEBUG: startFocus - Valid Rows: \(activeRows.count)")
        let generatedIds = materializeTemplates(from: activeRows)
        let memberIds = libraryIds + generatedIds
        print("DEBUG: MemberIDs count: \(memberIds.count)")
        
        guard !memberIds.isEmpty else {
            errorMessage = "部分任务解析失败，请检查输入格式。"
            return
        }

        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        let newId: UUID?

        if memberIds.count == 1 {
            print("DEBUG: Single member path")
            if let anchorId = daySession.currentNode?.id ?? daySession.nodes.last?.id {
                newId = timelineStore.placeCardOccurrence(
                    cardTemplateId: memberIds[0],
                    anchorNodeId: anchorId,
                    using: cardStore
                )
            } else {
                newId = timelineStore.placeCardOccurrenceAtStart(
                    cardTemplateId: memberIds[0],
                    using: cardStore,
                    engine: engine
                )
            }
        } else {
            print("DEBUG: Group member path")
            if let anchorId = daySession.currentNode?.id ?? daySession.nodes.last?.id {
                newId = timelineStore.placeFocusGroupOccurrence(
                    memberTemplateIds: memberIds,
                    anchorNodeId: anchorId,
                    using: cardStore
                )
            } else {
                print("DEBUG: placeFocusGroupOccurrenceAtStart")
                newId = timelineStore.placeFocusGroupOccurrenceAtStart(
                    memberTemplateIds: memberIds,
                    using: cardStore,
                    engine: engine
                )
            }
        }
        
        print("DEBUG: newId: \(String(describing: newId))")

        if let newId,
           let node = daySession.nodes.first(where: { $0.id == newId }),
           case .battle(let boss) = node.type,
           engine.state == .idle || engine.state == .victory || engine.state == .retreat {
            print("DEBUG: Starting battle")
            daySession.setCurrentNode(id: newId)
            engine.startBattle(boss: boss)
            stateManager.requestSave()
        } else {
            print("DEBUG: Failed to start battle. State: \(engine.state), Node: \(String(describing: newId))")
        }

        rows = [FocusRow()]
        selectedLibraryIds.removeAll()
        focusedRowId = rows.first?.id
        dismiss()
    }
    
    private func startDrag(for row: FocusRow) {
        guard !row.title.isEmpty else { return }
        
        // Create ephemeral template for dragging
        let ids = materializeTemplates(from: [row], isEphemeral: true)
        guard let templateId = ids.first else { return }
        
        draggingFocusRowId = row.id
        let payload = DragPayload(type: .cardTemplate(templateId), source: .library)
        appMode.enter(.dragging(payload))
        dragCoordinator.startDrag(payload: payload)
        Haptics.impact(.medium)
    }

    private func sectionIcon(for title: String) -> String {
        switch title {
        case "Today": return "sun.max.fill"
        case "Next 3 Days": return "calendar.badge.clock"
        case "This Week": return "calendar"
        case "Backlog": return "tray.full.fill"
        case "Expired": return "clock.badge.exclamationmark"
        default: return "folder.fill"
        }
    }

    private func materializeTemplates(from activeRows: [FocusRow]) -> [UUID] {
        return materializeTemplates(from: activeRows, isEphemeral: true)
    }
    
    private func materializeTemplatesForLibrary(from activeRows: [FocusRow]) -> [UUID] {
        return materializeTemplates(from: activeRows, isEphemeral: false)
    }
    
    private func materializeTemplates(from activeRows: [FocusRow], isEphemeral: Bool) -> [UUID] {
        var memberIds: [UUID] = []
        for row in activeRows {
            let cleanedTitle = row.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let parsed = QuickEntryParser.parseDetailed(input: cleanedTitle) else {
                continue
            }
            var template = parsed.template
            if let minutes = row.durationMinutes {
                template.defaultDuration = TimeInterval(minutes * 60)
                template.style = .focus
            } else {
                // Flexible Task (0 duration, passive style)
                template.defaultDuration = 0
                template.style = .passive
            }
            template.deadlineAt = deadlineDate(for: row.finishBy)
            template.isEphemeral = isEphemeral
            cardStore.add(template)
            memberIds.append(template.id)
        }
        return memberIds
    }

    private func deadlineDate(for selection: FinishBySelection) -> Date? {
        let now = Date()
        switch selection {
        case .tonight:
            return endOfDay(for: now)
        case .tomorrow:
            guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) else { return nil }
            return endOfDay(for: tomorrow)
        case .next3Days:
            guard let next3Days = Calendar.current.date(byAdding: .day, value: 3, to: now) else { return nil }
            return endOfDay(for: next3Days)
        case .thisWeek:
            return endOfWeek(for: now)
        case .none:
            return nil
        case .pickDate(let date):
            return endOfDay(for: date)
        }
    }

    private func inlineDurationMinutes(from text: String) -> Int? {
        let pattern = #"(\d+(\.\d+)?)\s*(m|min|h|hr)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return nil }
        var totalMinutes: Double = 0
        for match in matches {
            guard let valueRange = Range(match.range(at: 1), in: text),
                  let unitRange = Range(match.range(at: 3), in: text) else {
                continue
            }
            let valueStr = String(text[valueRange])
            let unitStr = String(text[unitRange]).lowercased()
            guard let value = Double(valueStr) else { continue }
            if unitStr.starts(with: "h") {
                totalMinutes += value * 60
            } else {
                totalMinutes += value
            }
        }
        let rounded = Int(totalMinutes.rounded())
        return rounded > 0 ? rounded : nil
    }

    private func cleanDurationFormats() {
        for index in rows.indices {
            let row = rows[index]
            guard row.durationFromInput, row.durationMinutes != nil else { continue }
            let cleanedTitle = stripDurationTokens(from: row.title)
            rows[index].title = cleanedTitle
            rows[index].durationFromInput = false
        }
    }

    private var totalSelectionCount: Int {
        validRows.count + selectedLibraryIds.count
    }

    private func toggleLibrarySelection(_ id: UUID, isExpired: Bool) {
        guard !isExpired else { return }
        if selectedLibraryIds.contains(id) {
            selectedLibraryIds.remove(id)
        } else {
            selectedLibraryIds.insert(id)
        }
    }

    private var librarySections: [(title: String, rows: [LibraryRowData])] {
        let buckets = libraryStore.bucketedEntries(using: cardStore)
        let today = libraryRows(for: buckets.deadline1)
        let next3 = libraryRows(for: buckets.deadline3)
        let thisWeek = libraryRows(for: mergeThisWeek(buckets.deadline5, buckets.deadline7))
        let later = libraryRows(for: buckets.later)
        let expired = libraryRows(for: buckets.expired)
        return [
            ("Today", today),
            ("Next 3 Days", next3),
            ("This Week", thisWeek),
            ("Backlog", later), // Renamed from Later
            ("Expired", expired)
        ]
    }

    private func libraryRows(for entries: [LibraryEntry]) -> [LibraryRowData] {
        entries.compactMap { entry in
            guard let template = cardStore.get(id: entry.templateId) else { return nil }
            if template.taskMode == .reminderOnly || template.remindAt != nil {
                return nil
            }
            return LibraryRowData(entry: entry, template: template)
        }
        .sorted { lhs, rhs in
            let lhsDate = resolvedDeadlineAt(entry: lhs.entry, template: lhs.template) ?? lhs.entry.addedAt
            let rhsDate = resolvedDeadlineAt(entry: rhs.entry, template: rhs.template) ?? rhs.entry.addedAt
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.entry.addedAt < rhs.entry.addedAt
        }
    }

    private func mergeThisWeek(_ entries: [LibraryEntry]...) -> [LibraryEntry] {
        let combined = entries.flatMap { $0 }
        return combined.sorted { lhs, rhs in
            let lhsTemplate = cardStore.get(id: lhs.templateId)
            let rhsTemplate = cardStore.get(id: rhs.templateId)
            let lhsDate = resolvedDeadlineAt(entry: lhs, template: lhsTemplate) ?? lhs.addedAt
            let rhsDate = resolvedDeadlineAt(entry: rhs, template: rhsTemplate) ?? rhs.addedAt
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.addedAt < rhs.addedAt
        }
    }

    private func resolvedDeadlineAt(entry: LibraryEntry, template: CardTemplate?) -> Date? {
        guard let template else { return nil }
        if let deadlineAt = template.deadlineAt {
            return deadlineAt
        }
        guard let windowDays = template.deadlineWindowDays, windowDays > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: windowDays, to: entry.addedAt)
    }

    private func stripDurationTokens(from text: String) -> String {
        let pattern = #"(\d+(\.\d+)?)\s*(m|min|h|hr)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        let cleaned = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        return cleaned
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func endOfDay(for date: Date) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 23
        components.minute = 59
        components.second = 0
        return Calendar.current.date(from: components)
    }

    private func endOfWeek(for date: Date) -> Date? {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 1
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) else {
            return nil
        }
        return endOfDay(for: lastDay)
    }

    private func shortDurationLabel(minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            if remainder == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remainder)m"
        }
        return "\(minutes)m"
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

private struct FocusRowView: View {
    @Binding var title: String
    let parsedDuration: String?
    let durationTitle: String
    let finishByTitle: String
    let onDurationTap: () -> Void
    let onFinishTap: () -> Void
    let onSubmit: () -> Void
    let onDragStart: () -> Void
    let isDragged: Bool
    let dragOffset: CGSize
    let focusedRowId: FocusState<UUID?>.Binding
    let rowId: UUID
    let rowIndex: Int

    var body: some View {
        mainContent
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(backgroundView)
            .scaleEffect(isDragged ? 1.05 : 1.0)
            .shadow(color: isDragged ? Color.black.opacity(0.2) : .clear, radius: isDragged ? 8 : 0)
            .offset(
                x: isDragged ? dragOffset.width : 0,
                y: isDragged ? dragOffset.height : 0
            )
            .zIndex(isDragged ? 100 : 0)
            .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 10) {
                onDragStart()
            }
    }
    
    private var mainContent: some View {
        HStack(spacing: 10) {
            inputSection
            durationButton
            finishButton
        }
    }
    
    private var inputSection: some View {
        HStack(spacing: 6) {
            // Seed Icon
            Image(systemName: "leaf.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(PixelTheme.forest)
            
            TextField("种下一颗种子…", text: $title)
                .font(.system(.body, design: .rounded))
                .foregroundColor(PixelTheme.textPrimary)
                .focused(focusedRowId, equals: rowId)
                .submitLabel(.next)
                .onSubmit {
                    onSubmit()
                }
                .accessibilityIdentifier("focusRowTitle_\(rowIndex)")
            
            if let parsedDuration {
                Text(parsedDuration)
                    .font(.system(.caption2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(PixelTheme.textInverted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(PixelTheme.forest)
                            .shadow(color: PixelTheme.forest.opacity(0.3), radius: 2, x: 1, y: 1)
                    )
                    .accessibilityIdentifier("focusRowParsedDuration_\(rowIndex)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var durationButton: some View {
        let isSet = durationTitle != "—"
        return Button(action: onDurationTap) {
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(durationTitle)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
            }
            .foregroundColor(isSet ? PixelTheme.textInverted : PixelTheme.textPrimary.opacity(0.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSet ? PixelTheme.vitality : PixelTheme.cardBackground.opacity(0.3))
                    .shadow(color: isSet ? PixelTheme.vitality.opacity(0.3) : Color.clear, radius: 2, x: 1, y: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("focusRowDuration_\(rowIndex)")
    }
    
    private var finishButton: some View {
        Button(action: onFinishTap) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .bold))
                Text(finishByTitle)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
            }
            .foregroundColor(PixelTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(PixelTheme.cardBackground.opacity(0.9))
                    .shadow(color: PixelTheme.woodMedium.opacity(0.2), radius: 2, x: 1, y: 1)
                    .overlay(
                        Capsule()
                            .stroke(PixelTheme.woodMedium.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("focusRowFinish_\(rowIndex)")
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(PixelTheme.cardBackground.opacity(0.8))
            .shadow(color: PixelTheme.woodMedium.opacity(0.15), radius: 3, x: 2, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(PixelTheme.forest.opacity(0.2), lineWidth: 1)
            )
    }
}

private struct LibraryRowData: Identifiable {
    let entry: LibraryEntry
    let template: CardTemplate

    var id: UUID {
        template.id
    }
}

private struct LibraryRowView: View {
    let data: LibraryRowData
    let isSelected: Bool
    let onToggle: () -> Void
    
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var dragCoordinator: DragDropCoordinator

    private var isDraggingThis: Bool {
        if let payload = dragCoordinator.activePayload,
           case .cardTemplate(let id) = payload.type,
           id == data.template.id {
            return true
        }
        return false
    }
    
    private var isExpired: Bool {
        data.entry.deadlineStatus == .expired
    }

    var body: some View {
        mainContent
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(backgroundView)
            .scaleEffect(isDraggingThis ? 1.05 : 1.0)
            .shadow(color: isDraggingThis ? Color.black.opacity(0.2) : .clear, radius: isDraggingThis ? 8 : 0)
            .offset(
                x: isDraggingThis ? dragCoordinator.dragOffset.width : 0,
                y: isDraggingThis ? dragCoordinator.dragOffset.height : 0
            )
            .zIndex(isDraggingThis ? 100 : 0)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isExpired else { return }
                onToggle()
            }
            .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 10, perform: handleDrag)
    }
    
    private var mainContent: some View {
        HStack(spacing: 12) {
            // Checkbox
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(isSelected ? PixelTheme.forest : PixelTheme.woodMedium.opacity(0.5))

            // Icon
            Image(systemName: data.template.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(pixelColor(for: data.template.id))
                        .shadow(color: pixelColor(for: data.template.id).opacity(0.3), radius: 2, x: 1, y: 1)
                )

            // Text Info
            textInfoView
            
            Spacer()
            
            // Expired Indicator
            if isExpired {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12))
                    .foregroundColor(PixelTheme.woodMedium.opacity(0.3))
            }
        }
    }
    
    private var textInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.template.title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(isExpired ? PixelTheme.textPrimary.opacity(0.4) : PixelTheme.textPrimary)
                .lineLimit(1)
            
            HStack(spacing: 8) {
                // Duration
                HStack(spacing: 2) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 8))
                        .foregroundColor(PixelTheme.vitality)
                    Text("\(Int(data.template.defaultDuration / 60)) 分钟")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(PixelTheme.textPrimary.opacity(0.8))
                }
                
                // Deadline
                if let deadlineText = deadlineLabel(now: Date()) {
                    HStack(spacing: 2) {
                        Image(systemName: isExpired ? "exclamationmark.triangle.fill" : "calendar")
                            .font(.system(size: 8))
                            .foregroundColor(isExpired ? PixelTheme.vitality : PixelTheme.forest)
                        Text(deadlineText)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(isExpired ? PixelTheme.vitality : PixelTheme.forest)
                    }
                }
            }
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(PixelTheme.cardBackground.opacity(isExpired ? 0.3 : 0.8))
            .shadow(color: PixelTheme.woodMedium.opacity(isExpired ? 0.1 : 0.15), radius: 2, x: 1, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ?
                        PixelTheme.forest.opacity(0.6) :
                        PixelTheme.woodMedium.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
    }

    private func handleDrag() {
        guard !isExpired else { return }
        let payload = DragPayload(type: .cardTemplate(data.template.id), source: .library)
        appMode.enter(.dragging(payload))
        dragCoordinator.startDrag(payload: payload)
        Haptics.impact(.medium)
    }

    private func deadlineLabel(now: Date) -> String? {
        guard let deadlineAt = resolvedDeadlineAt() else { return nil }
        if data.entry.deadlineStatus == .expired {
            return "已过期"
        }
        let calendar = Calendar.current
        let startNow = calendar.startOfDay(for: now)
        let startDeadline = calendar.startOfDay(for: deadlineAt)
        let dayDiff = calendar.dateComponents([.day], from: startNow, to: startDeadline).day ?? 0
        if dayDiff < 0 {
            return "已过期"
        }
        if dayDiff == 0 {
            return "今天截止"
        }
        if dayDiff == 1 {
            return "明天截止"
        }
        return "\(dayDiff) 天后截止"
    }

    private func resolvedDeadlineAt() -> Date? {
        if let deadlineAt = data.template.deadlineAt {
            return deadlineAt
        }
        guard let windowDays = data.template.deadlineWindowDays, windowDays > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: windowDays, to: data.entry.addedAt)
    }
    
    private func pixelColor(for templateId: UUID) -> Color {
        // 像素治愈风格的自然色系
        let hash = templateId.hashValue
        let colors: [Color] = [
            PixelTheme.forest,     // 森林绿
            PixelTheme.vitality,   // 活力橘
            PixelTheme.woodDark,   // 木纹棕
            Color(red: 0.2, green: 0.6, blue: 0.8),       // 天蓝色 (学习)
            Color(red: 0.8, green: 0.4, blue: 0.6),       // 粉紫色 (创作)
            Color(red: 0.6, green: 0.8, blue: 0.4),       // 草绿色 (家务)
        ]
        return colors[abs(hash) % colors.count]
    }
}

private struct DurationPickerSheet: View {
    let currentMinutes: Int?
    let onSelect: (Int?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var customMinutes: Int

    init(currentMinutes: Int?, onSelect: @escaping (Int?) -> Void) {
        self.currentMinutes = currentMinutes
        self.onSelect = onSelect
        _customMinutes = State(initialValue: currentMinutes ?? 25)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 标题区域
                VStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(PixelTheme.vitality)
                    
                    Text("设置专注时长")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(PixelTheme.textPrimary)
                }
                .padding(.top, 16)

                // 预设时长按钮
                let presets = [15, 25, 30, 45, 60, 90, 120]
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(presets, id: \.self) { minutes in
                        Button("\(minutes) 分钟") {
                            onSelect(minutes)
                            dismiss()
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(PixelTheme.textInverted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(PixelTheme.forest)
                                .shadow(color: PixelTheme.forest.opacity(0.3), radius: 3, x: 2, y: 2)
                        )
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                Divider()
                    .background(PixelTheme.woodMedium.opacity(0.3))

                // 自定义时长选择器
                VStack(spacing: 12) {
                    Text("自定义时长")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(PixelTheme.textPrimary)
                    
                    Picker("自定义", selection: $customMinutes) {
                        ForEach(1...240, id: \.self) { minutes in
                            Text("\(minutes) 分钟").tag(minutes)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 140)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(PixelTheme.cardBackground.opacity(0.8))
                    )
                }

                // 操作按钮
                HStack(spacing: 16) {
                    Button("清除") {
                        onSelect(nil)
                        dismiss()
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(PixelTheme.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(PixelTheme.cardBackground.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(PixelTheme.woodMedium.opacity(0.3), lineWidth: 1)
                            )
                    )

                    Button("确定") {
                        onSelect(customMinutes)
                        dismiss()
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(PixelTheme.textInverted)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(PixelTheme.vitality)
                            .shadow(color: PixelTheme.vitality.opacity(0.4), radius: 4, x: 2, y: 2)
                    )
                }
                .padding(.horizontal, 16)
                
                Spacer()
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        PixelTheme.cream,
                        PixelTheme.forest.opacity(0.1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("专注时长")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
