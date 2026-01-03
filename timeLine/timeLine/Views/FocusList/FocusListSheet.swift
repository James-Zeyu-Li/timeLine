import SwiftUI
import TimeLineCore

struct FocusListSheet: View {
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var focusListStore: FocusListStore
    @Environment(\.dismiss) private var dismiss

    @State private var inputText: String = ""
    @State private var errorMessage: String?
    @State private var showActiveBattleConfirm = false

    var body: some View {
        VStack(spacing: 16) {
            header
            inputArea
            addButton
            stagedList
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.orange)
            }
            actionBar
        }
        .padding(20)
        .confirmationDialog(
            "End current battle?",
            isPresented: $showActiveBattleConfirm,
            titleVisibility: .visible
        ) {
            Button("End & Start New Focus", role: .destructive) {
                startFocusGroup()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You already have an active battle. Starting a new Focus List will end the current one.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Focus List")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
            Text("每行一个任务（支持 30m / @study / 每天 / 明天 / 今晚）")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputArea: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $inputText)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.white)
                .padding(8)
                .frame(minHeight: 160)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                )

            if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("例：数学 30m\n英语 45m @study\n今晚 1h 练琴")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
        }
    }

    private var addButton: some View {
        Button("Add to List") {
            stageInputIfNeeded()
        }
        .font(.system(.caption, design: .rounded))
        .fontWeight(.semibold)
        .foregroundColor(canAdd ? .white : .gray)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(Color.cyan.opacity(canAdd ? 0.22 : 0.08))
        )
        .disabled(!canAdd)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stagedList: some View {
        let items = focusListStore.items
        if items.isEmpty {
            return AnyView(EmptyView())
        }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("Staged")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        FocusListRow(
                            title: itemTitle(item),
                            durationText: itemDuration(item),
                            onRemove: {
                                focusListStore.remove(id: item.id)
                            }
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

            Button("Start Focus") {
                if isActiveBattle {
                    showActiveBattleConfirm = true
                } else {
                    startFocusGroup()
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
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var canStart: Bool {
        canAdd || !focusListStore.items.isEmpty
    }

    private var canAdd: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isActiveBattle: Bool {
        switch engine.state {
        case .fighting, .paused, .frozen:
            return true
        default:
            return false
        }
    }

    private func startFocusGroup() {
        stageInputIfNeeded()
        let templates = parseInputTemplates()
        let memberIds = buildMemberIds(templates: templates)

        guard !memberIds.isEmpty else {
            errorMessage = "没有可创建的任务，请检查输入格式。"
            return
        }
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        let newId: UUID?

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

        if let newId,
           let node = daySession.nodes.first(where: { $0.id == newId }),
           case .battle(let boss) = node.type,
           engine.state == .idle || engine.state == .victory || engine.state == .retreat {
            daySession.setCurrentNode(id: newId)
            engine.startBattle(boss: boss)
            stateManager.requestSave()
        }

        focusListStore.clear()
        inputText = ""
        dismiss()
    }

    private func stageInputIfNeeded() {
        let templates = parseInputTemplates()
        guard !templates.isEmpty else { return }
        templates.forEach { template in
            focusListStore.add(FocusListItem(source: .adHoc(template)))
        }
        inputText = ""
    }

    private func parseInputTemplates() -> [CardTemplate] {
        let lines = inputText
            .split(whereSeparator: \.isNewline)
            .map { String($0) }
        var results: [CardTemplate] = []
        for line in lines {
            guard let parsed = QuickEntryParser.parseDetailed(input: line) else { continue }
            var template = parsed.template
            template.isEphemeral = true
            results.append(template)
        }
        return results
    }

    private func buildMemberIds(templates: [CardTemplate]) -> [UUID] {
        var memberIds: [UUID] = []

        templates.forEach { template in
            cardStore.add(template)
            memberIds.append(template.id)
        }

        for item in focusListStore.items {
            switch item.source {
            case .template(let id):
                if cardStore.get(id: id) != nil {
                    memberIds.append(id)
                }
            case .adHoc(let template):
                cardStore.add(template)
                memberIds.append(template.id)
            }
        }

        return memberIds
    }

    private func itemTitle(_ item: FocusListItem) -> String {
        switch item.source {
        case .template(let id):
            return cardStore.get(id: id)?.title ?? "Missing Card"
        case .adHoc(let template):
            return template.title
        }
    }

    private func itemDuration(_ item: FocusListItem) -> String {
        let seconds: TimeInterval
        switch item.source {
        case .template(let id):
            seconds = cardStore.get(id: id)?.defaultDuration ?? 0
        case .adHoc(let template):
            seconds = template.defaultDuration
        }
        if seconds <= 0 {
            return ""
        }
        return TimeFormatter.formatDuration(seconds)
    }
}

private struct FocusListRow: View {
    let title: String
    let durationText: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
            if !durationText.isEmpty {
                Text(durationText)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }
}
