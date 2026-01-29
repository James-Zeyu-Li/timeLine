import SwiftUI
import Foundation
import TimeLineCore

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
                Text("Focus Profile") // Title
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
                        Text("\(totalXP) pts")
                        Spacer()
                        Text("\((level + 1) * 1000) pts")
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
            InfoTile(icon: "checkmark.circle.fill", label: "TASKS", value: "\(quests)", color: PixelTheme.success)
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
        case .month:
            formatter.dateFormat = "d"
            return formatter.string(from: date)
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
        case .month:
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

struct AdventurerMonthHeatmap: View {
    @ObservedObject var viewModel: StatsViewModel
    
    var body: some View {
        let calendar = Calendar.current
        let range = calendar.dateInterval(of: .month, for: viewModel.rangeStart) ?? DateInterval(start: Date(), duration: 0)
        let monthDays = daysInMonth(range: range)
        
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
             ForEach(0..<monthDays.count, id: \.self) { index in
                if let date = monthDays[index] {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color(for: date))
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }
    
    private func daysInMonth(range: DateInterval) -> [Date?] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday start matching StatsViewModel
        
        let start = range.start
        let weekday = calendar.component(.weekday, from: start)
        // weekday: 1=Sun, 2=Mon... 7=Sat
        // We want Mon=0, Tue=1... Sun=6
        // If firstWeekday=2, then:
        // Mon(2) -> 0 => (2 - 2 + 7) % 7 = 0
        // Sun(1) -> 6 => (1 - 2 + 7) % 7 = 6
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        
        var dates: [Date?] = Array(repeating: nil, count: offset)
        
        var currentDate = start
        while currentDate < range.end {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        return dates
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

struct AdventurerDayLineChart: View {
    @ObservedObject var viewModel: StatsViewModel
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background Grid
                VStack {
                    Divider()
                    Spacer()
                    Divider()
                    Spacer()
                    Divider()
                }
                
                // The Line
                Path { path in
                    let width = geo.size.width
                    let height = geo.size.height
                    let data = viewModel.dayHourlyDistribution
                    let step = width / CGFloat(max(1, data.count - 1))
                    
                    let maxValue = data.max() ?? 60.0
                    let scale = maxValue > 0 ? height / maxValue : 1.0
                    
                    if data.count > 1 {
                        path.move(to: CGPoint(x: 0, y: height - (data[0] * scale)))
                        
                        for index in 1..<data.count {
                            let x = CGFloat(index) * step
                            let y = height - (data[index] * scale)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(PixelTheme.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .shadow(color: PixelTheme.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // Gradient Fill
                Path { path in
                    let width = geo.size.width
                    let height = geo.size.height
                    let data = viewModel.dayHourlyDistribution
                    let step = width / CGFloat(max(1, data.count - 1))
                    
                    let maxValue = data.max() ?? 60.0
                    let scale = maxValue > 0 ? height / maxValue : 1.0
                    
                    if data.count > 1 {
                        path.move(to: CGPoint(x: 0, y: height))
                        path.addLine(to: CGPoint(x: 0, y: height - (data[0] * scale)))
                        
                        for index in 1..<data.count {
                            let x = CGFloat(index) * step
                            let y = height - (data[index] * scale)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                }
                .fill(LinearGradient(
                    colors: [PixelTheme.primary.opacity(0.2), PixelTheme.primary.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            }
        }
    }
}
