import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // App概述
                    HelpSection(
                        icon: "map.fill",
                        title: "What is TimeLineApp?",
                        content: "TimeLineApp is a roguelike-inspired focus timer that turns your daily tasks into an adventure. Each day is a new journey with tasks as bosses to defeat through focused work."
                    )
                    
                    // 核心概念
                    HelpSection(
                        icon: "bolt.fill",
                        title: "Core Concepts",
                        content: """
                        • **Boss** = A task you need to complete
                        • **Battle** = Focusing on a task (timer-based)
                        • **Journey** = Your daily timeline
                        • **Bonfire** = Rest breaks between tasks
                        • **Wasted Time** = Time lost to distractions
                        """
                    )
                    
                    // 严格模式
                    HelpSection(
                        icon: "shield.fill",
                        title: "Strict Mode",
                        content: """
                        TimeLineApp uses strict focus rules:
                        • No pause button - you must finish or retreat
                        • Backgrounding the app counts as wasted time
                        • Use "Immunity" to safely use your phone during focus
                        • Each battle gives you 1 immunity token
                        """
                    )
                    
                    // 任务类型
                    HelpSection(
                        icon: "list.bullet",
                        title: "Task Types",
                        content: """
                        **Focus Tasks**: Timer-based work requiring concentration
                        **Passive Tasks**: Quick completion items (gym, calls, etc.)
                        
                        Focus tasks use the battle system, while passive tasks can be marked complete instantly.
                        """
                    )
                    
                    // Routine Packs
                    HelpSection(
                        icon: "square.stack.3d.up.fill",
                        title: "Routine Packs",
                        content: """
                        Add multiple related tasks at once:
                        • **Morning Flow**: Planning → Email → Deep Work
                        • **Study Session**: Review → Learn → Practice
                        • **Pomodoro Set**: 4 focused work blocks
                        
                        The system automatically adds rest breaks between tasks.
                        """
                    )
                    
                    // 每日重置
                    HelpSection(
                        icon: "sunrise.fill",
                        title: "Daily Reset",
                        content: """
                        Each day is a fresh start:
                        • Timeline resets at midnight
                        • Unfinished tasks don't carry over
                        • Daily/weekly templates auto-spawn
                        • Yesterday's progress is saved to history
                        """
                    )
                    
                    // 统计系统
                    HelpSection(
                        icon: "chart.bar.fill",
                        title: "Stats & Progress",
                        content: """
                        Track your focus journey:
                        • Daily focus time and completion rate
                        • Weekly summaries and comparisons
                        • 365-day heatmap showing consistency
                        • Wasted time tracking for improvement
                        """
                    )
                }
                .padding(24)
            }
            .navigationTitle("Help & Guide")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct HelpSection: View {
    let icon: String
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.cyan)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text(content)
                .font(.system(.body, design: .default))
                .foregroundColor(.gray)
                .lineSpacing(4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(white: 0.1), lineWidth: 1)
                )
        )
    }
}

#Preview {
    HelpView()
}