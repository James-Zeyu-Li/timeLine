import SwiftUI
import TimeLineCore

struct CardLibraryPickerSheet: View {
    let title: String

    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var libraryStore: LibraryStore
    @EnvironmentObject var stateManager: AppStateManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIds: Set<UUID> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if cardStore.orderedTemplates().isEmpty {
                    Text("No cards available.")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                } else {
                    CardLibrarySelectionView(
                        templates: cardStore.orderedTemplates(),
                        selectedIds: $selectedIds,
                        showLibraryStatus: true
                    )
                }

                addButton
            }
            .padding(.bottom, 12)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var addButton: some View {
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
        dismiss()
    }
}
