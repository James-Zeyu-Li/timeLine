import SwiftUI

enum PixelTheme {
    // Base pixel grid (retina-friendly)
    static let baseUnit: CGFloat = 4
    
    // Corner + stroke rules
    static let cornerSmall: CGFloat = baseUnit
    static let cornerMedium: CGFloat = baseUnit * 2
    static let cornerLarge: CGFloat = baseUnit * 3
    static let strokeThin: CGFloat = 1
    static let strokeBold: CGFloat = 2
    
    // Shadow rules (single direction, soft drop)
    static let shadowOffset = CGSize(width: 0, height: 2)
    static let shadowRadius: CGFloat = 4
    static let shadowOpacity: Double = 0.15
    
    // Theme switching support
    @AppStorage("usePixelTheme") private static var usePixelTheme = true
    
    // Phase 16: Modern RPG Palette (V2.5)
    // Clean, Cream & Orange, High Readability
    
    // Backgrounds - Theme aware
    static var cream: Color {
        usePixelTheme ? Color(hex: "F9F5EC") : Color(hex: "F8F9FA")
    }
    
    static var background: Color { cream }
    static var backgroundBoard: Color { cream }
    
    // Card Surface - Theme aware
    static var cardBackground: Color {
        usePixelTheme ? Color.white : Color(hex: "FFFFFF")
    }
    
    static var cardShadow: Color {
        usePixelTheme ? Color.black.opacity(0.06) : Color.black.opacity(0.04)
    }
    
    // Accents - Theme aware
    static var primary: Color {
        usePixelTheme ? Color(hex: "F5A623") : Color(hex: "007AFF")
    }
    
    static var secondary: Color {
        usePixelTheme ? Color(hex: "8B572A") : Color(hex: "6C757D")
    }
    
    static var success: Color {
        usePixelTheme ? Color(hex: "7ED321") : Color(hex: "28A745")
    }
    
    static var warning: Color {
        usePixelTheme ? Color(hex: "D0021B") : Color(hex: "DC3545")
    }
    
    // Re-map to existing semantic names
    static var forest: Color { success }
    static var vitality: Color { primary }
    static var alert: Color { warning }
    static var woodDark: Color { secondary }
    static var woodMedium: Color { secondary.opacity(0.8) }
    static var woodLight: Color { secondary.opacity(0.6) }
    
    // Text - Theme aware
    static var textPrimary: Color {
        usePixelTheme ? Color(hex: "4A4A4A") : Color(hex: "1C1C1E")
    }
    
    static var textSecondary: Color {
        usePixelTheme ? Color(hex: "9B9B9B") : Color(hex: "8E8E93")
    }
    
    static let textInverted = Color(hex: "1a1b26")
    static let surface = Color(hex: "1a1b26") // Dark background matching textInverted or slightly lighter
    static let surfaceHighlight = Color(hex: "24283b")
        
    // Legacy / Compat
    static var backgroundTop: Color { background }
    static var backgroundBottom: Color { background }
    static var backgroundGrid: Color { secondary.opacity(0.05) }
    static var backgroundTile: Color { secondary.opacity(0.03) }

    static var cardTop: Color { Color.white }
    static var cardBottom: Color { Color.white }
    static var cardBorder: Color { Color.clear } // Modern style uses shadows, not borders
    static var cardGlow: Color { primary.opacity(0.4) }
    
    static var pathPixel: Color { secondary.opacity(0.2) } // Dashed line color
    static var accent: Color { primary } // Primary branding
    
    // Terrain (Unused now, but kept for compat)
    static var plains: Color { success.opacity(0.2) }
    static var cave: Color { textSecondary.opacity(0.2) }
    static var camp: Color { primary }
    
    static var petBody: Color { secondary }
    static var petShadow: Color { Color.black.opacity(0.1) }

    // Helper for Hex
    static func color(hex: String) -> Color {
        return Color(hex: hex)
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let r = (rgbValue & 0xff0000) >> 16
        let g = (rgbValue & 0x00ff00) >> 8
        let b = rgbValue & 0x0000ff
        
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: 1
        )
    }
}
