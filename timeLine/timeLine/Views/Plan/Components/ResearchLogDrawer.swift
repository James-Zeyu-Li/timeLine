import SwiftUI
import TimeLineCore

struct ResearchLogDrawer: View {
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var libraryStore: LibraryStore
    
    // Accordion State
    @State private var expandedTier: LibraryStore.LibraryTier = .deadline1
    
    // Theme
    private let drawerBackground = Color.black.opacity(0.3)
    private let dividerColor = Color.white.opacity(0.1)
    
    /* 
     Icon mapping for LibraryStore.LibraryTier:
     .deadline1  -> "sun.max.fill"
     .deadline3  -> "calendar"
     .deadline10 -> "clock"
     .deadline30 -> "archivebox.fill"
     .noDeadline -> "tray.full"
     .frozen     -> "snowflake"
    */
    
    var body: some View {
        VStack(spacing: 0) {
            // Tier 1: 1 Day
            TierHeader(tier: .deadline1, title: "1 Day Window", icon: "sun.max.fill", isExpanded: expandedTier == .deadline1) {
                withAnimation { expandedTier = .deadline1 }
            }
            if expandedTier == .deadline1 {
                TierContent(tier: .deadline1, cardStore: cardStore, libraryStore: libraryStore)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Divider().overlay(dividerColor)
            
            // Tier 2: 3 Days
            TierHeader(tier: .deadline3, title: "3 Day Window", icon: "calendar", isExpanded: expandedTier == .deadline3) {
                withAnimation { expandedTier = .deadline3 }
            }
            if expandedTier == .deadline3 {
                TierContent(tier: .deadline3, cardStore: cardStore, libraryStore: libraryStore)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Divider().overlay(dividerColor)
            
            // Tier 3: 10 Days
            TierHeader(tier: .deadline10, title: "10 Day Window", icon: "clock", isExpanded: expandedTier == .deadline10) {
                withAnimation { expandedTier = .deadline10 }
            }
            if expandedTier == .deadline10 {
                TierContent(tier: .deadline10, cardStore: cardStore, libraryStore: libraryStore)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider().overlay(dividerColor)

            // Tier 4: 30 Days+
            TierHeader(tier: .deadline30, title: "30 Day Window", icon: "archivebox.fill", isExpanded: expandedTier == .deadline30) {
                withAnimation { expandedTier = .deadline30 }
            }
            if expandedTier == .deadline30 {
                TierContent(tier: .deadline30, cardStore: cardStore, libraryStore: libraryStore)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider().overlay(dividerColor)

            // Tier 5: No Deadline
            TierHeader(tier: .noDeadline, title: "No Deadline", icon: "tray.full", isExpanded: expandedTier == .noDeadline) {
                withAnimation { expandedTier = .noDeadline }
            }
            if expandedTier == .noDeadline {
                TierContent(tier: .noDeadline, cardStore: cardStore, libraryStore: libraryStore)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Divider().overlay(dividerColor)
            
            // Tier 6: Frozen (Stale)
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
        case .deadline1:
            entries = buckets.deadline1
        case .deadline3:
            entries = buckets.deadline3
        case .deadline10:
            entries = buckets.deadline10
        case .deadline30:
            entries = buckets.deadline30
        case .noDeadline:
            entries = buckets.noDeadline
        case .frozen:
            entries = buckets.frozen
        }
        
        return entries.compactMap { cardStore.get(id: $0.templateId) }
    }
}
