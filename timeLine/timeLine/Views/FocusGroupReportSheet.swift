import SwiftUI
import TimeLineCore

struct FocusGroupReportSheet: View {
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var libraryStore: LibraryStore
    @EnvironmentObject var stateManager: AppStateManager
    @Environment(\.dismiss) private var dismiss
    let report: FocusGroupFinishedReport

    private var visibleEntries: [FocusGroupReportEntry] {
        report.entries.filter { $0.focusedSeconds > 0 }
    }

    private var timelineSegments: [FocusGroupReportSegment] {
        report.segments
            .filter { $0.duration > 0 }
            .sorted { $0.startedAt < $1.startedAt }
    }
    
    private var achievementLabel: String {
        let totalMinutes = Int(report.totalFocusedSeconds / 60)
        if totalMinutes >= 120 {
            return "🌟 大丰收！"
        } else if totalMinutes >= 60 {
            return "🌾 好收成！"
        } else if totalMinutes >= 30 {
            return "🌱 有进步！"
        } else {
            return "🌿 好开始！"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Section - Harvest Summary (丰收总结)
                    VStack(spacing: 16) {
                        // Treasure Chest Animation Area
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                // Treasure Chest Icon
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(PixelTheme.secondary)
                                    .scaleEffect(1.1)
                                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: UUID())
                                
                                Text("今日收获")
                                    .font(.system(.title2, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(PixelTheme.textPrimary)
                            }
                            Spacer()
                        }
                        
                        // Achievement Banner (飘动的黄色缎带)
                        HStack {
                            Spacer()
                            Text(achievementLabel)
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(PixelTheme.textPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.yellow.opacity(0.8))
                                        .shadow(color: .orange.opacity(0.3), radius: 4, x: 2, y: 2)
                                )
                            Spacer()
                        }
                        
                        // Total Focus Time (专注时长显示在木牌上)
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(PixelTheme.success)
                                Text("专注时长")
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(PixelTheme.textPrimary)
                            }
                            
                            Text(TimeFormatter.formatDuration(report.totalFocusedSeconds))
                                .font(.system(.largeTitle, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(PixelTheme.primary)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(PixelTheme.cream)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(PixelTheme.secondary, lineWidth: 2)
                                )
                        )
                    }

                    // Task Distribution (任务分布 - 种子包风格)
                    if visibleEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 40))
                                .foregroundColor(PixelTheme.success.opacity(0.6))
                            Text("今天还没有收获哦")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(PixelTheme.textPrimary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            // Section Header with Icon
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(PixelTheme.success)
                                Text("收获清单")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(PixelTheme.textPrimary)
                            }
                            
                            // Task Cards (宝可梦卡牌风格)
                            ForEach(visibleEntries, id: \.templateId) { entry in
                                let template = cardStore.get(id: entry.templateId)
                                let progress = report.totalFocusedSeconds > 0 ? entry.focusedSeconds / report.totalFocusedSeconds : 0
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    // Card Header
                                    HStack {
                                        // Pixel Icon
                                        Image(systemName: pixelIcon(for: entry.templateId))
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 32, height: 32)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(pixelColor(for: entry.templateId))
                                            )
                                        
                                        Text(template?.title ?? "Task")
                                            .font(.system(.subheadline, design: .rounded))
                                            .fontWeight(.bold)
                                            .foregroundColor(PixelTheme.textPrimary)
                                        
                                        Spacer()
                                        
                                        // Time Badge
                                        Text(TimeFormatter.formatDuration(entry.focusedSeconds))
                                            .font(.system(.caption, design: .monospaced))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule().fill(PixelTheme.primary)
                                            )
                                    }
                                    
                                    // Progress Bar (像素风格进度条)
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            // Background Track
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(PixelTheme.secondary.opacity(0.2))
                                                .frame(height: 12)
                                            
                                            // Progress Fill with Pixel Pattern
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            pixelColor(for: entry.templateId),
                                                            pixelColor(for: entry.templateId).opacity(0.8)
                                                        ]),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: geometry.size.width * progress, height: 12)
                                                .animation(.easeInOut(duration: 1.2), value: progress)
                                            
                                        }
                                    }
                                    .frame(height: 12)
                                    
                                    // Save Template Button (像素风格)
                                    if let template, template.isEphemeral {
                                        Button(action: { saveEphemeralTemplate(template) }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "heart.fill")
                                                    .font(.system(size: 12))
                                                Text("收藏种子")
                                                    .font(.system(.caption, design: .rounded))
                                                    .fontWeight(.bold)
                                            }
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(Color.pink.opacity(0.8))
                                                    .shadow(color: .pink.opacity(0.3), radius: 2, x: 1, y: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(PixelTheme.cardBackground)
                                        .shadow(color: PixelTheme.secondary.opacity(0.2), radius: 4, x: 2, y: 2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(pixelColor(for: entry.templateId).opacity(0.3), lineWidth: 2)
                                        )
                                )
                            }
                        }
                    }

                    // Timeline Section (乡间小径)
                    if !timelineSegments.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "map.fill")
                                    .foregroundColor(PixelTheme.success)
                                Text("今日足迹")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(PixelTheme.textPrimary)
                            }
                            
                            VStack(spacing: 8) {
                                ForEach(timelineSegments, id: \.startedAt) { segment in
                                    HStack(spacing: 12) {
                                        // Time Badge
                                        Text(timeRangeLabel(for: segment))
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundColor(PixelTheme.textPrimary.opacity(0.7))
                                            .frame(width: 80, alignment: .leading)
                                        
                                        // Path Marker (路标指示牌)
                                        Image(systemName: "signpost.right.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(pixelColor(for: segment.templateId))
                                        
                                        Text(cardStore.get(id: segment.templateId)?.title ?? "Task")
                                            .font(.system(.caption, design: .rounded))
                                            .fontWeight(.medium)
                                            .foregroundColor(PixelTheme.textPrimary)
                                        
                                        Spacer()
                                        
                                        // Duration with Flower Icon
                                        HStack(spacing: 2) {
                                            Image(systemName: "leaf.fill")
                                                .font(.system(size: 8))
                                                .foregroundColor(PixelTheme.success)
                                            Text(TimeFormatter.formatDuration(segment.duration))
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(PixelTheme.textPrimary.opacity(0.8))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(PixelTheme.cream.opacity(0.6))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(PixelTheme.success.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(24)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        PixelTheme.cream,
                        PixelTheme.success.opacity(0.1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("🎉 今日完成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("回到农场") {
                        dismiss()
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(PixelTheme.success)
                }
            }
        }
    }

    private func saveEphemeralTemplate(_ template: CardTemplate) {
        var updated = template
        updated.isEphemeral = false
        cardStore.update(updated)
        libraryStore.add(templateId: updated.id)
        stateManager.requestSave()
    }

    private func timeRangeLabel(for segment: FocusGroupReportSegment) -> String {
        guard let start = timelineSegments.first?.startedAt else {
            return TimeFormatter.formatTimer(segment.duration)
        }
        let startOffset = segment.startedAt.timeIntervalSince(start)
        let endOffset = segment.endedAt.timeIntervalSince(start)
        return "\(TimeFormatter.formatTimer(startOffset)) - \(TimeFormatter.formatTimer(endOffset))"
    }
    
    private func pixelColor(for templateId: UUID) -> Color {
        let hash = templateId.hashValue
        let colors: [Color] = [
            PixelTheme.success,    // 森林绿
            PixelTheme.primary,    // 活力橘
            PixelTheme.secondary,  // 木纹棕
            Color(hex: "3399CC"),  // 天蓝色 (学习)
            Color(hex: "CC6699"),  // 粉紫色 (创作)
            Color(hex: "99CC66"),  // 草绿色 (家务)
        ]
        return colors[abs(hash) % colors.count]
    }
    
    private func pixelIcon(for templateId: UUID) -> String {
        // 像素风格的彩色小物件图标
        let hash = templateId.hashValue
        let icons = [
            "laptopcomputer",      // 迷你电脑屏幕 (编程)
            "envelope.fill",       // 带红漆的小信封 (邮件)
            "book.fill",          // 小书本 (学习)
            "house.fill",         // 小房子 (家务)
            "paintbrush.fill",    // 画笔 (创作)
            "gamecontroller.fill", // 游戏手柄 (娱乐)
        ]
        return icons[abs(hash) % icons.count]
    }
}
