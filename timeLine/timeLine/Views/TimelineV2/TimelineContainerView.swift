import SwiftUI

enum TimelineViewMode: String, CaseIterable {
    case vertical
    case verticalLegacy
    case horizontal
}

struct TimelineContainerView: View {
    // 1. Storage & State
    // Using MockTimelineStore for immediate preview as requested. 
    // In production, swap with TimelineV2Store()
    @StateObject private var store = MockTimelineStore()
    
    // Persisted Mode
    @AppStorage("timelineViewMode") private var viewMode: TimelineViewMode = .vertical
    
    // Navigation State
    @State private var isTodayVisible: Bool = true // Default to true to hide button initially
    @State private var horizontalSelection: Date = Date() // For Horizontal Mode Control
    
    // Internal Data Cache (View Model Layer)
    @State private var cachedDays: [TimelineDay] = []
    
    // Callback to open settings (passed from Root)
    var onOpenSettings: () -> Void = {}
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Background (Matches V1)
            PixelTheme.background
                .ignoresSafeArea()
            
            // Main Content
            Group {
                switch viewMode {
                case .vertical:
                    TimelineVerticalStackedView(
                        store: store,
                        days: cachedDays,
                        onToggleCompletion: store.toggleCompletion,
                        isTodayVisible: $isTodayVisible
                    )
                    .transition(.opacity.animation(.easeInOut))
                case .verticalLegacy:
                    TimelineVerticalView(
                        store: store,
                        days: cachedDays,
                        onToggleCompletion: store.toggleCompletion,
                        isTodayVisible: $isTodayVisible
                    )
                    .transition(.opacity.animation(.easeInOut))

                case .horizontal:
                    TimelineHorizontalPagerView(
                        days: cachedDays,
                        onToggleCompletion: store.toggleCompletion,
                        isTodayVisible: $isTodayVisible,
                        selection: $horizontalSelection
                    )
                    .id(viewMode) // Reset state on mode change
                    .transition(.opacity.animation(.easeInOut))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // "Now" Button
            if !isTodayVisible {
                Button(action: jumpToNow) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Now")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .clipShape(Capsule())
                    .shadow(radius: 4, y: 2)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 40)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Settings Button (Top Left)
            VStack {
                HStack {
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(PixelTheme.primary)
                            .padding(12)
                            .background(PixelTheme.surface)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .padding(.leading, 16)
                    .padding(.top, 8) // Adjust for Safe Area if needed
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            loadData()
        }
        .onChange(of: viewMode) { _, _ in
            // Reset visibility check when switching modes
            isTodayVisible = true 
            // Normalize Selection if needed
            if viewMode == .horizontal {
                horizontalSelection = Calendar.current.startOfDay(for: Date())
            }
        }
    }
    
    private func loadData() {
        cachedDays = store.loadDays()
        // Ensure horizontal selection matches a loaded day
        horizontalSelection = Calendar.current.startOfDay(for: Date())
    }
    
    private func jumpToNow() {
        withAnimation {
            if viewMode == .vertical {
                NotificationCenter.default.post(name: .scrollToTodayVertical, object: nil)
            } else {
                horizontalSelection = Calendar.current.startOfDay(for: Date())
            }
        }
    }
}
