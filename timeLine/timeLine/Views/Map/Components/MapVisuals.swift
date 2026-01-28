import SwiftUI
import TimeLineCore

// MARK: - Shared Map Visual Components

struct PixelHeroMarker: View {
    var body: some View {
        VStack(spacing: 0) {
            // "Pixel Sprite" Adventurer
            ZStack {
                // Head
                RoundedRectangle(cornerRadius: 2)
                    .fill(PixelTheme.woodDark)
                    .frame(width: 14, height: 14)
                    .offset(y: -10)
                
                // Body/Cape
                RoundedRectangle(cornerRadius: 3)
                    .fill(PixelTheme.vitality)
                    .frame(width: 18, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(PixelTheme.woodDark, lineWidth: 1.5)
                    )
                
                // Face Details (Bandana/Eyes)
                HStack(spacing: 4) {
                    Circle().fill(Color.white).frame(width: 2, height: 2)
                    Circle().fill(Color.white).frame(width: 2, height: 2)
                }
                .offset(y: -10)
            }
            // Shadow
            Ellipse()
                .fill(Color.black.opacity(0.2))
                .frame(width: 16, height: 4)
                .offset(y: 4)
        }
    }
}

struct InsertHint: View {
    let placement: DropPlacement

    var body: some View {
        let isAfter = placement == .after
        HStack(spacing: 6) {
            Image(systemName: isAfter ? "arrow.up" : "arrow.down")
                .font(.system(size: 10, weight: .bold))
            Text(isAfter ? "Drop to insert after" : "Drop to insert before")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .allowsHitTesting(false)
    }
}