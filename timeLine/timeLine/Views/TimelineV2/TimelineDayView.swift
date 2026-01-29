import SwiftUI

struct TimelineDayView: View {
    let day: TimelineDay
    let onToggleCompletion: (TimelineTask) -> Void
    
    @State private var isCarryOverExpanded: Bool = true
    
    // Formatting
    private let headerDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMM d" // e.g., "Monday, Jan 29"
        return df
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Header
            HStack {
                Text(headerDateFormatter.string(from: day.date))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Summary Counts
                HStack(spacing: 8) {
                    if !day.carryOverTasks.isEmpty {
                        CountBadge(count: day.carryOverTasks.count, color: .orange, icon: "arrow.uturn.left")
                    }
                    let totalToday = day.tasksForDay.filter { $0.status == .todo }.count
                    if totalToday > 0 {
                        CountBadge(count: totalToday, color: .blue, icon: "circle")
                    }
                    if !day.completedTodayTasks.isEmpty {
                        CountBadge(count: day.completedTodayTasks.count, color: .green, icon: "checkmark")
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // MARK: - Carry Over Group
            if !day.carryOverTasks.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: { withAnimation { isCarryOverExpanded.toggle() } }) {
                        HStack {
                            Image(systemName: "chevron.right")
                                .rotationEffect(.degrees(isCarryOverExpanded ? 90 : 0))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Carried Over")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .background(Color.orange.opacity(0.1))
                    }
                    
                    if isCarryOverExpanded {
                        ForEach(day.carryOverTasks) { task in
                            TimelineV2NodeRow(task: task, onToggle: { onToggleCompletion(task) })
                                .transition(.opacity)
                        }
                    }
                }
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            // MARK: - Today's Entries (Created Today + Completed Today)
            // We combine them for the list, but maybe separating sections is clearer? 
            // The logic implies "Timeline entries".
            // Let's mix them or grouping?
            // "Entries (tasks created today, completed today, etc)"
            // Simplest: Show "Active (Created Today)" then "Completed Today"
            
            // let activeToday = day.tasksForDay.filter { $0.status == .todo } // Unused
            // Completed Today can include items created today (duplicates in list?)
            // If I created it today and finished it today, it's in both properties in the Store logic I wrote?
            // Store:
            //   createdToday: createdAt >= starts
            //   completedToday: completedAt >= start
            // Overlap: Created Today & Completed Today.
            // UI Strategy: Show Active in one block, Completed in another?
            // Or sort by time?
            // Let's do:
            // 1. Created Today (and still Active)
            // 2. Completed Today (regardless of creation)
            // Wait, Store's `tasksForDay` holds ALL created today.
            // I should filter `tasksForDay` to only show Active ones here to avoid duplicates if they are also in Completed.
            
            let activeCreatedToday = day.tasksForDay.filter { $0.status != .done }
            
            LazyVStack(spacing: 8) {
                if activeCreatedToday.isEmpty && day.completedTodayTasks.isEmpty && day.carryOverTasks.isEmpty {
                    Text("No tasks for today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 20)
                } else {
                    // Active
                    ForEach(activeCreatedToday) { task in
                        TimelineV2NodeRow(task: task, onToggle: { onToggleCompletion(task) })
                    }
                    
                    // Completed Divider?
                    if !day.completedTodayTasks.isEmpty {
                        HStack {
                            Text("Completed")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        ForEach(day.completedTodayTasks) { task in
                            TimelineV2NodeRow(task: task, onToggle: { onToggleCompletion(task) })
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            // Soft Boundary Spacer
            Rectangle()
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 1)
                .padding(.top, 16)
        }
        .padding(.bottom, 24) // Soft spacing between days
    }
}

// Minimal Subviews

struct CountBadge: View {
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
}


