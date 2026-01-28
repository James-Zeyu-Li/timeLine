import SwiftUI
import UIKit
import Foundation
import TimeLineCore

// MARK: - Supporting Views

struct PlanInboxListView: View {
    let inboxNodes: [TimelineNode]
    let cardStore: CardTemplateStore
    let onDelete: (UUID) -> Void
    let onUpdateFinishBy: (UUID, FinishBySelection) -> Void
    
    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(inboxNodes) { node in
                if case .battle(let boss) = node.type,
                   let templateId = boss.templateId,
                   let template = cardStore.get(id: templateId) {
                    
                    PlanInboxTaskRow(
                        node: node,
                        template: template,
                        onDelete: { onDelete(node.id) },
                        onUpdateFinishBy: { fb in onUpdateFinishBy(node.id, fb) }
                    )
                    .transition(.opacity)
                }
            }
        }
    }
}

struct PlanInboxTaskRow: View {
    let node: TimelineNode
    let template: CardTemplate
    let onDelete: () -> Void
    let onUpdateFinishBy: (FinishBySelection) -> Void
    
    @State private var showFinishByPicker = false
    
    // Helper to determine current FinishBy selection from template.deadlineAt
    private var currentFinishBy: FinishBySelection {
        if let d = template.deadlineAt {
            // Heuristic to match back to enum if necessary, or just display date
            // For simplify, we default to showing 'Scheduled' or 'None'
            return .pickDate(d)
        }
        return .none
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(template.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                
                HStack(spacing: 8) {
                    Text(TimeFormatter.formatDuration(template.defaultDuration))
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.6))
                    
                    Button(action: { showFinishByPicker = true }) {
                        HStack(spacing: 2) {
                            if let deadline = template.deadlineAt {
                                Image(systemName: "calendar")
                                Text(deadlineIsToday(deadline) ? "Tonight" : "Scheduled")
                            } else {
                                Image(systemName: "infinity")
                                Text("No Deadline")
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue.opacity(0.2)))
                        .foregroundStyle(Color.blue.opacity(0.8))
                    }
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(.red.opacity(0.7))
                    .padding(8)
                    .background(Circle().fill(.red.opacity(0.1)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
        .sheet(isPresented: $showFinishByPicker) {
            FinishByPickerSheet(
                selectedFinishBy: currentFinishBy,
                onSelection: onUpdateFinishBy
            )
        }
    }
    
    private func deadlineIsToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

struct FinishByPickerSheet: View {
    let selectedFinishBy: FinishBySelection
    let onSelection: (FinishBySelection) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var customDate = Date()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("设置截止时间")
                    .font(.headline)
                    .padding()
                
                VStack(spacing: 12) {
                    ForEach(FinishBySelection.allCases, id: \.displayName) { option in
                        Button(action: {
                            onSelection(option)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: option.iconName)
                                    .frame(width: 20)
                                Text(option.displayName)
                                Spacer()
                                // Simple check not robust for .pickDate, but sufficient for UI selection
                                if option.displayName == selectedFinishBy.displayName {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                            )
                        }
                        .foregroundStyle(.primary)
                    }
                }
                .padding()
                
                Divider()
                
                VStack(spacing: 12) {
                    Text("自定义日期")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    DatePicker(
                        "选择日期",
                        selection: $customDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    
                    Button("设置自定义日期") {
                        onSelection(.pickDate(customDate))
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(8)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("截止时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// Button Style Helper
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ScaleButtonStyle {
    static var scale: ScaleButtonStyle { ScaleButtonStyle() }
}
