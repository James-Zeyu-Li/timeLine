import SwiftUI
import TimeLineCore

struct MasterClockView: View {
    @EnvironmentObject var masterClock: MasterClockService
    @EnvironmentObject var engine: BattleEngine
    
    var body: some View {
        HStack(spacing: 16) {
            // 1. Time Display
            VStack(alignment: .leading, spacing: 2) {
                Text(formatTime(masterClock.currentTime))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(masterClock.timeOfDay.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: masterClock.timeOfDay.colorHex))
            }
            
            // 2. Day Progress Bar (with Shadow visualization)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    // Progress
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#FF9E80"), Color(hex: "#80D8FF"), Color(hex: "#1A237E")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(masterClock.dayProgress), height: 8)
                    
                    // Shadow Overlay (Pressure)
                    // If shadow is accumulated, show it as a dark overlay from the current time backwards
                    // For visualization simplicity in V0, standard progress bar is fine.
                    // Shadow can be a separate bar or overlay.
                }
            }
            .frame(height: 8)
            
            // 3. Shadow Indicator
            if engine.shadowAccumulated > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "cloud.rain.fill")
                        .font(.caption)
                    Text(TimeFormatter.formatDuration(engine.shadowAccumulated))
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundColor(.black.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.8))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Material.thin)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// Helper for Hex Color
// Color(hex:) extension removed (provided by TimeLineCore)
