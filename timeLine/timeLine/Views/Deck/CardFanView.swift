import SwiftUI
import TimeLineCore

// MARK: - Card Fan View

struct CardFanView: View {
    let tab: DeckTab

    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var libraryStore: LibraryStore
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var appMode: AppModeManager
    
    @State private var showQuickBuilder = false
    @State private var isSelecting = false
    @State private var selectedIds: Set<UUID> = []
    
    var body: some View {
        let cards = cardStore.orderedTemplates(includeEphemeral: false)
        let count = cards.count
        
        VStack(spacing: 12) {
            headerRow
            
            if !isSelecting {
                Text("Tap a card to add it to Library")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            if isSelecting {
                CardLibrarySelectionView(
                    templates: cards,
                    selectedIds: $selectedIds,
                    showLibraryStatus: true
                )
                addToLibraryButton
            } else {
                ZStack {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        CardView(template: card)
                            .offset(fanOffset(index: index, total: count))
                            .rotationEffect(fanRotation(index: index, total: count))
                            .zIndex(Double(index))
                            .onTapGesture {
                                guard !appMode.isDragging else { return }
                                addCardToLibrary(card.id)
                            }
                            .onLongPressGesture(minimumDuration: 0.5) {
                                guard !appMode.isDragging else { return }
                                appMode.enterCardEdit(cardTemplateId: card.id)
                            }
                    }
                }
                .frame(height: 200)
            }
        }
        .sheet(isPresented: $showQuickBuilder) {
            QuickBuilderSheet()
        }
    }
    
    // MARK: - Quick Builder Entry
    
    private var headerRow: some View {
        HStack {
            Button {
                showQuickBuilder = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add Card")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                }
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
            }
            .accessibilityIdentifier("addCardButton")
            .buttonStyle(.plain)
            
            Spacer()
            
            Button(isSelecting ? "Done" : "Select") {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    isSelecting.toggle()
                    if !isSelecting {
                        selectedIds.removeAll()
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
        .padding(.horizontal, 24)
    }

    private var addToLibraryButton: some View {
        Button {
            addSelectedToLibrary()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 12, weight: .bold))
                Text("Add to Library")
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
        .padding(.bottom, 8)
    }
    
    private func addSelectedToLibrary() {
        for id in selectedIds {
            libraryStore.add(templateId: id)
        }
        stateManager.requestSave()
        Haptics.impact(.heavy)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            selectedIds.removeAll()
            isSelecting = false
        }
    }

    private func addCardToLibrary(_ id: UUID) {
        libraryStore.add(templateId: id)
        stateManager.requestSave()
        Haptics.impact(.light)
    }
    
    // MARK: - Fan Layout
    
    private func fanOffset(index: Int, total: Int) -> CGSize {
        guard total > 1 else { return .zero }
        let centerIndex = Double(total - 1) / 2.0
        let offset = Double(index) - centerIndex
        return CGSize(width: offset * 60, height: abs(offset) * 10)
    }
    
    private func fanRotation(index: Int, total: Int) -> Angle {
        guard total > 1 else { return .zero }
        let centerIndex = Double(total - 1) / 2.0
        let offset = Double(index) - centerIndex
        return .degrees(offset * 5)
    }
    
    // MARK: - Gestures
}

// MARK: - Card View

struct CardView: View {
    let template: CardTemplate
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon
            Image(systemName: template.icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            // Title
            Text(template.title)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Duration
            Text(formatDuration(template.defaultDuration))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(12)
        .frame(width: 100, height: 140)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(cardAccessibilityId)
    }
    
    private var cardBackground: some View {
        LinearGradient(
            colors: [Color.purple.opacity(0.8), Color.purple.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var cardAccessibilityId: String {
        let compactTitle = template.title.replacingOccurrences(of: " ", with: "_")
        return "cardView_\(compactTitle)"
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return "\(minutes) min"
    }
}

private struct CardPreviewPanel: View {
    let template: CardTemplate

    @EnvironmentObject var libraryStore: LibraryStore
    @EnvironmentObject var stateManager: AppStateManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 4) {
                Text(template.title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text("\(Int(template.defaultDuration / 60)) min · \(template.category.rawValue.capitalized)")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.gray)
            }
            Spacer()
            Button {
                toggleLibrary()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isInLibrary ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 12, weight: .bold))
                    Text(isInLibrary ? "Saved" : "Save")
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.semibold)
                }
                .foregroundColor(isInLibrary ? .cyan : .white)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isInLibrary ? Color.cyan.opacity(0.18) : Color.white.opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(isInLibrary ? Color.cyan.opacity(0.4) : Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }

    private var isInLibrary: Bool {
        libraryStore.entry(for: template.id) != nil
    }

    private func toggleLibrary() {
        if isInLibrary {
            libraryStore.remove(templateId: template.id)
        } else {
            libraryStore.add(templateId: template.id)
        }
        stateManager.requestSave()
        Haptics.impact(.light)
    }
}
