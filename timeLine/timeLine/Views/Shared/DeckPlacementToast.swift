import SwiftUI

struct DeckPlacementToast: View {
    let title: String
    let onUndo: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.cyan)
            
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            Button("Undo") {
                onUndo()
            }
            .font(.system(.subheadline, design: .rounded))
            .fontWeight(.semibold)
            .foregroundColor(.cyan)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }
}
