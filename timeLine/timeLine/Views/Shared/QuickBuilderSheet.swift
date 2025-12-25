import SwiftUI
import TimeLineCore

struct QuickBuilderSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var appMode: AppModeManager
    
    let onCreated: (() -> Void)?
    
    init(onCreated: (() -> Void)? = nil) {
        self.onCreated = onCreated
    }
    
    @State private var draft = QuickBuilderDraft.default
    
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
        
        static let `default` = QuickBuilderDraft(
            title: "Study",
            category: .study,
            duration: .m30
        )
    }
    
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
                                handlePrimaryAction()
                            }
                        
                        sectionTitle("Quick Picks")
                        flowChips(items: topics, tintFromCategory: true) { item in
                            draft.title = item.0
                            draft.category = item.1
                        } isSelected: { item in
                            draft.title == item.0
                        }
                        
                        if !recentTemplates.isEmpty {
                            sectionTitle("Recent Cards")
                            recentChips
                        }
                        
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
        
        let style: BossStyle = draft.category == .rest ? .passive : .focus
        let template = CardTemplate(
            title: trimmed,
            icon: draft.category.icon,
            defaultDuration: draft.duration.duration,
            tags: [draft.category.rawValue],
            energyColor: energyToken(for: draft.category),
            category: draft.category,
            style: style
        )
        cardStore.add(template)
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
        Array(cardStore.orderedTemplates().prefix(6))
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
                }
            }
        }
    }
    
    private func durationOption(for seconds: TimeInterval) -> QuickDuration {
        let target = max(0, seconds)
        let options = QuickDuration.allCases
        let closest = options.min { lhs, rhs in
            abs(lhs.duration - target) < abs(rhs.duration - target)
        }
        return closest ?? .m30
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
