import SwiftUI
import TimeLineCore

struct StatsView: View {
    @StateObject var viewModel = StatsViewModel()
    @EnvironmentObject var engine: BattleEngine
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedRange: StatsRange = .week
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    Picker("Range", selection: $selectedRange) {
                        ForEach(StatsRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if selectedRange == .week {
                        weekView
                    } else {
                        yearView
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("History")
                        .font(.system(.title, design: .rounded))
                        .bold()
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            viewModel.processHistory(engine.history)
            selectedDate = Calendar.current.startOfDay(for: Date())
        }
        .preferredColorScheme(.dark)
    }
    
    private var weekView: some View {
        VStack(spacing: 24) {
            HStack(spacing: 16) {
                SummaryCard(title: "FOCUSED", value: viewModel.weeklyFocusedText, color: .green)
                SummaryCard(title: "WASTED", value: viewModel.weeklyWastedText, color: .red)
                SummaryCard(title: "SESSIONS", value: viewModel.sessionsCountText, color: .white)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("THIS WEEK")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(weekRangeText)
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.6))
                }
                .padding(.horizontal)
                
                WeekBarChart(
                    bars: viewModel.weekBars,
                    selectedDate: selectedDate,
                    onSelect: { date in
                        selectedDate = date
                    }
                )
                .padding(.horizontal, 16)
                
                DayDetailCard(bar: selectedBar, date: selectedDate)
                    .padding(.horizontal)
            }
        }
    }
    
    private var yearView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("CONSISTENCY")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.gray)
                Spacer()
                Text("Last 365 Days")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.horizontal)
            
            HeatmapView(viewModel: viewModel)
                .padding(20)
                .background(Color(white: 0.05))
                .cornerRadius(16)
                .padding(.horizontal)
        }
    }
    
    private var selectedBar: WeekBar? {
        viewModel.weekBars.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    private var weekRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: viewModel.weekStart)
        let end = formatter.string(from: viewModel.weekEnd)
        return "\(start) - \(end)"
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(.gray)
                .lineLimit(1)
            
            Text(value)
                .font(.system(.title3, design: .monospaced)) // Monospaced for numbers
                .bold()
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
}

struct HeatmapView: View {
    @ObservedObject var viewModel: StatsViewModel
    
    let rows = Array(repeating: GridItem(.fixed(10), spacing: 4), count: 7) // Smaller cells for tighter grid
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: rows, spacing: 4) {
                ForEach(viewModel.gridDates, id: \.self) { date in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: date))
                        .frame(width: 10, height: 10)
                }
            }
        }
    }
    
    func color(for date: Date) -> Color {
        // Normalize
        let day = Calendar.current.startOfDay(for: date)
        let level = viewModel.heatmapData[day] ?? 0
        
        // GitHub-like shades of Green, but on Dark Mode
        switch level {
        case 0: return Color(white: 0.15) // Empty
        case 1: return Color.green.opacity(0.3)
        case 2: return Color.green.opacity(0.5)
        case 3: return Color.green.opacity(0.7)
        case 4: return Color.green
        default: return Color.green
        }
    }
}

private enum StatsRange: String, CaseIterable, Identifiable {
    case week
    case year
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .week: return "Week"
        case .year: return "Year"
        }
    }
}

private struct WeekBarChart: View {
    let bars: [WeekBar]
    let selectedDate: Date
    let onSelect: (Date) -> Void
    
    private let maxBarHeight: CGFloat = 160
    
    var body: some View {
        let maxTotal = max(bars.map { $0.total }.max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(bars) { bar in
                let isToday = Calendar.current.isDateInToday(bar.date)
                let isSelected = Calendar.current.isDate(bar.date, inSameDayAs: selectedDate)
                let totalHeight = CGFloat(bar.total / maxTotal) * maxBarHeight
                let focusedHeight = bar.total > 0 ? totalHeight * CGFloat(bar.focused / bar.total) : 0
                let wastedHeight = bar.total > 0 ? totalHeight * CGFloat(bar.wasted / bar.total) : 0
                
                Button(action: { onSelect(bar.date) }) {
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(white: 0.15))
                                .frame(width: 20, height: maxBarHeight)
                            
                            if bar.total > 0 {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.red.opacity(0.5))
                                    .frame(width: 20, height: wastedHeight)
                                
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.green.opacity(0.8))
                                    .frame(width: 20, height: focusedHeight)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isToday ? Color.white.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                        
                        Text(dayLabel(for: bar.date))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(isToday ? .white : .gray)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
    }
    
    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

private struct DayDetailCard: View {
    let bar: WeekBar?
    let date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dayTitle)
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                statBlock(title: "Focused", value: TimeFormatter.formatStats(bar?.focused ?? 0), color: .green)
                statBlock(title: "Wasted", value: TimeFormatter.formatStats(bar?.wasted ?? 0), color: .red)
                statBlock(title: "Sessions", value: "\(bar?.sessions ?? 0)", color: .white)
            }
        }
        .padding(16)
        .background(Color(white: 0.08))
        .cornerRadius(16)
    }
    
    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        return formatter.string(from: date)
    }
    
    private func statBlock(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundColor(.gray)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
