import SwiftUI

struct JumpToNowButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                
                Text("NOW")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.0)
            }
            .foregroundColor(PixelTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(hex: "E0D8C8")) // Slightly darker than cream for contrast
                    // Or reuse existing theme: PixelTheme.woodLight.opacity(0.2)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}
