import SwiftUI
import TimeLineCore

struct DeckBar: View {
    @EnvironmentObject var templateStore: TemplateStore
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var daySession: DaySession
    
    @State private var showingTaskSheet = false
    @State private var editingTemplate: TaskTemplate? = nil
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // 1. 改进的添加卡片按钮
                Button(action: {
                    editingTemplate = nil
                    showingTaskSheet = true
                }) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.cyan.opacity(0.2), Color.blue.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.cyan)
                        }
                        
                        Text("New Card")
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.cyan)
                    }
                    .frame(width: 100, height: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                                    )
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // 2. 改进的模板卡片
                ForEach(templateStore.templates) { template in
                    Button(action: {
                        spawnTask(from: template)
                    }) {
                        VStack(alignment: .leading, spacing: 0) {
                            // 顶部标签区域
                            HStack {
                                // 分类图标
                                Image(systemName: template.category.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(template.category.color)
                                
                                Spacer()
                                
                                // 执行模式图标
                                if template.style == .focus {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.yellow)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.cyan)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                            
                            Spacer()
                            
                            // 中间标题区域
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.title)
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                // 时长显示
                                Text(TimeFormatter.formatDuration(template.duration ?? 0))
                                    .font(.system(.caption2, design: .monospaced))
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 12)
                            
                            Spacer()
                            
                            // 底部重复标签
                            HStack {
                                Spacer()
                                if template.repeatRule != .none {
                                    Text(repeatBadge(for: template.repeatRule))
                                        .font(.system(size: 8, weight: .bold))
                                        .tracking(0.5)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(Color.blue.opacity(0.2))
                                        )
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                        }
                        .frame(width: 110, height: 130)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(white: 0.12), Color(white: 0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(white: 0.2), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button {
                            spawnTask(from: template)
                        } label: {
                            Label("Spawn Task", systemImage: "play.fill")
                        }
                        
                        Button {
                            editingTemplate = template
                            showingTaskSheet = true
                        } label: {
                            Label("Edit Card", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            templateStore.delete(template)
                        } label: {
                            Label("Delete Card", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .sheet(isPresented: $showingTaskSheet) {
            TaskSheet(templateToEdit: $editingTemplate)
        }
    }
    
    func spawnTask(from template: TaskTemplate) {
        // 🎯 简化spawn逻辑，使用DaySession的标准方法
        let boss = SpawnManager.spawn(from: template)
        let newNode = TimelineNode(
            type: .battle(boss),
            isLocked: false // Manual spawn = immediately available
        )
        
        withAnimation(.easeInOut(duration: 0.3)) {
            daySession.nodes.append(newNode)
        }
        
        print("✅ Spawned: \(boss.name)")
    }
    
    func repeatBadge(for rule: RepeatRule) -> String {
        switch rule {
        case .none: return ""
        case .daily: return "DAILY"
        case .weekly: return "WEEKLY"
        case .monthly: return "MONTHLY"
        }
    }
}
