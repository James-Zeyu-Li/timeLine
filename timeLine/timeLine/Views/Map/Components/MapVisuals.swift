import SwiftUI
import TimeLineCore

// MARK: - Shared Map Visual Components

struct PixelTrail: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 5
            let step: CGFloat = 9
            for y in stride(from: 0, to: size.height, by: step) {
                let rect = CGRect(x: 0, y: y, width: tile, height: tile)
                context.fill(Path(rect), with: .color(PixelTheme.pathPixel))
            }
        }
    }
}

struct PixelHeroMarker: View {
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(PixelTheme.petBody.opacity(0.25))
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(PixelTheme.petBody.opacity(0.7), lineWidth: 1)
                    )
                Image(systemName: "figure.walk")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(PixelTheme.textPrimary)
            }
            RoundedRectangle(cornerRadius: 1)
                .fill(PixelTheme.textPrimary.opacity(0.5))
                .frame(width: 6, height: 6)
        }
        .shadow(color: PixelTheme.petShadow, radius: 4, x: 0, y: 2)
    }
}

enum PixelTerrainType {
    case forest
    case plains
    case cave
    case campfire
}

struct PixelTerrainTile: View {
    let type: PixelTerrainType
    
    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let tile = PixelTheme.baseUnit * 2
                let rows = Int(size.height / tile)
                let cols = Int(size.width / tile)
                let palette = colors(for: type)
                
                for row in 0...rows {
                    for col in 0...cols {
                        if (row + col) % 2 == 0 {
                            let rect = CGRect(
                                x: CGFloat(col) * tile,
                                y: CGFloat(row) * tile,
                                width: tile - 1,
                                height: tile - 1
                            )
                            context.fill(Path(rect), with: .color(palette.base.opacity(0.7)))
                        }
                    }
                }
                
                for row in 0...rows {
                    for col in 0...cols {
                        if (row * col) % 7 == 0 {
                            let rect = CGRect(
                                x: CGFloat(col) * tile,
                                y: CGFloat(row) * tile,
                                width: tile,
                                height: tile
                            )
                            context.fill(Path(rect), with: .color(palette.accent.opacity(0.4)))
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: PixelTheme.cornerLarge))
    }
    
    private func colors(for type: PixelTerrainType) -> (base: Color, accent: Color) {
        switch type {
        case .forest:
            return (PixelTheme.forest, PixelTheme.forest.opacity(0.6))
        case .plains:
            return (PixelTheme.plains, PixelTheme.plains.opacity(0.6))
        case .cave:
            return (PixelTheme.cave, PixelTheme.cave.opacity(0.6))
        case .campfire:
            return (PixelTheme.camp, PixelTheme.camp.opacity(0.7))
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

// MARK: - Terrain Type Helper

extension PixelTerrainType {
    init(from node: TimelineNode) {
        switch node.type {
        case .bonfire:
            self = .campfire
        case .treasure:
            self = .plains
        case .battle(let boss):
            if boss.maxHp >= 3600 {
                self = .cave
            } else {
                switch boss.category {
                case .study:
                    self = .forest
                case .work:
                    self = .plains
                case .gym, .rest:
                    self = .plains
                case .other:
                    self = .forest
                }
            }
        }
    }
}