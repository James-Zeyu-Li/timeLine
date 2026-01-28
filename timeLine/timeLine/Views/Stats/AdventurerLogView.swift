import SwiftUI
import TimeLineCore

struct AdventurerLogView: View {
    @StateObject var viewModel = StatsViewModel()
    @EnvironmentObject var engine: BattleEngine
    @Environment(\.presentationMode) var presentationMode
    
    @State var showSettings = false
    
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
        .onChange(of: engine.history) { _, newHistory in
            viewModel.processHistory(
                newHistory,
                specimens: engine.specimenCollection
            )
        }
        .onChange(of: engine.specimenCollection) { _, newSpecimens in
            viewModel.processHistory(
                engine.history,
                specimens: newSpecimens
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    func openSettings() {
        showSettings = true
    }
}
