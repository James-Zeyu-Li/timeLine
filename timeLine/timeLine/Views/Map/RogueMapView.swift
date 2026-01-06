import SwiftUI
import TimeLineCore

struct RogueMapView: View {
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var coordinator: TimelineEventCoordinator
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var dragCoordinator: DragDropCoordinator
    
    // View Model
    @StateObject private var viewModel = MapViewModel()
    
    @AppStorage("use24HourClock") private var use24HourClock = true
    
    @State private var showStats = false
    @State private var nodeAnchors: [UUID: CGFloat] = [:]
    @State private var viewportHeight: CGFloat = 0
    @State private var showNodeEdit = false
    @State private var editingNodeTemplate: CardTemplate?
    @State private var editingNodeId: UUID?
    
    private let bottomFocusPadding: CGFloat = 140
    private let bottomSheetInset: CGFloat = 96
    
    private var upcomingNodes: [TimelineNode] { daySession.nodes.filter { !$0.isCompleted } }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Background: Map content
                mapContent(proxy: proxy)
            }
            .sheet(isPresented: $showStats) {
                StatsView()
            }
            .sheet(isPresented: $showNodeEdit) {
                TaskSheet(
                    templateToEdit: $editingNodeTemplate,
                    isEditingNode: true,
                    onSaveNode: { template in
                        guard let nodeId = editingNodeId else { return }
                        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
                        if template.remindAt != nil {
                            timelineStore.updateNodeByTime(id: nodeId, payload: template, engine: engine)
                        } else {
                            timelineStore.updateNode(id: nodeId, payload: template)
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Map Content
    @ViewBuilder
    private func mapContent(proxy: GeometryProxy) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    mapTrack
                    
                    let inboxTemplates = stateManager.inbox.compactMap { cardStore.get(id: $0) }
                    if !inboxTemplates.isEmpty {
                        InboxListView(
                            items: inboxTemplates,
                            onAdd: { item in viewModel.addInboxItem(item) },
                            onRemove: { item in viewModel.removeInboxItem(item.id) }
                        )
                        .padding(.horizontal, MapLayout.horizontalInset)
                        .padding(.vertical, 16)
                    }
                }
                .padding(.top, 16)
                // Reserve space for collapsed bottom sheet
                .padding(.bottom, bottomSheetInset)
            }
            .coordinateSpace(name: "mapScroll")
            .safeAreaInset(edge: .top) {
                HeaderView(
                    focusedMinutes: Int(engine.totalFocusedToday / 60),
                    progress: daySession.completionProgress,
                    onDayTap: { showStats = true }
                )
            }
            .background(PixelMapBackground())
            .overlay(alignment: .top) {
                if let banner = viewModel.banner {
                    InfoBanner(data: banner)
                        .padding(.top, 6)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.9), value: viewModel.banner)
            .onPreferenceChange(MapNodeAnchorKey.self) { value in
                nodeAnchors = value
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onEnded { _ in
                        snapToNearestNode(using: scrollProxy)
                    }
            )
            .onReceive(coordinator.uiEvents) { event in
                viewModel.handleUIEvent(event)
            }
            .onAppear {
                viewModel.bind(
                    engine: engine,
                    daySession: daySession,
                    stateManager: stateManager,
                    cardStore: cardStore,
                    use24HourClock: use24HourClock
                )
                
                viewportHeight = proxy.size.height
                scrollToActive(using: scrollProxy)
            }
            .onChange(of: use24HourClock) { _, newValue in
                viewModel.updatePreferences(use24HourClock: newValue)
            }
            .onChange(of: proxy.size.height) { _, newValue in
                viewportHeight = newValue
            }
            .onChange(of: daySession.currentIndex) { _, _ in
                scrollToActive(using: scrollProxy)
            }
            .onChange(of: engine.state) { _, _ in
                scrollToActive(using: scrollProxy)
            }
        }
    }

    private var mapTrack: some View {
        let nodes = Array(daySession.nodes.enumerated().reversed())
        let currentId = currentActiveId
        let nextId = upcomingNodes.first?.id
        
        return VStack(spacing: 26) {
            ForEach(nodes.indices, id: \.self) { offset in
                let item = nodes[offset]
                let index = item.offset
                let node = item.element
                let alignment: MapNodeAlignment = offset.isMultiple(of: 2) ? .left : .right
                let isCurrent = currentId == node.id
                let isNext = !isSessionActive && nextId == node.id
                let isFinal = index == daySession.nodes.indices.last
                let timeInfo = node.isCompleted ? nil : timeInfo(for: node)
                
                MapNodeRow(
                    node: node,
                    alignment: alignment,
                    isCurrent: isCurrent,
                    isNext: isNext,
                    isFinal: isFinal,
                    isPulsing: viewModel.pulseNextNodeId == node.id,
                    timeInfo: timeInfo,
                    onTap: { handleTap(on: node) },
                    onLongPress: { handleLongPress(on: node) }
                )
                .id(node.id)
            }
        }
        .padding(.horizontal, MapLayout.horizontalInset)
        .padding(.bottom, bottomFocusPadding)
    }
    
    private var isSessionActive: Bool {
        switch engine.state {
        case .fighting, .paused, .frozen, .resting:
            return true
        default:
            return false
        }
    }
    
    private var currentActiveId: UUID? {
        isSessionActive ? daySession.currentNode?.id : nil
    }
    
    private var mapAnchorY: CGFloat {
        if !isSessionActive {
            return 0.5
        }
        guard viewportHeight > 0 else { return 0.82 }
        let anchor = 1 - (bottomFocusPadding / viewportHeight) - (bottomSheetInset / viewportHeight)
        return min(0.9, max(0.7, anchor))
    }
    
    private func handleTap(on node: TimelineNode) {
        guard !node.isCompleted else {
            Haptics.impact(.light)
            return
        }

        if case .battle = node.type {
            let behavior = node.effectiveTaskBehavior { id in
                cardStore.get(id: id)
            }
            if behavior == .reminder {
                coordinator.completeReminder(nodeId: node.id)
                Haptics.impact(.medium)
                return
            }
        }

        let isFirstUpcoming = upcomingNodes.first?.id == node.id
        if !isSessionActive && isFirstUpcoming {
            // Allow start even if lock state is stale.
        } else {
            guard !node.isLocked, !node.isCompleted else {
                Haptics.impact(.light)
                return
            }
        }
        
        switch node.type {
        case .battle(let boss):
            if node.id != daySession.currentNode?.id {
                Haptics.impact(.medium)
                daySession.setCurrentNode(id: node.id)
                engine.startBattle(boss: boss)
                stateManager.requestSave()
            } else {
                if engine.state == .frozen {
                    engine.resumeFromFreeze()
                    stateManager.requestSave()
                } else if engine.state != .fighting {
                    engine.startBattle(boss: boss)
                } else {
                    Haptics.impact(.light)
                }
            }
        case .bonfire(let duration):
            if node.id != daySession.currentNode?.id {
                Haptics.impact(.medium)
                daySession.setCurrentNode(id: node.id)
                engine.startRest(duration: duration)
                stateManager.requestSave()
            } else {
                engine.startRest(duration: duration)
            }
        case .treasure:
            break
        }
    }
    
    private func handleLongPress(on node: TimelineNode) {
        guard case .battle(let boss) = node.type else { return }
        if let templateId = boss.templateId, let template = cardStore.get(id: templateId) {
            editingNodeTemplate = template
        } else {
            editingNodeTemplate = CardTemplate(
                id: boss.templateId ?? UUID(),
                title: boss.name,
                icon: "bolt.fill",
                defaultDuration: boss.maxHp,
                tags: [],
                energyColor: .focus,
                category: boss.category,
                style: boss.style,
                taskMode: node.effectiveTaskMode { id in
                    cardStore.get(id: id)
                },
                remindAt: boss.remindAt,
                leadTimeMinutes: boss.leadTimeMinutes
            )
        }
        editingNodeId = node.id
        showNodeEdit = true
    }
    
    private func timeInfo(for node: TimelineNode) -> MapTimeInfo? {
        if case .battle(let boss) = node.type, boss.recommendedStart != nil, boss.remindAt == nil {
            return MapTimeInfo(absolute: nil, relative: nil, isRecommended: true)
        }
        guard let estimate = viewModel.estimatedStartTime(for: node, upcomingNodes: upcomingNodes) else { return nil }
        return MapTimeInfo(
            absolute: estimate.absolute,
            relative: estimate.relative,
            isRecommended: false
        )
    }
    
    private func scrollToActive(using proxy: ScrollViewProxy) {
        let targetId = isSessionActive ? daySession.currentNode?.id : upcomingNodes.first?.id
        guard let targetId else { return }
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                proxy.scrollTo(targetId, anchor: UnitPoint(x: 0.5, y: mapAnchorY))
            }
        }
    }
    
    private func snapToNearestNode(using proxy: ScrollViewProxy) {
        guard !nodeAnchors.isEmpty else { return }
        let targetY = viewportHeight * mapAnchorY
        let nearest = nodeAnchors.min { lhs, rhs in
            abs(lhs.value - targetY) < abs(rhs.value - targetY)
        }
        guard let id = nearest?.key else { return }
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: mapAnchorY))
            }
        }
    }
}

private struct MapNodeRow: View {
    let node: TimelineNode
    let alignment: MapNodeAlignment
    let isCurrent: Bool
    let isNext: Bool
    let isFinal: Bool
    let isPulsing: Bool
    let timeInfo: MapTimeInfo?
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var dragCoordinator: DragDropCoordinator
    
    @State private var preventTap = false
    @State private var containerWidth: CGFloat = 0
    
    var body: some View {
        ZStack {
            PixelTrail()
                .frame(width: PixelTheme.baseUnit * 1.5)
                .frame(maxHeight: .infinity)
            
            PixelTerrainTile(type: terrainType)
                .frame(width: terrainWidth, height: terrainHeight)
                .opacity(0.35)
                .offset(y: 18)
            
            if showHeroMarker {
                PixelHeroMarker()
                    .offset(x: alignment == .left ? -120 : 120, y: -24)
            }
            
            Button(action: {
                if preventTap {
                    preventTap = false
                    return
                }
                onTap()
            }) {
                HStack(spacing: 12) {
                    iconBadge
                    VStack(alignment: .leading, spacing: 4) {
                        Text(titleText)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(PixelTheme.textPrimary)
                            .lineLimit(1)
                        
                        if let timeInfo {
                            HStack(spacing: 6) {
                                if let absolute = timeInfo.absolute {
                                    Text(absolute)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(PixelTheme.accent)
                                }
                                if let relative = timeInfo.relative {
                                    Text(relative)
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundColor(PixelTheme.textSecondary)
                                }
                                if timeInfo.isRecommended {
                                    Text("RECOMMENDED")
                                        .font(.system(size: 8, weight: .bold))
                                        .tracking(0.6)
                                        .foregroundColor(PixelTheme.accent)
                                }
                            }
                        }
                    }
                    Spacer()
                    if let badge = statusBadge {
                        Text(badge.text)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(badge.color.opacity(0.2))
                            .foregroundColor(badge.color)
                            .cornerRadius(PixelTheme.cornerSmall)
                    } else if isFinal {
                        Text("FINAL")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(PixelTheme.cornerSmall)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(width: cardWidth, height: cardHeight)
                .background(cardBackground)
                .overlay(cardBorder)
                .overlay(dropTargetOverlay)
                .overlay(deckGhostOverlay, alignment: .topTrailing)
                .opacity(node.isLocked ? 0.45 : 1)
                .scaleEffect(cardScale)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: cardScale)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier(nodeAccessibilityId)
            .offset(x: alignment == .left ? -cardOffsetX : cardOffsetX)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        guard canEditNode, !appMode.isDragging else { return }
                        preventTap = true
                        onLongPress()
                    }
            )
        }
        .frame(height: 120)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        containerWidth = geo.size.width
                    }
                    .onChange(of: geo.size.width) { _, newValue in
                        containerWidth = newValue
                    }
                    .preference(
                        key: MapNodeAnchorKey.self,
                        value: [node.id: geo.frame(in: .named("mapScroll")).midY]
                    )
                    .preference(
                        key: NodeFrameKey.self,
                        value: [node.id: geo.frame(in: .global)]
                    )
            }
        )
    }
    
    private var titleText: String {
        switch node.type {
        case .battle(let boss):
            return boss.name
        case .bonfire:
            return "Bonfire"
        case .treasure:
            return "Treasure"
        }
    }
    
    private var nodeAccessibilityId: String {
        switch node.type {
        case .battle(let boss):
            let compact = boss.name.replacingOccurrences(of: " ", with: "_")
            return "mapNode_\(compact)"
        case .bonfire:
            return "mapNode_Bonfire_\(node.id.uuidString.prefix(6))"
        case .treasure:
            return "mapNode_Treasure_\(node.id.uuidString.prefix(6))"
        }
    }

    private var cardWidth: CGFloat {
        let width = containerWidth > 0 ? containerWidth : 360
        let target = width * 0.75
        return min(max(target, 240), 320)
    }

    private var cardHeight: CGFloat {
        76
    }

    private var terrainWidth: CGFloat {
        max(140, cardWidth - 16)
    }

    private var terrainHeight: CGFloat {
        cardHeight - 4
    }

    private var cardOffsetX: CGFloat {
        let screenWidth = containerWidth > 0 ? containerWidth : 360
        let halfCard = cardWidth / 2
        let center = screenWidth / 2
        let offset = center - halfCard - MapLayout.horizontalInset
        return max(0, offset)
    }

    private var cardScale: CGFloat {
        1.0
    }
    
    private var showHeroMarker: Bool {
        isNext && !isCurrent && !node.isCompleted
    }
    
    private var canEditNode: Bool {
        if case .battle = node.type {
            return true
        }
        return false
    }

    private var terrainType: PixelTerrainType {
        switch node.type {
        case .bonfire:
            return .campfire
        case .treasure:
            return .plains
        case .battle(let boss):
            if boss.maxHp >= 3600 {
                return .cave
            }
            switch boss.category {
            case .study:
                return .forest
            case .work:
                return .plains
            case .gym, .rest:
                return .plains
            case .other:
                return .forest
            }
        }
    }
    
    private var iconBadge: some View {
        let icon: String
        let color: Color
        
        switch node.type {
        case .battle(let boss):
            icon = boss.style == .focus ? "bolt.fill" : "checkmark.circle.fill"
            color = boss.category.color
        case .bonfire:
            icon = "flame.fill"
            color = .orange
        case .treasure:
            icon = "star.fill"
            color = .yellow
        }
        
        return ZStack {
            RoundedRectangle(cornerRadius: PixelTheme.cornerSmall)
                .fill(color.opacity(0.25))
                .frame(width: 38, height: 38)
                .overlay(
                    RoundedRectangle(cornerRadius: PixelTheme.cornerSmall)
                        .stroke(color.opacity(0.6), lineWidth: PixelTheme.strokeThin)
                )
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
        }
        .overlay(
            RoundedRectangle(cornerRadius: PixelTheme.cornerMedium)
                .stroke(isPulsing ? PixelTheme.accent : Color.clear, lineWidth: PixelTheme.strokeBold)
                .scaleEffect(isPulsing ? 1.35 : 1)
                .opacity(isPulsing ? 0.7 : 0)
        )
        .shadow(color: isCurrent ? color.opacity(0.6) : .clear, radius: 10, x: 0, y: 0)
    }
    
    private var statusBadge: (text: String, color: Color)? {
        if isCurrent {
            return ("STARTED", .cyan)
        }
        if isNext {
            return ("NEXT", .green)
        }
        if node.isCompleted {
            return ("DONE", .gray)
        }
        if node.isLocked {
            return ("LOCKED", .orange)
        }
        return nil
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: PixelTheme.cornerLarge)
            .fill(
                LinearGradient(
                    colors: [PixelTheme.cardTop, PixelTheme.cardBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: PixelTheme.cornerLarge)
            .stroke(isCurrent ? PixelTheme.cardGlow : PixelTheme.cardBorder, lineWidth: isCurrent ? PixelTheme.strokeBold : PixelTheme.strokeThin)
            .shadow(
                color: isCurrent ? PixelTheme.cardGlow.opacity(0.6) : .clear,
                radius: PixelTheme.shadowRadius,
                x: PixelTheme.shadowOffset.width,
                y: PixelTheme.shadowOffset.height
            )
    }
    
    private var dropTargetOverlay: some View {
        Group {
            if appMode.isDragging {
                let isHovering = dragCoordinator.hoveringNodeId == node.id
                RoundedRectangle(cornerRadius: PixelTheme.cornerLarge)
                    .stroke(
                        isHovering ? PixelTheme.accent : Color.white.opacity(0.15),
                        lineWidth: isHovering ? PixelTheme.strokeBold + 1 : PixelTheme.strokeThin
                    )
                    .shadow(color: isHovering ? PixelTheme.accent.opacity(0.6) : .clear, radius: 8, x: 0, y: 0)
                    .allowsHitTesting(false)
                    .overlay(alignment: .bottom) {
                        if isHovering {
                            InsertHint(placement: dragCoordinator.hoveringPlacement)
                                .padding(.bottom, 8)
                        }
                    }
            }
        }
    }
    
    
    private var deckGhostOverlay: some View {
        Group {
            if appMode.isDragging,
               let summary = dragCoordinator.activeDeckSummary,
               dragCoordinator.hoveringNodeId == node.id {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Insert \(summary.count)")
                        .font(.system(size: 10, weight: .bold))
                    Text("·")
                        .font(.system(size: 10, weight: .bold))
                    Text(formatDuration(summary.duration))
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .padding(.trailing, 12)
                .padding(.top, 10)
            }
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return "\(minutes) min"
    }
}

private enum MapNodeAlignment {
    case left
    case right
}

private struct MapTimeInfo {
    let absolute: String?
    let relative: String?
    let isRecommended: Bool
}

private struct MapNodeAnchorKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct InsertHint: View {
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

private struct PixelTrail: View {
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

private struct PixelHeroMarker: View {
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

private struct PixelMapBackground: View {
    var body: some View {
        GeometryReader { _ in
            ZStack {
                LinearGradient(
                    colors: [
                        PixelTheme.backgroundTop,
                        PixelTheme.backgroundBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                Canvas { context, size in
                    let grid: CGFloat = PixelTheme.baseUnit * 5.5
                    let dot: CGFloat = 2
                    for y in stride(from: 0, through: size.height, by: grid) {
                        for x in stride(from: 0, through: size.width, by: grid) {
                            let rect = CGRect(x: x, y: y, width: dot, height: dot)
                            context.fill(Path(rect), with: .color(PixelTheme.backgroundGrid))
                        }
                    }
                    
                    let tile: CGFloat = PixelTheme.baseUnit * 2
                    for y in stride(from: grid * 0.6, to: size.height, by: grid * 2.6) {
                        for x in stride(from: grid * 0.5, to: size.width, by: grid * 2.8) {
                            let rect = CGRect(x: x, y: y, width: tile, height: tile)
                            context.fill(Path(rect), with: .color(PixelTheme.backgroundTile))
                        }
                    }
                }
                
                PixelTerrainBand()
                    .frame(height: 90)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .ignoresSafeArea()
    }
}

private struct PixelTerrainBand: View {
    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let tile: CGFloat = PixelTheme.baseUnit * 3
                let rows = 3
                let baseColor = PixelTheme.forest
                for row in 0..<rows {
                    let y = size.height - CGFloat(row + 1) * tile
                    let opacity = 0.25 - (CGFloat(row) * 0.06)
                    for x in stride(from: 0, to: size.width, by: tile) {
                        let rect = CGRect(x: x, y: y, width: tile - 1, height: tile - 1)
                        context.fill(Path(rect), with: .color(baseColor.opacity(opacity)))
                    }
                }
            }
        }
    }
}

private enum PixelTerrainType {
    case forest
    case plains
    case cave
    case campfire
}

private struct PixelTerrainTile: View {
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
