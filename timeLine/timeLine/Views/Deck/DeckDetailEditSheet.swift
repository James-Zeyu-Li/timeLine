import SwiftUI
import TimeLineCore

struct DeckDetailEditSheet: View {
    let deckId: UUID
    
    @EnvironmentObject var deckStore: DeckStore
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var appMode: AppModeManager
    @Environment(\.editMode) private var editMode
    
    @State private var title: String = ""
    @State private var cardTemplateIds: [UUID] = []
    @State private var didLoad = false
    
    var body: some View {
        NavigationStack {
            Group {
                if let deck = deckStore.get(id: deckId) {
                    Form {
                        Section("Title") {
                            TextField("Deck title", text: $title)
                                .textInputAutocapitalization(.sentences)
                        }
                        
                        Section("Cards") {
                            if cardTemplateIds.isEmpty {
                                Text("No cards yet")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(cardTemplateIds, id: \.self) { templateId in
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
                                    cardTemplateIds.remove(atOffsets: indexSet)
                                }
                                .onMove { source, destination in
                                    cardTemplateIds.move(fromOffsets: source, toOffset: destination)
                                }
                            }
                        }
                        
                        Section("Add Card") {
                            ForEach(cardStore.orderedTemplates()) { template in
                                Button {
                                    cardTemplateIds.append(template.id)
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
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28, weight: .bold))
                        Text("Deck not found")
                            .font(.system(.headline, design: .rounded))
                    }
                    .foregroundColor(.secondary)
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
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            if !didLoad {
                loadDeck()
                didLoad = true
            }
        }
    }
    
    private func loadDeck() {
        guard let deck = deckStore.get(id: deckId) else { return }
        title = deck.title
        cardTemplateIds = deck.cardTemplateIds
    }
    
    private func saveChanges() {
        guard var deck = deckStore.get(id: deckId) else { return }
        deck.title = title
        deck.cardTemplateIds = cardTemplateIds
        deckStore.update(deck)
    }
}
