import SwiftUI
import TimeLineCore

struct ResearchLogDrawer: View {
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var libraryStore: LibraryStore
    
    // Accordion State
    @State private var expandedTier: LibraryStore.LibraryTier = .today
    
    // Theme
    private let drawerBackground = Color.black.opacity(0.3)
    private let dividerColor = Color.white.opacity(0.1)
    
    /* 
     Icon mapping for LibraryStore.LibraryTier:
     .today      -> "sun.max.fill"
     .shortTerm  -> "calendar"
     .longTerm   -> "archivebox.fill"
     .frozen     -> "snowflake"
    */
    
    var body: some View {
        VStack(spacing: 0) {
            // Tier 1: Today
            TierHeader(tier: .today, title: "Today's Observation", icon: "sun.max.fill", isExpanded: expandedTier == .today) {
                withAnimation { expandedTier = .today }
            }
            if expandedTier == .today {
                TierContent(tier: .today, cardStore: cardStore, libraryStore: libraryStore)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Divider().overlay(dividerColor)
            
            // Tier 2: Short-term (3-10 days)
            TierHeader(tier: .shortTerm, title: "Short-term Survey", icon: "calendar", isExpanded: expandedTier == .shortTerm) {
                withAnimation { expandedTier = .shortTerm }
            }
            if expandedTier == .shortTerm {
                TierContent(tier: .shortTerm, cardStore: cardStore, libraryStore: libraryStore)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Divider().overlay(dividerColor)
            
            // Tier 3: Long-term (30+ days)
            TierHeader(tier: .longTerm, title: "Deep Research", icon: "archivebox.fill", isExpanded: expandedTier == .longTerm) {
                withAnimation { expandedTier = .longTerm }
            }
            if expandedTier == .longTerm {
                TierContent(tier: .longTerm, cardStore: cardStore, libraryStore: libraryStore)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Divider().overlay(dividerColor)
            
            // Tier 4: Frozen (Stale)
            TierHeader(tier: .frozen, title: "Cryogenic Storage", icon: "snowflake", isExpanded: expandedTier == .frozen) {
                withAnimation { expandedTier = .frozen }
            }
            if expandedTier == .frozen {
                TierContent(tier: .frozen, cardStore: cardStore, libraryStore: libraryStore)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(drawerBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

// MARK: - Subviews

private struct TierHeader: View {
    let tier: LibraryStore.LibraryTier
    let title: String
    let icon: String
    let isExpanded: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(isExpanded ? .white : .gray)
                
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(isExpanded ? .bold : .medium)
                    .foregroundStyle(isExpanded ? .white : .gray)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .rotationEffect(Angle(degrees: isExpanded ? 90 : 0))
            }
            .padding()
            .background(Color.white.opacity(0.01)) // Tappable area
        }
        .buttonStyle(.plain)
    }
}

private struct TierContent: View {
    let tier: LibraryStore.LibraryTier
    let cardStore: CardTemplateStore
    let libraryStore: LibraryStore
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(templatesForTier) { template in
                    SpecimenChip(template: template)
                        .onDrag {
                            NSItemProvider(object: "TEMPLATE:\(template.id.uuidString)" as NSString)
                        }
                }
                
                if templatesForTier.isEmpty {
                    Text("No specimens found")
                        .font(.caption)
                        .italic()
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .frame(height: 50)
    }
    
    private var templatesForTier: [CardTemplate] {
        let buckets = libraryStore.bucketedEntries(using: cardStore)
        let entries: [LibraryEntry]
        
        switch tier {
        case .today:
            entries = buckets.today
        case .shortTerm:
            entries = buckets.shortTerm
        case .longTerm:
            entries = buckets.longTerm
        case .frozen:
            entries = buckets.frozen
        }
        
        return entries.compactMap { cardStore.get(id: $0.templateId) }
    }
}
