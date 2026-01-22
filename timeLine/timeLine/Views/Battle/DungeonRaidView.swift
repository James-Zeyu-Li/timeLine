import SwiftUI
import TimeLineCore

struct DungeonRaidView: View {
    let enemies: [EnemyNode]
    @EnvironmentObject var engine: BattleEngine
    
    var body: some View {
        VStack(spacing: 24) {
            // Main Timer
            VStack(spacing: 8) {
                Text("DUNGEON RAID")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.8))
                
                Text(timeDisplayString)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            .padding(.top, 40)
            
            // Enemies List (Placeholder)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(enemies) { enemy in
                        VStack {
                            Circle()
                                .fill(enemy.isDefeated ? Color.gray : Color.red)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "skull.fill")
                                        .foregroundColor(.white)
                                )
                            Text(enemy.title)
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 100)
            
            Spacer()
        }
        .background(Color.black.opacity(0.8)) // Dark dungeon bg
    }

    private var timeDisplayString: String {
        let time = engine.remainingTime ?? 0
        return TimeFormatter.formatTimer(time)
    }
}
