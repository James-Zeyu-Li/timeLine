import SwiftUI
import Foundation
import TimeLineCore

// MARK: - Backlog Tab

struct LibraryTabView: View {
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var libraryStore: LibraryStore
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var dragCoordinator: DragDropCoordinator
    
    @State private var isSelecting = false
    @State private var selectedIds: Set<UUID> = []
    @State private var showCardPicker = false
    @State private var wasDragging = false
    @State private var showExpired = true
    @State private var showExpiredBanner = false
    @State private var itemFrames: [UUID: CGRect] = [:]
    @State private var groupFrame: CGRect = .zero
    
    var body: some View {
        let buckets = libraryStore.bucketedEntries(using: cardStore)
        let reminders = rows(for: buckets.reminders)
        let today = rows(for: buckets.today)
        let shortTerm = rows(for: buckets.shortTerm)
        let longTerm = rows(for: buckets.longTerm)
        let frozen = rows(for: buckets.frozen)
        
        VStack(spacing: 12) {
            header
            
            if reminders.isEmpty && today.isEmpty && shortTerm.isEmpty && longTerm.isEmpty && frozen.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            if !reminders.isEmpty {
                                section(title: "Reminders", rows: reminders)
                            }
                            if !today.isEmpty {
                                section(title: "Today & Urgent", rows: today)
                            }
                            if !shortTerm.isEmpty {
                                section(title: "Upcoming (3-10 days)", rows: shortTerm)
                            }
                            if !longTerm.isEmpty {
                                section(title: "Long Term", rows: longTerm)
                            }
                            if !frozen.isEmpty {
                                section(title: "Frozen (Stale)", rows: frozen)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, isSelecting ? 70 : 20)
                    }
                }
            }
            
            if isSelecting {
                selectionBar
            }
        }
        .sheet(isPresented: $showCardPicker) {
            CardLibraryPickerSheet(title: "Add from Cards")
        }
        .onChange(of: appMode.mode) { _, newMode in
            if case .dragging = newMode {
                wasDragging = true
                return
            }
            if wasDragging {
                wasDragging = false
                if isSelecting {
                    exitSelection()
                }
            }
        }
        .onAppear {
            let expiredCount = libraryStore.refreshDeadlineStatuses(using: cardStore)
            if expiredCount > 0 {
                showExpiredBanner = true
            }
        }
        .onPreferenceChange(OverlayItemFramePreferenceKey.self) { frames in
            self.itemFrames = frames
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Backlog")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text("Pick or drag tasks onto the map")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            HStack(spacing: 8) {
                // Quick List Removed

                Button("Add from Cards") {
                    showCardPicker = true
                }
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.cyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.cyan.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                        )
                )
                
                Button(isSelecting ? "Cancel" : "Select") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        if isSelecting {
                            exitSelection()
                        } else {
                            isSelecting = true
                        }
                    }
                }
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(isSelecting ? .white : .cyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelecting ? Color.white.opacity(0.15) : Color.cyan.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(isSelecting ? Color.white.opacity(0.2) : Color.cyan.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var selectionBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Button {
                    addSelectedToGroup()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.stack.3d.up")
                            .font(.system(size: 12, weight: .bold))
                        Text("Add to Group")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(selectedIds.isEmpty ? .gray : .cyan)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(selectedIds.isEmpty ? Color.white.opacity(0.08) : Color.cyan.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(Color.cyan.opacity(selectedIds.isEmpty ? 0.15 : 0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(selectedIds.isEmpty)
            }
            
            if selectedIds.count > 1 {
                groupDragToken
            }
            
            Text("选中 ≥2 会出现拖拽组，拖到地图插入；快速追加放到末尾")
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.bottom, 24)
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Backlog is empty")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.white)
            Text("Create a card to add it here.")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.top, 40)
    }
    
    private func section(title: String, rows: [LibraryRowData]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.7))
            
            ForEach(rows) { row in
                rowView(for: row)
            }
        }
    }

    @ViewBuilder
    private func expiredSection(rows: [LibraryRowData]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    showExpired.toggle()
                }
            } label: {
                HStack {
                    Text("Expired · \(rows.count)")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: showExpired ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)

            if showExpired {
                if rows.isEmpty {
                    Text("No expired tasks")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.leading, 8)
                } else {
                    ForEach(rows) { row in
                        rowView(for: row)
                    }
                }
            }
        }
    }

    private func expiredBanner(onView: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Text("一个任务已枯萎，已移至 Expired。")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            Button("View") {
                onView()
            }
            .font(.system(.caption, design: .rounded))
            .foregroundColor(.cyan)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func rowView(for row: LibraryRowData) -> some View {
        let rowView = LibraryRow(
            entry: row.entry,
            template: row.template,
            isSelecting: isSelecting,
            isSelected: selectedIds.contains(row.id),
            onToggle: {
                toggleSelection(row.id)
            },
            onEdit: {
                appMode.enterCardEdit(cardTemplateId: row.id)
            }
        )
        if isSelecting {
            rowView
        } else {
            rowView
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: OverlayItemFramePreferenceKey.self, value: [row.template.id: proxy.frame(in: .global)])
                    }
                )
                .gesture(cardDragGesture(for: row.template))
        }
    }
    
    private func rows(for entries: [LibraryEntry]) -> [LibraryRowData] {
        entries.compactMap { entry in
            guard let template = cardStore.get(id: entry.templateId) else { return nil }
            return LibraryRowData(entry: entry, template: template)
        }
    }

    private func mergeThisWeek(_ entries: [LibraryEntry]...) -> [LibraryEntry] {
        let combined = entries.flatMap { $0 }
        return combined.sorted { lhs, rhs in
            let lhsDate = deadlineAt(for: lhs) ?? lhs.addedAt
            let rhsDate = deadlineAt(for: rhs) ?? rhs.addedAt
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.addedAt < rhs.addedAt
        }
    }

    private func deadlineAt(for entry: LibraryEntry) -> Date? {
        guard let template = cardStore.get(id: entry.templateId) else { return nil }
        if let deadlineAt = template.deadlineAt {
            return deadlineAt
        }
        guard let windowDays = template.deadlineWindowDays else { return nil }
        return Calendar.current.date(byAdding: .day, value: windowDays, to: entry.addedAt)
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func exitSelection() {
        selectedIds.removeAll()
        isSelecting = false
    }

    private func addSelectedToGroup() {
        let memberIds = orderedSelection()
        guard !memberIds.isEmpty else { return }

        let shouldAutoStart = ProcessInfo.processInfo.environment["EMPTY_TIMELINE"] == "1"
        if shouldAutoStart {
            daySession.nodes.removeAll()
            daySession.currentIndex = 0
        }
        
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        let newId: UUID?
        if let anchorId = daySession.nodes.last?.id {
            newId = timelineStore.placeFocusGroupOccurrence(
                memberTemplateIds: memberIds,
                anchorNodeId: anchorId,
                using: cardStore
            )
        } else {
            newId = timelineStore.placeFocusGroupOccurrenceAtStart(
                memberTemplateIds: memberIds,
                using: cardStore,
                engine: engine
            )
        }

        if shouldAutoStart, let newId,
           let node = daySession.nodes.first(where: { $0.id == newId }),
           case .battle(let boss) = node.type {
            daySession.setCurrentNode(id: newId)
            engine.startBattle(boss: boss)
            stateManager.requestSave()
        }
        
        Haptics.impact(.heavy)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            exitSelection()
        }
    }
    
    private func orderedSelection() -> [UUID] {
        let ordered = libraryStore.orderedEntries().map(\.templateId)
        let selected = ordered.filter { selectedIds.contains($0) }
        if !selected.isEmpty {
            return selected
        }
        return Array(selectedIds)
    }
    
    private func cardDragGesture(for template: CardTemplate) -> some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                guard !isSelecting else { return }
                switch value {
                case .second(true, let drag?):
                    if !appMode.isDragging {
                        let frame = itemFrames[template.id] ?? .zero
                        let center = CGPoint(x: frame.midX, y: frame.midY)
                        let start = drag.startLocation
                        let offset = CGSize(width: center.x - start.x, height: center.y - start.y)
                        
                        let payload = DragPayload(type: .cardTemplate(template.id), source: .library, initialOffset: offset)
                        appMode.enter(.dragging(payload))
                        dragCoordinator.startDrag(payload: payload)
                    }
                    dragCoordinator.dragLocation = drag.location
                default:
                    break
                }
            }
            .onEnded { _ in
                dragCoordinator.isDragEnded = true
            }
    }

    private var groupDragToken: some View {
        let memberIds = orderedSelection()
        return HStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 12, weight: .bold))
            Text("Drag Group · \(memberIds.count)")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.cyan.opacity(0.35))
                .overlay(
                    Capsule()
                        .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
                )
        )
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { groupFrame = proxy.frame(in: .global) }
                    .onChange(of: proxy.frame(in: .global)) { _, newFrame in groupFrame = newFrame }
            }
        )
        .gesture(groupDragGesture(memberIds: memberIds))
    }

    private func groupDragGesture(memberIds: [UUID]) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { value in
                guard !memberIds.isEmpty else { return }
                if !appMode.isDragging {
                    let frame = groupFrame
                    let center = CGPoint(x: frame.midX, y: frame.midY)
                    let start = value.startLocation
                    let offset = CGSize(width: center.x - start.x, height: center.y - start.y)
                    
                    let payload = DragPayload(type: .focusGroup(memberIds), source: .library, initialOffset: offset)
                    appMode.enter(.dragging(payload))
                    if appMode.isDragging {
                        dragCoordinator.startDrag(payload: payload)
                    } else {
                        return
                    }
                }
                dragCoordinator.dragLocation = value.location
            }
            .onEnded { _ in
                dragCoordinator.isDragEnded = true
            }
    }
}

private struct LibraryRowData: Identifiable {
    let entry: LibraryEntry
    let template: CardTemplate
    
    var id: UUID {
        template.id
    }
}

private struct LibraryRow: View {
    let entry: LibraryEntry
    let template: CardTemplate
    let isSelecting: Bool
    let isSelected: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        let now = Date()
        let isReminder = template.taskMode == .reminderOnly || template.remindAt != nil
        let deadlineText = deadlineLabel(now: now)
        let reminderText = reminderLabel(now: now)
        let isExpired = entry.deadlineStatus == .expired
        let isUrgent = isUrgentDeadline(now: now)
        let isStale = isStaleEntry(now: now)
        let titleColor: Color = isExpired ? .gray : (isStale ? .white.opacity(0.6) : .white)
        HStack(spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .cyan : .gray)
            }
            
            Image(systemName: template.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(template.title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(titleColor)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if !isReminder {
                        Text("\(Int(template.defaultDuration / 60)) min")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    if !isReminder && template.repeatRule != .none {
                        Text(repeatLabel(for: template.repeatRule))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.cyan)
                    }
                    if let deadlineText {
                        Text(deadlineText)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(isExpired ? .gray : .orange)
                    } else if let reminderText {
                        Text(reminderText)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.orange)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isStale ? 0.03 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.cyan.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(urgentPulseOpacity(isUrgent: isUrgent)), lineWidth: 1)
        )
        .saturation(isStale ? 0.35 : 1.0)
        .onAppear {
            startUrgentPulseIfNeeded(isUrgent: isUrgent)
        }
        .onChange(of: isUrgent) { _, newValue in
            startUrgentPulseIfNeeded(isUrgent: newValue)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelecting {
                onToggle()
            } else {
                onEdit()
            }
        }
    }
    
    private func repeatLabel(for rule: RepeatRule) -> String {
        switch rule {
        case .none:
            return ""
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        }
    }
    
    private func deadlineLabel(now: Date) -> String? {
        guard template.taskMode != .reminderOnly else { return nil }
        guard let deadlineAt = resolvedDeadlineAt() else { return nil }
        if entry.deadlineStatus == .expired {
            return "Expired"
        }
        let calendar = Calendar.current
        let startNow = calendar.startOfDay(for: now)
        let startDeadline = calendar.startOfDay(for: deadlineAt)
        let dayDiff = calendar.dateComponents([.day], from: startNow, to: startDeadline).day ?? 0
        if dayDiff < 0 {
            return "Expired"
        }
        if dayDiff == 0 {
            return "Due today"
        }
        if dayDiff == 1 {
            return "Due tomorrow"
        }
        return "Due in \(dayDiff) days"
    }

    private func reminderLabel(now: Date) -> String? {
        guard template.taskMode == .reminderOnly || template.remindAt != nil else { return nil }
        guard let remindAt = template.remindAt else { return "reminder" }
        let timeLabel = Self.reminderTimeFormatter.string(from: remindAt)
        if let remaining = CountdownFormatter.formatRelative(seconds: remindAt.timeIntervalSince(now)) {
            return "at \(timeLabel) · \(remaining)"
        }
        return "at \(timeLabel)"
    }

    private static let reminderTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    @State private var urgentPulse = false

    private func urgentPulseOpacity(isUrgent: Bool) -> Double {
        guard isUrgent else { return 0 }
        return urgentPulse ? 0.85 : 0.25
    }

    private func startUrgentPulseIfNeeded(isUrgent: Bool) {
        if isUrgent && !urgentPulse {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                urgentPulse = true
            }
        }
        if !isUrgent {
            urgentPulse = false
        }
    }

    private func isUrgentDeadline(now: Date) -> Bool {
        guard template.taskMode != .reminderOnly else { return false }
        guard entry.deadlineStatus == .active else { return false }
        guard let deadlineAt = resolvedDeadlineAt() else { return false }
        let calendar = Calendar.current
        let startNow = calendar.startOfDay(for: now)
        let startDeadline = calendar.startOfDay(for: deadlineAt)
        let dayDiff = calendar.dateComponents([.day], from: startNow, to: startDeadline).day ?? 0
        return dayDiff == 0
    }

    private func isStaleEntry(now: Date) -> Bool {
        guard template.taskMode != .reminderOnly else { return false }
        guard entry.deadlineStatus == .active else { return false }
        guard template.deadlineWindowDays == nil && template.deadlineAt == nil else { return false }
        guard let staleDate = Calendar.current.date(byAdding: .day, value: -7, to: now) else { return false }
        return entry.addedAt < staleDate
    }

    private func resolvedDeadlineAt() -> Date? {
        if let deadlineAt = template.deadlineAt {
            return deadlineAt
        }
        guard let windowDays = template.deadlineWindowDays else { return nil }
        return Calendar.current.date(byAdding: .day, value: windowDays, to: entry.addedAt)
    }
}
