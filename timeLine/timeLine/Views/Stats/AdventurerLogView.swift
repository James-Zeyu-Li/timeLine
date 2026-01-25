import SwiftUI
import TimeLineCore

struct AdventurerLogView: View {
    @StateObject var viewModel = StatsViewModel()
    @EnvironmentObject var engine: BattleEngine
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showSettings = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                navigationHeader
                
                // Profile
                AdventurerProfileCard(
                    totalXP: Int(viewModel.totalFocusedAllTime / 60) * 10, // 1 min = 10 XP
                    level: calculateLevel(xp: Int(viewModel.totalFocusedAllTime / 60) * 10)
                )
                
                // Ranges
                rangePicker
                
                // Stats Grid
                AdventurerStatGrid(
                    dungeons: viewModel.totalSessionsAllTime,
                    gold: Int(viewModel.totalFocusedAllTime / 60), // 1 min = 1 gold
                    quests: viewModel.totalQuests,
                    streak: viewModel.currentStreak
                )
                
                // Weekly Progress
                VStack(alignment: .leading, spacing: 16) {
                    headerText(progressHeaderText)
                    
                    HStack(spacing: 12) {
                        Text(viewModel.rangeFocusedText)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(PixelTheme.textPrimary)
                        
                        // Percentage growth
                        HStack(spacing: 2) {
                            Image(systemName: viewModel.rangeGrowthPercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text("\(viewModel.rangeGrowthPercent > 0 ? "+" : "")\(viewModel.rangeGrowthPercent)%")
                        }
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.rangeGrowthPercent >= 0 ? PixelTheme.success : PixelTheme.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((viewModel.rangeGrowthPercent >= 0 ? PixelTheme.success : PixelTheme.warning).opacity(0.1))
                        .cornerRadius(4)
                        
                        Spacer()
                        
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundColor(PixelTheme.textSecondary.opacity(0.3))
                    }
                    
                    AdventurerRangeChart(bars: viewModel.rangeBars, range: viewModel.selectedRange)
                        .frame(height: 180)
                }
                .padding(24)
                .background(Color.white)
                .cornerRadius(24)
                .shadow(color: PixelTheme.cardShadow, radius: 12, x: 0, y: 4)
                
                // Quest Map
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        headerText("ACTIVITY HEATMAP")
                        Spacer()
                        Text("365 Days")
                            .font(.caption)
                            .foregroundColor(PixelTheme.textSecondary)
                    }
                    
                    AdventurerQuestMap(viewModel: viewModel)
                }
                .padding(24)
                .background(Color.white)
                .cornerRadius(24)
                .shadow(color: PixelTheme.cardShadow, radius: 12, x: 0, y: 4)
                
                // Legendary Feats (Placeholders - Hidden for now until V2)
                /*
                VStack(alignment: .leading, spacing: 16) {
                    headerText("ACHIEVEMENTS")
                    
                    FeatRow(icon: "trophy.fill", color: .orange, title: "Focus Streak", subtitle: "14 days of consistent focus sessions")
                    FeatRow(icon: "checkmark.seal.fill", color: .green, title: "Task Master", subtitle: "Completed 50 tasks", badge: "Badge")
                }
                */
            }
            .padding(24)
        }
        .background(PixelTheme.background.ignoresSafeArea())
        .onAppear {
            viewModel.processHistory(
                engine.history,
                specimens: engine.specimenCollection
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
    
    private var navigationHeader: some View {
        HStack {
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(PixelTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: PixelTheme.cardShadow, radius: 4, x: 0, y: 2)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Statistics")
                    .font(.system(.headline, design: .serif))
                    .fontWeight(.bold)
                    .foregroundColor(PixelTheme.textPrimary)
                Text("STATS & RECORDS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(PixelTheme.primary)
            }
            
            Spacer()
            
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(PixelTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: PixelTheme.cardShadow, radius: 4, x: 0, y: 2)
            }
        }
        .padding(.bottom, 8)
    }
    
    private var rangePicker: some View {
        HStack(spacing: 4) {
            ForEach(StatsTimeRange.allCases) { range in
                Button {
                    withAnimation { 
                        viewModel.updateSelectedRange(range)
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(viewModel.selectedRange == range ? PixelTheme.primary : PixelTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(viewModel.selectedRange == range ? Color.white : Color.clear)
                        .cornerRadius(20)
                        .shadow(color: viewModel.selectedRange == range ? PixelTheme.cardShadow : .clear, radius: 4, x: 0, y: 2)
                }
            }
        }
        .padding(4)
        .background(PixelTheme.woodLight.opacity(0.1)) // Subtle background
        .cornerRadius(24)
    }
    
    private var progressHeaderText: String {
        switch viewModel.selectedRange {
        case .day: return "TODAY'S PROGRESS"
        case .week: return "WEEKLY PROGRESS"
        case .year: return "YEARLY PROGRESS"
        }
    }
    
    private func headerText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1)
            .foregroundColor(PixelTheme.secondary)
            .opacity(0.8)
    }
    
    private func calculateLevel(xp: Int) -> Int {
        // Simple linear level curve: 1000 XP per level
        return max(1, xp / 1000)
    }
}

// MARK: - Subcomponents

struct AdventurerProfileCard: View {
    let totalXP: Int
    let level: Int
    
    var body: some View {
        HStack(spacing: 20) {
            // Avatar
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "person.crop.circle.fill") // Placeholder for wizard
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .foregroundColor(PixelTheme.secondary)
                    .background(Circle().fill(PixelTheme.background))
                    .overlay(Circle().stroke(PixelTheme.secondary, lineWidth: 2))
                
                Text("\(level)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(PixelTheme.primary))
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .offset(x: 4, y: 4)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 8) {
                Text("Focus Master") // Title
                    .font(.system(.title3, design: .serif))
                    .fontWeight(.bold)
                    .foregroundColor(PixelTheme.textPrimary)
                
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.gray.opacity(0.2))
                            Capsule().fill(
                                LinearGradient(colors: [PixelTheme.success, PixelTheme.success.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: geo.size.width * 0.45) // Example progress
                        }
                    }
                    .frame(height: 8)
                    
                    HStack {
                        Text("\(totalXP) XP")
                        Spacer()
                        Text("\((level + 1) * 1000) XP")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(PixelTheme.textSecondary)
                }
            }
        }
        .padding(24)
        .background(
            LinearGradient(colors: [Color.white, Color(hex: "#F9F5EC")], startPoint: .top, endPoint: .bottom)
        )
        .cornerRadius(24)
        .shadow(color: PixelTheme.cardShadow, radius: 12, x: 0, y: 4)
    }
}

struct AdventurerStatGrid: View {
    let dungeons: Int
    let gold: Int
    let quests: Int
    let streak: Int
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            InfoTile(icon: "timer", label: "SESSIONS", value: "\(dungeons)", color: PixelTheme.secondary)
            InfoTile(icon: "clock.fill", label: "MINUTES", value: "\(gold)", color: PixelTheme.primary)
            InfoTile(icon: "checkmark.circle.fill", label: "QUESTS", value: "\(quests)", color: PixelTheme.success)
            InfoTile(icon: "flame.fill", label: "STREAK", value: "\(streak)", color: PixelTheme.warning)
        }
    }
    
    private struct InfoTile: View {
        let icon: String
        let label: String
        let value: String
        let color: Color
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .padding(10)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(PixelTheme.textSecondary)
                    
                    Text(value)
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(PixelTheme.textPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: PixelTheme.cardShadow, radius: 8, x: 0, y: 2)
        }
    }
}

struct AdventurerRangeChart: View {
    let bars: [WeekBar]
    let range: StatsTimeRange
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(bars) { bar in
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 6)
                                .fill(bar.total > 0 ? PixelTheme.primary : Color.gray.opacity(0.1))
                                .frame(height: max(4, min(CGFloat(bar.focused / 3600) / 4.0 * geo.size.height, geo.size.height))) // Scale roughly
                        }
                    }
                    
                    Text(labelForBar(bar.date, range: range))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isCurrentPeriod(bar.date, range: range) ? PixelTheme.primary : PixelTheme.textSecondary)
                }
            }
        }
    }
    
    private func labelForBar(_ date: Date, range: StatsTimeRange) -> String {
        let formatter = DateFormatter()
        switch range {
        case .day:
            return "Today"
        case .week:
            formatter.dateFormat = "E"
            return String(formatter.string(from: date).prefix(1))
        case .year:
            formatter.dateFormat = "MMM"
            return String(formatter.string(from: date).prefix(3))
        }
    }
    
    private func isCurrentPeriod(_ date: Date, range: StatsTimeRange) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        
        switch range {
        case .day:
            return calendar.isDate(date, inSameDayAs: today)
        case .week:
            return calendar.isDate(date, inSameDayAs: today)
        case .year:
            return calendar.isDate(date, equalTo: today, toGranularity: .month)
        }
    }
}

struct AdventurerQuestMap: View {
    @ObservedObject var viewModel: StatsViewModel
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 20) // Simplified grid
    
    var body: some View {
        // We render a subset of the grid/heatmap
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(viewModel.gridDates.suffix(140), id: \.self) { date in // Last 140 days approx
                RoundedRectangle(cornerRadius: 2)
                    .fill(color(for: date))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }
    
    func color(for date: Date) -> Color {
        let day = Calendar.current.startOfDay(for: date)
        let level = viewModel.heatmapData[day] ?? 0
        switch level {
        case 0: return PixelTheme.woodLight.opacity(0.15)
        case 1: return PixelTheme.success.opacity(0.3)
        case 2: return PixelTheme.success.opacity(0.5)
        case 3: return PixelTheme.success.opacity(0.7)
        case 4: return PixelTheme.success
        default: return PixelTheme.success
        }
    }
}

struct FeatRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    var badge: String? = nil
    var xp: String? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .padding(12)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(PixelTheme.textPrimary)
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(PixelTheme.textSecondary)
            }
            
            Spacer()
            
            if let xp = xp {
                Text(xp)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(PixelTheme.primary)
            }
            
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(PixelTheme.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PixelTheme.success.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: PixelTheme.cardShadow, radius: 4, x: 0, y: 2)
    }
}

