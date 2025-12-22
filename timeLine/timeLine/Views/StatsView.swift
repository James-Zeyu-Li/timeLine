import SwiftUI
import TimeLineCore

struct StatsView: View {
    @StateObject var viewModel = StatsViewModel()
    @EnvironmentObject var engine: BattleEngine
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 40) {
                    // Weekly Summary Row
                    HStack(spacing: 16) {
                        SummaryCard(title: "FOCUSED", value: viewModel.weeklyFocusedText, color: .green)
                        SummaryCard(title: "WASTED", value: viewModel.weeklyWastedText, color: .red)
                        SummaryCard(title: "SESSIONS", value: viewModel.sessionsCountText, color: .white)
                    }
                    .padding(.horizontal)
                    
                    // Heatmap Section
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
                    
                    Spacer()
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
        }
        .preferredColorScheme(.dark)
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
