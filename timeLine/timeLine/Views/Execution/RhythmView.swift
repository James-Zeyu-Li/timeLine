import SwiftUI
import TimeLineCore

struct RhythmView: View {
    @EnvironmentObject var engine: BattleEngine
    
    // Cycle Constants
    private let focusDuration: TimeInterval = 50 * 60
    private let restDuration: TimeInterval = 10 * 60
    
    var body: some View {
        HStack {
            // Cycle Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                    .frame(width: 40, height: 40)
                
                // Progress Arc
                Circle()
                    .trim(from: 0, to: cycleProgress)
                    .stroke(cycleColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 40, height: 40)
                
                // Icon
                Image(systemName: cycleIcon)
                    .font(.caption2)
                    .foregroundColor(cycleColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(cycleStateName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(remainingTimeText)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Skip/Action Button (Optional)
            if engine.state == .resting {
                Button(action: { engine.endRest() }) {
                    Image(systemName: "forward.end.fill")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
    
    private var cycleProgress: CGFloat {
        guard let elapsed = engine.currentSessionElapsed() else { return 0 }
        
        if engine.state == .fighting {
            // Focus Phase (50m target)
            return min(1.0, elapsed / focusDuration)
        } else if engine.state == .resting {
            // Rest Phase (10m target)
            return min(1.0, elapsed / restDuration)
        }
        return 0
    }
    
    private var cycleColor: Color {
        engine.state == .resting ? .green : .blue
    }
    
    private var cycleIcon: String {
        engine.state == .resting ? "cup.and.saucer.fill" : "flame.fill"
    }
    
    private var cycleStateName: String {
        engine.state == .resting ? "Recharge" : "Focus Rhythm"
    }
    
    private var remainingTimeText: String {
        guard let elapsed = engine.currentSessionElapsed() else { return "--:--" }
        
        let target = engine.state == .resting ? restDuration : focusDuration
        let remaining = max(0, target - elapsed)
        return TimeFormatter.formatDuration(remaining)
    }
}
