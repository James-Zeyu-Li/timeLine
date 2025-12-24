import SwiftUI
import Combine
import TimeLineCore

// MARK: - Bottom Sheet State
enum MapBottomSheetState {
    case collapsed
    case expanded
}

// MARK: - ViewModel
@MainActor
final class MapBottomSheetViewModel: ObservableObject {
    @Published var state: MapBottomSheetState = .collapsed
    @Published var dragOffset: CGFloat = 0
    
    var isExpanded: Bool { state == .expanded }
    
    func toggle() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            state = isExpanded ? .collapsed : .expanded
        }
    }
    
    func expand() {
        guard !isExpanded else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            state = .expanded
        }
    }
    
    func collapse() {
        guard isExpanded else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            state = .collapsed
        }
    }
    
    func handleDragEnd(velocity: CGFloat, threshold: CGFloat) {
        let shouldExpand = dragOffset < -threshold || velocity < -500
        let shouldCollapse = dragOffset > threshold || velocity > 500
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if isExpanded && shouldCollapse {
                state = .collapsed
            } else if !isExpanded && shouldExpand {
                state = .expanded
            }
            dragOffset = 0
        }
    }
}

// MARK: - MapBottomSheet
struct MapBottomSheet: View {
    @StateObject private var viewModel = MapBottomSheetViewModel()
    @Binding var showRoutinePicker: Bool
    let isLocked: Bool  // NEW: locked when overlay active
    
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var deckStore: DeckStore
    
    init(showRoutinePicker: Binding<Bool>, isLocked: Bool = false) {
        self._showRoutinePicker = showRoutinePicker
        self.isLocked = isLocked
    }
    
    // Layout constants
    private let collapsedHeight: CGFloat = 100
    private let grabberHeight: CGFloat = 24
    private let snapThreshold: CGFloat = 60
    
    var body: some View {
        GeometryReader { geo in
            let safeBottom = geo.safeAreaInsets.bottom
            let maxExpandedHeight = geo.size.height * 0.65
            let effectiveCollapsed = collapsedHeight + safeBottom
            let effectiveExpanded = maxExpandedHeight + safeBottom
            let collapsedInset = effectiveCollapsed + 16
            
            ZStack {
                // Dim overlay when expanded (only if not locked)
                if viewModel.isExpanded && !isLocked {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.collapse()
                        }
                        .transition(.opacity)
                }
                
                // Sheet content
                VStack(spacing: 0) {
                    Spacer()
                    
                    sheetContent(
                        collapsedHeight: effectiveCollapsed,
                        expandedHeight: isLocked ? effectiveCollapsed : effectiveExpanded,
                        safeBottom: safeBottom
                    )
                    .offset(y: viewModel.dragOffset)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.isExpanded)
            .onChange(of: appMode.mode) { _, newMode in
                guard !isLocked else { return }
                switch newMode {
                case .homeExpanded:
                    viewModel.expand()
                case .homeCollapsed:
                    viewModel.collapse()
                default:
                    viewModel.collapse()
                }
            }
            .onChange(of: isLocked) { _, locked in
                if locked {
                    viewModel.collapse()
                }
            }
            .onAppear {
                if isLocked {
                    viewModel.collapse()
                } else {
                    switch appMode.mode {
                    case .homeExpanded:
                        viewModel.expand()
                    case .homeCollapsed:
                        viewModel.collapse()
                    default:
                        viewModel.collapse()
                    }
                }
            }
            .preference(key: MapBottomSheetHeightKey.self, value: collapsedInset)
        }
    }
    
    // MARK: - Sheet Content
    @ViewBuilder
    private func sheetContent(
        collapsedHeight: CGFloat,
        expandedHeight: CGFloat,
        safeBottom: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            // Grabber handle
            grabberHandle
            
            if viewModel.isExpanded && !isLocked {
                expandedContent
            } else {
                collapsedContent
            }
        }
        .frame(height: (viewModel.isExpanded ? expandedHeight : collapsedHeight) + abs(min(0, viewModel.dragOffset)))
        .background(sheetBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .gesture(dragGesture)
    }
    
    // MARK: - Grabber
    private var grabberHandle: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 8)
        }
        .frame(height: grabberHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isLocked {
                viewModel.toggle()
                syncAppModeWithSheet()
            }
        }
    }
    
    // MARK: - Collapsed Content
    private var collapsedContent: some View {
        HStack(spacing: 12) {
            // Next actionable mini card
            Button {
                if !isLocked {
                    viewModel.expand()
                    syncAppModeWithSheet()
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready when you are")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Your next boss is waiting")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Add button - NOW OPENS DECK OVERLAY
            Button {
                if !isLocked {
                    appMode.enter(.deckOverlay(.cards))
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("Add")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                }
                .foregroundColor(.cyan)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cyan.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isLocked)
            
            // Menu button
            Button {
                if !isLocked {
                    viewModel.toggle()
                    syncAppModeWithSheet()
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.06))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - Expanded Content
    private var expandedContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Section 1: Routine Decks
                routinePacksSection
                
                // Section 2: Your Map (de-emphasized)
                yourMapSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Section: Routine Decks
    private var routinePacksSection: some View {
        let routines = Array(RoutineProvider.defaults.prefix(3))
        let accents: [(String, Color)] = [
            ("sun.horizon.fill", .orange),
            ("brain.head.profile", .purple),
            ("moon.stars.fill", .indigo)
        ]
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ROUTINE DECKS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(.cyan.opacity(0.8))
                
                Spacer()
                
                Button {
                    showRoutinePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.system(.caption, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.cyan)
                }
            }
            
            // Horizontal pack cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                        let accent = accents[index % accents.count]
                        RoutinePackCard(
                            title: routine.name,
                            icon: accent.0,
                            color: accent.1,
                            taskCount: routine.presets.count,
                            isEnabled: !isLocked,
                            onTap: {
                                addRoutineDeck(routine)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Section: Your Map
    private var yourMapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                viewModel.collapse()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text("Your Map")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("点一个房间开始")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.04))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Drag Gesture
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isLocked else { return }
                viewModel.dragOffset = value.translation.height
            }
            .onEnded { value in
                viewModel.handleDragEnd(
                    velocity: value.predictedEndTranslation.height - value.translation.height,
                    threshold: snapThreshold
                )
                syncAppModeWithSheet()
            }
    }

    private func syncAppModeWithSheet() {
        guard !isLocked else { return }
        let target: AppMode = viewModel.isExpanded ? .homeExpanded : .homeCollapsed
        if appMode.mode != target {
            appMode.enter(target)
        }
    }
    
    private func addRoutineDeck(_ routine: RoutineTemplate) {
        deckStore.addDeck(from: routine, using: cardStore)
        appMode.enter(.deckOverlay(.decks))
    }
    
    // MARK: - Background
    private var sheetBackground: some View {
        LinearGradient(
            colors: [
                Color(white: 0.12),
                Color(white: 0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
private struct RoutinePackCard: View {
    let title: String
    let icon: String
    let color: Color
    let taskCount: Int
    let isEnabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(taskCount) tasks")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.gray)
            }
            .padding(12)
            .frame(width: 110)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

// MARK: - Collapsed Height Provider (for map inset)
struct MapBottomSheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 116 // collapsedHeight + padding
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
