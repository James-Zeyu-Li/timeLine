import SwiftUI
import TimeLineCore

struct CardLibrarySelectionView: View {
    let templates: [CardTemplate]
    @Binding var selectedIds: Set<UUID>
    let showLibraryStatus: Bool

    @EnvironmentObject var libraryStore: LibraryStore

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(templates, id: \.id) { template in
                    CardLibrarySelectionRow(
                        template: template,
                        isSelected: selectedIds.contains(template.id),
                        isInLibrary: showLibraryStatus && libraryStore.entry(for: template.id) != nil,
                        onToggle: {
                            toggle(template.id)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    private func toggle(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }
}

private struct CardLibrarySelectionRow: View {
    let template: CardTemplate
    let isSelected: Bool
    let isInLibrary: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .cyan : .gray)

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
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(TimeFormatter.formatDuration(template.defaultDuration))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    if isInLibrary {
                        Text("In Library")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.cyan)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.cyan.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}
