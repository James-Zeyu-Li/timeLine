import SwiftUI

struct BackpackButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            Haptics.impact(.light)
            action()
        }) {
            ZStack {
                // Background
                Circle()
                    .fill(Color(red: 0.2, green: 0.15, blue: 0.1)) // Leather Brown
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .overlay(
                        Circle()
                            .stroke(Color(red: 0.35, green: 0.25, blue: 0.15), lineWidth: 2)
                    )
                
                // Icon
                Image(systemName: "backpack.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(red: 0.8, green: 0.7, blue: 0.5)) // Canvas Beige
            }
        }
    }
}
