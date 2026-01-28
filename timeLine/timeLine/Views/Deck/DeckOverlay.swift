import SwiftUI
import TimeLineCore

// MARK: - Deck Overlay

struct DeckOverlay: View {
    let tab: DeckTab
    let isDimmed: Bool
    let allowedTabs: [DeckTab]
    
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var appMode: AppModeManager
    
    init(tab: DeckTab, isDimmed: Bool = false, allowedTabs: [DeckTab] = DeckTab.allCases) {
        self.tab = tab
        self.isDimmed = isDimmed
        self.allowedTabs = allowedTabs
    }
    
    var body: some View {
        GeometryReader { proxy in
            let maxHeight = proxy.size.height
            let expandedHeight = min(maxHeight * 0.5, 450)  // Reduced from 0.6 to 0.5, and from 520 to 450
            let collapsedHeight = min(maxHeight * 0.35, 300)  // Reduced from 0.42 to 0.35, and from 360 to 300
            let sheetHeight = isDimmed ? collapsedHeight : expandedHeight
            
            ZStack(alignment: .bottom) {
                Color.black.opacity(isDimmed ? 0.0 : 0.75)  // Increased from 0.45 to 0.75 for less transparency
                    .ignoresSafeArea()
                    .accessibilityIdentifier("deckOverlayBackground")
                    .allowsHitTesting(!isDimmed)
                    .onTapGesture {
                        if !isDimmed {
                            appMode.closeDeck()
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if !isDimmed && value.translation.height > 80 {
                                    appMode.exitToHome()
                                }
                            }
                    )
                
                sheetContent
                    .frame(maxWidth: .infinity)
                    .frame(height: sheetHeight)
                    .background(sheetBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(sheetBorder)
                    .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: -4)
                    .padding(.horizontal, 12)
                    .padding(.bottom, proxy.safeAreaInsets.bottom + 8)
            }
        }
    }

    private var sheetContent: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(red: 0.6, green: 0.5, blue: 0.4).opacity(0.3)) // 温暖棕色
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 10)
            
            // Tip prompt
            if !isDimmed {
                Text(tipText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.4)) // 温暖棕色
                    .padding(.bottom, 10)
            }
            
            // Tab bar
            if !isDimmed {
                tabBar
                    .padding(.bottom, 6)
            }
            
            // Content based on tab
            Group {
                switch activeTab {
                case .cards:
                    CardFanView(tab: activeTab)
                case .library:
                    LibraryTabView()
                case .decks:
                    DecksTabView()
                }
            }
            .padding(.bottom, 16)
        }
    }

    private var sheetBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.94, blue: 0.92), // 浅米色背景 (Chapter theme)
                        Color(red: 0.6, green: 0.5, blue: 0.4).opacity(0.1) // 温暖棕色
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private var sheetBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
    }

    private var tipText: String {
        switch activeTab {
        case .cards:
            return "Tap a card to save it"
        case .library:
            return "Drag a task to the map, or select to group"
        case .decks:
            return "Drag a deck onto the map"
        }
    }
    
    private var activeTab: DeckTab {
        guard allowedTabs.contains(tab) else {
            return allowedTabs.first ?? tab
        }
        return tab
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 24) {
            ForEach(allowedTabs, id: \.self) { t in
                Button {
                    appMode.enter(.deckOverlay(t))
                } label: {
                    Text(tabTitle(t))
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(activeTab == t ? .bold : .medium)
                        .foregroundColor(activeTab == t ? Color(red: 0.2, green: 0.15, blue: 0.1) : Color(red: 0.6, green: 0.5, blue: 0.4)) // Chapter theme colors
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(activeTab == t ? Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.2) : Color.clear) // Chapter activity orange
                        )
                }
            }
        }
    }

    private func tabTitle(_ tab: DeckTab) -> String {
        switch tab {
        case .cards:
            return "Items"
        case .library:
            return "Backlog"
        case .decks:
            return "Plans"
        }
    }
}
