import SwiftUI
import TimeLineCore

struct SpecimenChip: View {
    let template: CardTemplate
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: template.icon)
                .font(.system(size: 10))
                .foregroundColor(isSelected ? .white : template.category.color)
            
            Text(template.title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .lineLimit(1)
                .foregroundColor(isSelected ? .white : PixelTheme.textPrimary)
            
            Text(TimeFormatter.formatDuration(template.defaultDuration))
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundColor(isSelected ? .white.opacity(0.8) : PixelTheme.textPrimary.opacity(0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSelected ? PixelTheme.primary : PixelTheme.cardBackground)
                .shadow(color: PixelTheme.cardShadow.opacity(0.2), radius: 2, x: 0, y: 1)
        )
        .overlay(
            Capsule()
                .stroke(PixelTheme.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
