import SwiftUI

struct HUDControlsView: View {
    let onZap: () -> Void
    let onPlan: () -> Void
    let onBackpack: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Zap Button (Left) - Quick Action
            ZapButton(action: onZap)
                .accessibilityIdentifier("zapButton")
            
            // Plan Button (Center) - Daily Planning
            PlanButton(action: onPlan)
                .accessibilityIdentifier("planButton")
            
            // Backpack Button (Right) - Inventory
            BackpackButton(action: onBackpack)
                .accessibilityIdentifier("backpackButton")
        }
        .padding(16)
    }
}
