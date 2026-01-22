import SwiftUI

struct PlanButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            Haptics.impact(.light)
            action()
        }) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.306, green: 0.486, blue: 0.196), // Forest Green
                                Color(red: 0.22, green: 0.38, blue: 0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: Color(red: 0.306, green: 0.486, blue: 0.196).opacity(0.4), radius: 4, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                // Icon
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}
