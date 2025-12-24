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
    
    // Shadow rules (single direction, low blur)
    static let shadowOffset = CGSize(width: 0, height: 2)
    static let shadowRadius: CGFloat = 4
    static let shadowOpacity: Double = 0.18
    
    // Palette
    static let backgroundTop = Color(red: 0.10, green: 0.14, blue: 0.15)
    static let backgroundBottom = Color(red: 0.07, green: 0.11, blue: 0.10)
    static let backgroundGrid = Color.white.opacity(0.05)
    static let backgroundTile = Color.white.opacity(0.03)
    
    static let cardTop = Color(white: 0.13)
    static let cardBottom = Color(white: 0.09)
    static let cardBorder = Color(white: 0.22)
    static let cardGlow = Color.cyan.opacity(0.7)
    
    static let pathPixel = Color.white.opacity(0.14)
    static let textPrimary = Color.white
    static let textSecondary = Color.gray
    static let accent = Color.cyan
    
    // Terrain colors
    static let forest = Color(red: 0.20, green: 0.35, blue: 0.26)
    static let plains = Color(red: 0.36, green: 0.39, blue: 0.27)
    static let cave = Color(red: 0.28, green: 0.29, blue: 0.36)
    static let camp = Color(red: 0.40, green: 0.28, blue: 0.20)
    
    static let petBody = Color(red: 0.55, green: 0.60, blue: 0.62)
    static let petShadow = Color.black.opacity(0.2)
}
