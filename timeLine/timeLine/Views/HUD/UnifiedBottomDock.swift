import SwiftUI

struct UnifiedBottomDock: View {
    let onZap: () -> Void
    let onPlan: () -> Void
    let onBackpack: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Plan Button (Left)
            Button(action: onPlan) {
                ZStack {
                    Circle()
                        .fill(PixelTheme.forest) // Green
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "doc.text.fill") // or list.clipboard
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Zap Button (Center - Prominent)
            Button(action: onZap) {
                ZStack {
                    Circle()
                        .fill(PixelTheme.vitality) // Orange
                        .frame(width: 56, height: 56)
                        .shadow(color: PixelTheme.vitality.opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .offset(y: -4) // Slight pop-up effect
            
            // Backpack/Stats Button (Right)
            Button(action: onBackpack) {
                ZStack {
                    Circle()
                        .fill(PixelTheme.woodDark) // Dark Brown
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "backpack.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)
        )
    }
}

// Reuse existing ScaleButtonStyle if available, or define local one for now
fileprivate struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
