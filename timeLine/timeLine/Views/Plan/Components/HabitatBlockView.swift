import SwiftUI
import TimeLineCore

struct HabitatBlockView: View {
    let title: String
    let timeRange: String
    let items: [StagedTask] // This view will display staged items
    let onDrop: ([String]) -> Void
    
    // Theme
    private let habitatBackground = Color.black.opacity(0.2)
    private let habitatBorder = Color.white.opacity(0.1)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "leaf.circle.fill")
                    .foregroundColor(Color.green.opacity(0.7))
                Text(title) // e.g. "Forest Clearing"
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                Text(timeRange) // "14:00 - 16:00"
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Content Area (The "Habitat")
            // A Flow Layout or Grid for chips
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                if items.isEmpty {
                    // Empty State
                    Text("Drop seeds here to cultivate")
                        .font(.caption)
                        .italic()
                        .foregroundColor(.white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                } else {
                    ForEach(items) { task in
                        SpecimenChip(template: task.template, isSelected: false)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundColor(.white.opacity(0.1))
                    )
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(habitatBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(habitatBorder, lineWidth: 1)
                )
        )
        .dropDestination(for: String.self) { items, location in
            onDrop(items)
            return true
        }
    }
}
