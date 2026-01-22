import SwiftUI

struct HUDControlsView: View {
    let onZap: () -> Void
    let onBackpack: () -> Void
    let onSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            // Zap Button (Left) - Quick Action
            ZapButton(action: onZap)
                .accessibilityIdentifier("zapButton")
            
            // Backpack Button (Center-ish) - Inventory
            BackpackButton(action: onBackpack)
                .accessibilityIdentifier("backpackButton")
            
            // Settings Button (Right) - Tiny
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.4))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color(red: 0.95, green: 0.94, blue: 0.92))
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            .overlay(
                                Circle()
                                    .stroke(Color(red: 0.8, green: 0.7, blue: 0.6), lineWidth: 1)
                            )
                    )
            }
            .accessibilityIdentifier("settingsButton")
        }
        .padding(16)
    }
}
