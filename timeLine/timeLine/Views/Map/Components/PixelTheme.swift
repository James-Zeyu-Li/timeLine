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
    
    // Phase 16: Modern RPG Palette (V2.5)
    // Clean, Cream & Orange, High Readability
    
    // Backgrounds
    static let cream = Color(hex: "F9F5EC") // Soft Cream Base
    static let background = cream
    static let backgroundBoard = cream // Unified bg
    
    // Card Surface
    static let cardBackground = Color.white
    static let cardShadow = Color.black.opacity(0.06)
    
    // Accents
    static let primary = Color(hex: "F5A623") // Golden Orange
    static let secondary = Color(hex: "8B572A") // Leather Brown
    static let success = Color(hex: "7ED321") // Quest Green
    static let warning = Color(hex: "D0021B") // Alert Red
    
    // Re-map to existing semantic names
    static let forest = success
    static let vitality = primary
    static let alert = warning
    static let woodDark = secondary
    static let woodMedium = secondary.opacity(0.8)
    static let woodLight = secondary.opacity(0.6)
    
    // Text
    static let textPrimary = Color(hex: "4A4A4A") // Soft Black
    static let textSecondary = Color(hex: "9B9B9B") // Medium Gray
    static let textInverted = Color.white
        
    // Legacy / Compat
    static let backgroundTop = background
    static let backgroundBottom = background
    static let backgroundGrid = secondary.opacity(0.05)
    static let backgroundTile = secondary.opacity(0.03)

    static let cardTop = Color.white
    static let cardBottom = Color.white
    static let cardBorder = Color.clear // Modern style uses shadows, not borders
    static let cardGlow = primary.opacity(0.4)
    
    static let pathPixel = secondary.opacity(0.2) // Dashed line color
    static let accent = primary // Primary branding
    
    // Terrain (Unused now, but kept for compat)
    static let plains = success.opacity(0.2)
    static let cave = textSecondary.opacity(0.2)
    static let camp = primary
    
    static let petBody = secondary
    static let petShadow = Color.black.opacity(0.1)

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
            red: Double(r) / 0.255,
            green: Double(g) / 0.255,
            blue: Double(b) / 0.255,
            opacity: 1
        )
    }
}
