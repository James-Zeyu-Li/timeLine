import SwiftUI
import TimeLineCore

struct FocusListSheet: View {
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var cardStore: CardTemplateStore
    @Environment(\.dismiss) private var dismiss

    @State private var rows: [FocusRow] = [FocusRow()]
    @State private var errorMessage: String?
    @State private var showActiveBattleConfirm = false
    @State private var durationPickerTarget: RowPickerTarget?
    @State private var finishPickerTarget: RowPickerTarget?
    @State private var finishPickerDate = Date()
    @FocusState private var focusedRowId: UUID?

    private enum FinishBySelection: Equatable {
        case tonight
        case tomorrow
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
            finishBy = .tonight
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
                    .foregroundColor(.orange)
            }
            actionBar
        }
        .padding(20)
        .accessibilityIdentifier("focusListSheet")
        .onAppear {
            if focusedRowId == nil {
                focusedRowId = rows.first?.id
            }
        }
        .confirmationDialog(
            "End current battle?",
            isPresented: $showActiveBattleConfirm,
            titleVisibility: .visible
        ) {
            Button("End & Start New Focus", role: .destructive) {
                startFocus()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You already have an active battle. Starting a new Focus List will end the current one.")
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
                Text("Focus List")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                Spacer()
                Button("Clean format") {
                    cleanDurationFormats()
                }
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.cyan)
                .buttonStyle(.plain)
            }
            Text("每行一个任务，分别设置时长与截止")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.gray)
            Text("输入如 Math 45m 会自动填充 Duration（稍后可清理格式）")
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusLine: some View {
        let validCount = validRows.count
        guard validCount > 0 else { return AnyView(EmptyView()) }
        let missingCount = missingDurationCount
        let summary = "Valid \(validCount) · Missing duration \(missingCount)"
        return AnyView(
            HStack {
                Text(summary)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
        )
    }

    private var rowsList: some View {
        List {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                FocusRowView(
                    title: titleBinding(for: row),
                    parsedDuration: parsedDurationLabel(for: row),
                    durationTitle: durationButtonTitle(for: row),
                    finishByTitle: finishByTitle(for: row),
                    onDurationTap: { durationPickerTarget = RowPickerTarget(id: row.id) },
                    onFinishTap: { openFinishPicker(for: row.id) },
                    onSubmit: { handleSubmit(for: row.id) },
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
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            Button {
                addRowAndFocus()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add task")
                        .font(.system(.subheadline, design: .rounded))
                }
                .foregroundColor(.cyan)
                .padding(.vertical, 4)
            }
            .accessibilityIdentifier("focusListAddRow")
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(minHeight: 200, maxHeight: 280)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                dismiss()
            }
            .font(.system(.caption, design: .rounded))
            .foregroundColor(.gray)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(Color.white.opacity(0.08))
            )
            .accessibilityIdentifier("focusListCancelButton")

            Button(startButtonTitle) {
                if isActiveBattle {
                    showActiveBattleConfirm = true
                } else {
                    startFocus()
                }
            }
            .font(.system(.caption, design: .rounded))
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(Color.cyan.opacity(canStart ? 0.9 : 0.3))
            )
            .disabled(!canStart)
            .accessibilityIdentifier("focusListStartButton")
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var validRows: [FocusRow] {
        rows.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var missingDurationCount: Int {
        validRows.filter { $0.durationMinutes == nil }.count
    }

    private var canStart: Bool {
        !validRows.isEmpty
    }

    private var startButtonTitle: String {
        validRows.count > 1 ? "Start Group Focus" : "Start Focus"
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
        switch row.finishBy {
        case .tonight:
            return "Tonight"
        case .tomorrow:
            return "Tomorrow"
        case .thisWeek:
            return "This Week"
        case .none:
            return "None"
        case .pickDate(let date):
            return Self.shortDateFormatter.string(from: date)
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
            VStack(spacing: 12) {
                Button("Tonight") {
                    setFinishBy(rowId, selection: .tonight)
                }
                Button("Tomorrow") {
                    setFinishBy(rowId, selection: .tomorrow)
                }
                Button("This Week") {
                    setFinishBy(rowId, selection: .thisWeek)
                }
                Button("None") {
                    setFinishBy(rowId, selection: .none)
                }

                Divider()

                DatePicker(
                    "Pick Date",
                    selection: $finishPickerDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, 8)

                Button("Set Date") {
                    setFinishBy(rowId, selection: .pickDate(finishPickerDate))
                }
                .font(.system(.subheadline, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.cyan.opacity(0.8)))
                .foregroundColor(.white)
            }
            .padding(.vertical, 12)
            .navigationTitle("Finish by")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func setFinishBy(_ rowId: UUID, selection: FinishBySelection) {
        guard let index = rows.firstIndex(where: { $0.id == rowId }) else { return }
        rows[index].finishBy = selection
        finishPickerTarget = nil
    }

    private func startFocus() {
        let activeRows = validRows
        guard !activeRows.isEmpty else {
            errorMessage = "没有可创建的任务，请检查输入格式。"
            return
        }

        let memberIds = materializeTemplates(from: activeRows)
        guard !memberIds.isEmpty else {
            errorMessage = "部分任务解析失败，请检查输入格式。"
            return
        }

        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        let newId: UUID?

        if memberIds.count == 1 {
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
            if let anchorId = daySession.currentNode?.id ?? daySession.nodes.last?.id {
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
        }

        if let newId,
           let node = daySession.nodes.first(where: { $0.id == newId }),
           case .battle(let boss) = node.type,
           engine.state == .idle || engine.state == .victory || engine.state == .retreat {
            daySession.setCurrentNode(id: newId)
            engine.startBattle(boss: boss)
            stateManager.requestSave()
        }

        rows = [FocusRow()]
        focusedRowId = rows.first?.id
        dismiss()
    }

    private func materializeTemplates(from activeRows: [FocusRow]) -> [UUID] {
        var memberIds: [UUID] = []
        for row in activeRows {
            guard let parsed = QuickEntryParser.parseDetailed(input: row.title) else {
                continue
            }
            var template = parsed.template
            let minutes = row.durationMinutes ?? 25
            template.defaultDuration = TimeInterval(minutes * 60)
            template.deadlineAt = deadlineDate(for: row.finishBy)
            template.isEphemeral = true
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
    let focusedRowId: FocusState<UUID?>.Binding
    let rowId: UUID
    let rowIndex: Int

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                TextField("Task…", text: $title)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.white)
                    .focused(focusedRowId, equals: rowId)
                    .submitLabel(.next)
                    .onSubmit {
                        onSubmit()
                    }
                    .accessibilityIdentifier("focusRowTitle_\(rowIndex)")
                if let parsedDuration {
                    Text(parsedDuration)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.cyan.opacity(0.15))
                        )
                        .accessibilityIdentifier("focusRowParsedDuration_\(rowIndex)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDurationTap) {
                Text(durationTitle)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(durationTitle == "—" ? .gray : .black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(durationTitle == "—" ? Color.white.opacity(0.08) : Color.cyan)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("focusRowDuration_\(rowIndex)")

            Button(action: onFinishTap) {
                Text(finishByTitle)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.white.opacity(0.9))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("focusRowFinish_\(rowIndex)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
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
            VStack(spacing: 12) {
                Text("Duration")
                    .font(.system(.headline, design: .rounded))

                let presets = [15, 25, 30, 45, 60, 90, 120]
                VStack(spacing: 8) {
                    ForEach(presets, id: \.self) { minutes in
                        Button("\(minutes)m") {
                            onSelect(minutes)
                            dismiss()
                        }
                        .font(.system(.subheadline, design: .rounded))
                    }
                }

                Divider()

                Picker("Custom", selection: $customMinutes) {
                    ForEach(1...240, id: \.self) { minutes in
                        Text("\(minutes)m").tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 140)

                HStack(spacing: 12) {
                    Button("Clear") {
                        onSelect(nil)
                        dismiss()
                    }
                    .foregroundColor(.gray)

                    Button("Set") {
                        onSelect(customMinutes)
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.cyan.opacity(0.8)))
                }
            }
            .padding(.vertical, 12)
            .navigationTitle("Duration")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
