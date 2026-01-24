import SwiftUI

struct ZapButton: View {
    let action: () -> Void
    
    // Pulse animation state
    @State private var isPulsing = false
    // Lightning animation state
    @State private var showLightning = false
    
    var body: some View {
        Button(action: {
            // Trigger lightning animation
            withAnimation(.easeOut(duration: 0.3)) {
                showLightning = true
            }
            
            // Reset lightning after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showLightning = false
            }
            
            Haptics.impact(.medium)
            action()
        }) {
            ZStack {
                // Lightning effect overlay (appears on tap)
                if showLightning {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 64, height: 64)
                        .scaleEffect(1.2)
                        .opacity(showLightning ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.15), value: showLightning)
                }
                
                // Outer glow/pulse
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.yellow.opacity(0.3))
                    .frame(width: 64, height: 64)
                    .scaleEffect(isPulsing ? 1.08 : 1.0)
                    .opacity(isPulsing ? 0.6 : 0.0)
                
                // Main Button Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: .orange.opacity(0.4), radius: 6, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
                
                // Icon with lightning effect
                Image(systemName: "bolt.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(showLightning ? .black : .white)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .scaleEffect(showLightning ? 1.1 : 1.0)
                    .animation(.easeOut(duration: 0.15), value: showLightning)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
