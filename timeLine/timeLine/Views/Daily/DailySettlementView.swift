import SwiftUI
import TimeLineCore

struct DailySettlementView: View {
    @EnvironmentObject var engine: BattleEngine
    @Environment(\.dismiss) var dismiss
    
    // Filter to show only today's specimens
    var todaysSpecimens: [CollectedSpecimen] {
        return engine.specimenCollection.specimens(for: Date())
    }
    
    var totalObservationTime: TimeInterval {
        todaysSpecimens.reduce(0) { $0 + $1.duration }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                PixelTheme.surface.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Field Journal")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(PixelTheme.primary)
                            
                            Text(Date().formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(PixelTheme.secondary)
                        }
                        .padding(.top, 20)
                        
                        // Summary Stats
                        HStack(spacing: 40) {
                            StatItem(
                                label: "Specimens",
                                value: "\(todaysSpecimens.count)",
                                icon: "leaf.fill"
                            )
                            StatItem(
                                label: "Observation",
                                value: formatDuration(totalObservationTime),
                                icon: "clock.fill"
                            )
                        }
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(PixelTheme.surface)
                                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                        )
                        .padding(.horizontal)
                        
                        // Quality Legend
                        HStack(spacing: 16) {
                            LegendItem(label: "Perfect", color: .green)
                            LegendItem(label: "Good", color: .blue)
                            LegendItem(label: "Flawed", color: .orange)
                            LegendItem(label: "Fled", color: .gray)
                        }
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        
                        // Specimens Grid
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                            ForEach(todaysSpecimens) { specimen in
                                SpecimenCard(specimen: specimen)
                            }
                        }
                        .padding()
                        
                        if todaysSpecimens.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "binoculars")
                                    .font(.system(size: 40))
                                    .foregroundColor(PixelTheme.secondary)
                                Text("No discoveries yet today.")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(PixelTheme.secondary)
                            }
                            .padding(.top, 40)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Subviews

struct StatItem: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(PixelTheme.accent)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(PixelTheme.primary)
            
            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(PixelTheme.secondary)
        }
    }
}

struct LegendItem: View {
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .foregroundColor(PixelTheme.secondary)
        }
    }
}

struct SpecimenCard: View {
    let specimen: CollectedSpecimen
    
    var qualityColor: Color {
        switch specimen.quality {
        case .perfect: return .green
        case .good: return .blue
        case .flawed: return .orange
        case .fled: return .gray
        }
    }
    
    var qualityIcon: String {
        switch specimen.quality {
        case .perfect: return "star.fill"
        case .good: return "star.leadinghalf.filled"
        case .flawed: return "exclamationmark.triangle"
        case .fled: return "wind"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(qualityColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: qualityIcon)
                            .font(.system(size: 14))
                            .foregroundColor(qualityColor)
                    )
                
                Spacer()
                
                Text(formatDuration(specimen.duration))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(PixelTheme.secondary)
            }
            
            Text(specimen.title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(specimen.quality == .fled ? .gray : PixelTheme.primary)
                .lineLimit(2)
            
            Text(specimen.quality.rawValue.capitalized)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(qualityColor)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(qualityColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes)m"
    }
}
