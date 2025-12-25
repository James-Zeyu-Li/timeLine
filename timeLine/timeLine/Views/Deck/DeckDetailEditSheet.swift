import SwiftUI
import TimeLineCore

struct DeckDetailEditSheet: View {
    let deckId: UUID
    
    @EnvironmentObject var deckStore: DeckStore
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var appMode: AppModeManager
    @Environment(\.editMode) private var editMode
    
    @State private var draft: DeckTemplate?
    @State private var deckMissing = false
    
    var body: some View {
        NavigationStack {
            Group {
                if deckMissing {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28, weight: .bold))
                        Text("Deck not found")
                            .font(.system(.headline, design: .rounded))
                    }
                    .foregroundColor(.secondary)
                } else if draft != nil {
                    Form {
                        Section("Title") {
                            TextField("Deck title", text: titleBinding)
                                .textInputAutocapitalization(.sentences)
                        }
                        
                        Section("Cards") {
                            if cardTemplateIds.isEmpty {
                                Text("No cards yet")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(Array(cardTemplateIds.enumerated()), id: \.offset) { item in
                                    let templateId = item.element
                                    if let template = cardStore.get(id: templateId) {
                                        HStack {
                                            Text(template.title)
                                            Spacer()
                                            Text("\(Int(template.defaultDuration / 60)) min")
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        Text("Missing card")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .onDelete { indexSet in
                                    var updated = cardTemplateIds
                                    updated.remove(atOffsets: indexSet)
                                    updateCardTemplateIds(updated)
                                }
                                .onMove { source, destination in
                                    var updated = cardTemplateIds
                                    updated.move(fromOffsets: source, toOffset: destination)
                                    updateCardTemplateIds(updated)
                                }
                            }
                        }
                        
                        Section("Add Card") {
                            ForEach(cardStore.orderedTemplates()) { template in
                                Button {
                                    var updated = cardTemplateIds
                                    updated.append(template.id)
                                    updateCardTemplateIds(updated)
                                } label: {
                                    HStack {
                                        Text(template.title)
                                        Spacer()
                                        Text("\(Int(template.defaultDuration / 60)) min")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Edit Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        appMode.exitDeckEdit()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        appMode.exitDeckEdit()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
        .onAppear {
            loadDeckIfNeeded()
        }
    }
    
    private var titleBinding: Binding<String> {
        Binding(
            get: { draft?.title ?? "" },
            set: { newValue in
                guard var current = draft else { return }
                current.title = newValue
                draft = current
            }
        )
    }
    
    private var cardTemplateIds: [UUID] {
        draft?.cardTemplateIds ?? []
    }
    
    private var isSaveDisabled: Bool {
        let trimmed = draft?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty
    }
    
    private func loadDeckIfNeeded() {
        guard draft == nil, !deckMissing else { return }
        guard let deck = deckStore.get(id: deckId) else {
            deckMissing = true
            return
        }
        draft = deck
    }
    
    private func updateCardTemplateIds(_ updated: [UUID]) {
        guard var current = draft else { return }
        current.cardTemplateIds = updated
        draft = current
    }
    
    private func saveChanges() {
        guard let draft else { return }
        deckStore.update(draft)
    }
}
