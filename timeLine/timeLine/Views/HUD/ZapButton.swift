import SwiftUI

struct ZapButton: View {
    let action: () -> Void
    
    // Pulse animation state
    @State private var isPulsing = false
    
    var body: some View {
        Button(action: {
            Haptics.impact(.medium)
            action()
        }) {
            ZStack {
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
                
                // Icon
                Image(systemName: "bolt.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
