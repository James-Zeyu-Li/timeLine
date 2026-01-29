import SwiftUI
import TimeLineCore

struct TimelineHeaderView: View {
    let currentChapter: Int
    let journeyTitle: String
    let currentLevel: Int
    let totalFocusedTime: TimeInterval
    let completionProgress: Double
    @Binding var isEditMode: Bool
    @Binding var showStats: Bool
    @Binding var statsInitialRange: StatsTimeRange?
    
    var body: some View {
        let levelColor = Color(red: 0.6, green: 0.5, blue: 0.4)
        
        VStack(spacing: 0) {
            // Chapter header
            HStack {
                Image(systemName: "book.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(levelColor)
                Text("WEEK \(currentChapter)")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(levelColor)
                Spacer()
                
                // Edit button
                Button(action: { isEditMode.toggle() }) {
                    Text(isEditMode ? "Done" : "Edit")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(PixelTheme.primary)
                }
                
                Button(action: { showStats = true }) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(levelColor)
                }
                .padding(.leading, 12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Journey title and progress
            VStack(alignment: .leading, spacing: 8) {
                Text(journeyTitle)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.1))
                
                HStack {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 12))
                        .foregroundColor(levelColor)
                    Text("\(Int(totalFocusedTime / 60))m")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(levelColor)
                    
                    Spacer()
                    
                    Text("LEVEL \(currentLevel)")
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(levelColor)
                }
                
                // Progress bar
                ProgressView(value: completionProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 1.0, green: 0.6, blue: 0.2)))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        statsInitialRange = .day
                        showStats = true
                    }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}
