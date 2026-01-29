import SwiftUI

struct TimelineVerticalView: View {
    @ObservedObject var store: TimelineV2Store
    let days: [TimelineDay] // Pre-loaded
    let onToggleCompletion: (TimelineTask) -> Void
    @Binding var isTodayVisible: Bool
    
    // Internal for scrolling
    @State private var todayID: Date?
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(days) { day in
                        TimelineDayView(day: day, onToggleCompletion: onToggleCompletion)
                            .id(day.date) // ID for scrolling
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onChange(of: geo.frame(in: .named("VerticalScrollSpace"))) { _, frame in
                                            checkVisibility(for: day, frame: frame)
                                        }
                                }
                            )
                            // iOS 17 Scroll Snapping
                            .scrollTargetLayout()
                    }
                }
                .scrollTargetBehavior(.viewAligned)
                .coordinateSpace(name: "VerticalScrollSpace")
            }
            .onAppear {
                // Find today ID
                if let today = days.first(where: { Calendar.current.isDateInToday($0.date) }) {
                    todayID = today.date
                    // Initial scroll to today after a short delay to let layout settle
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(today.date, anchor: .top)
                    }
                }
            }
            // Listen for external "Scroll To Now" requests?
            // User requirement: "Now" button is tapped -> scrolls to Today.
            // This view usually owns the proxy. 
            // We can add a .onChange(of: trigger) if needed, OR exposing a closure is hard in SwiftUI.
            // Best pattern: ScrollViewReader is local. 
            // If the Button is in the Container, we need a trigger Binding.
            .onReceive(NotificationCenter.default.publisher(for: .scrollToTodayVertical)) { _ in
                if let todayID {
                    withAnimation {
                        proxy.scrollTo(todayID, anchor: .top)
                    }
                }
            }
        }
    }
    
    private func checkVisibility(for day: TimelineDay, frame: CGRect) {
        // Only care about Today
        guard Calendar.current.isDateInToday(day.date) else { return }
        
        // Simple visibility check: Does it intersect with the visible area?
        // Visible area in "VerticalScrollSpace" is roughly 0...ViewportHeight
        // We can approximate ViewportHeight or just check relative to 0.
        // If frame.maxY < 0 (above) or frame.minY > viewport (below), it's hidden.
        // Since we don't have exact viewport height here easily without GeometryReader on ScrollView,
        // we can assume a safe range. Or pass viewport height.
        // Better: Use minY. If it's roughly on screen.
        
        // Heuristic: If top is within -Height ... +Height.
        // Actually, frame.minY is relative to the ScrollView's top-left (0,0).
        // If minY is between 0 and ScreenHeight, it's detected.
        // Actually, let's keep it simple:
        // Use a preference key preference for robust visibility?
        // For now, let's assume standard screen height < 1000.
        let isVisible = frame.maxY > 0 && frame.minY < 1000 
        
        // Debounce or direct update?
        if isTodayVisible != isVisible {
            isTodayVisible = isVisible
        }
    }
}

extension Notification.Name {
    static let scrollToTodayVertical = Notification.Name("scrollToTodayVertical")
}
