import SwiftUI
import Combine
import TimeLineCore

struct RootView: View {
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var deckStore: DeckStore
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var coordinator: TimelineEventCoordinator
    
    @StateObject private var dragCoordinator = DragDropCoordinator()
    @StateObject internal var viewModel = RootViewModel()
    
    @State internal var showSettings = false
    @State private var showPlanSheet = false
    @State private var showFieldJournal = false
    @State private var showQuickBuilder = false
    @State private var showSettlement = false
    @State private var reminderTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    // Dock & Scroll State
    @State internal var showJumpButton = false
    @State internal var scrollToNowTrigger = 0
    
    // Feature Flags
    @AppStorage("useTimelineV2") internal var useTimelineV2 = false
    
    var body: some View {
        ZStack {
            // 16.1 Global Background (Parchment)
            PixelTheme.background
                .ignoresSafeArea()
            
            // 1. Base layer: Map or Battle/Rest screens
            baseLayer
            
            // 2. Deck overlay (visible during drag too, dimmed)
            deckLayer
            
            // 3. Empty timeline drop target (when no nodes exist)
            emptyDropLayer
            
            // 3. Dragging card on top
            draggingLayer
        }
        .environmentObject(appMode)
        .environmentObject(dragCoordinator)
        .animation(.easeInOut, value: engine.state)
        .animation(.spring(response: 0.35), value: appMode.mode)
        .overlay(
            GlobalDragTracker(
                isActive: appMode.isDragging,
                onChanged: { location in
                    guard appMode.isDragging else { return }
                    dragCoordinator.dragLocation = location
                },
                onEnded: {
                    guard appMode.isDragging else { return }
                    dragCoordinator.isDragEnded = true
                }
            )
            .allowsHitTesting(false)
        )
        // 移除全局 DragGesture(minimumDistance: 0)，解决 Timeline Scroll 被阻断的问题。
        .onChange(of: dragCoordinator.dragLocation) { _, newLocation in
            guard appMode.isDragging else { return }
            
            // 首次设置 initialDragLocation (若未设置)
            if dragCoordinator.initialDragLocation == nil {
                dragCoordinator.initialDragLocation = newLocation
            }
            
            // 计算相对位移
            if let start = dragCoordinator.initialDragLocation {
                dragCoordinator.dragOffset = CGSize(
                    width: newLocation.x - start.x,
                    height: newLocation.y - start.y
                )
            }
        }
        // 监听拖拽结束信号，触发 drop 逻辑
        .onChange(of: dragCoordinator.isDragEnded) { _, ended in
            if ended {
                if appMode.isDragging {
                    viewModel.handleDrop()
                }
                dragCoordinator.isDragEnded = false
            }
        }
        .sheet(isPresented: cardEditBinding) {
            if case .cardEdit(let id, _) = appMode.mode {
                CardDetailEditSheet(cardTemplateId: id)
            }
        }
        .sheet(isPresented: deckEditBinding) {
            if case .deckEdit(let id, _) = appMode.mode {
                DeckDetailEditSheet(deckId: id)
            }
        }
        .sheet(isPresented: $showSettlement) {
            DailySettlementView()
        }
        .onReceive(coordinator.uiEvents) { event in
            if case .showSettlement = event {
                showSettlement = true
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.showDeckToast, let _ = viewModel.lastDeckBatch {
                DeckPlacementToast(
                    title: "Deck placed",
                    onUndo: {
                        viewModel.undoLastDeckBatch()
                    }
                )
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if shouldShowReminder, let event = coordinator.pendingReminder {
                ReminderBanner(
                    event: event,
                    onComplete: {
                        coordinator.completeReminder(nodeId: event.nodeId)
                    },
                    onSnooze: {
                        coordinator.snoozeReminder(nodeId: event.nodeId)
                    },
                    onOpen: {
                        openReminderDetails(event)
                    }
                )
                .padding(.bottom, viewModel.showDeckToast ? 96 : 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if shouldShowRestSuggestion, let event = coordinator.pendingRestSuggestion {
                RestSuggestionBanner(
                    event: event,
                    onRest: {
                        coordinator.acceptRestSuggestion()
                    },
                    onContinue: {
                        coordinator.declineRestSuggestion()
                    }
                )
                .padding(.bottom, viewModel.showDeckToast ? 96 : 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if showsFloatingControls {
                VStack(spacing: 16) {
                    if showJumpButton {
                        JumpToNowButton(action: {
                            Haptics.impact(.medium)
                            scrollToNowTrigger += 1
                        })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    UnifiedBottomDock(
                        onZap: handleZapTap,
                        onPlan: { showPlanSheet = true },
                        onBackpack: { showFieldJournal = true }
                    )
                }
                .padding(.bottom, 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if coordinator.isRestBreakActive {
                RestBreakView()
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showPlanSheet) {
            PlanSheetView()
                .environmentObject(TimelineStore(daySession: daySession, stateManager: stateManager))
                .environmentObject(cardStore)
                .environmentObject(daySession)
                .environmentObject(engine)
                .presentationDetents([.fraction(0.85)])
        }
        .sheet(isPresented: $showFieldJournal) {
            DailySettlementView()
                .environmentObject(engine)
        }
        .sheet(isPresented: $showQuickBuilder) {
            QuickBuilderSheet()
        }
        .sheet(item: explorationReportBinding) { report in
            FocusGroupReportSheet(report: report)
        }
        .task {
            cardStore.seedDefaultsIfNeeded()
            deckStore.seedDefaultsIfNeeded(using: cardStore)
            
            viewModel.bind(
                engine: engine,
                daySession: daySession,
                stateManager: stateManager,
                cardStore: cardStore,
                deckStore: deckStore,
                appMode: appMode,
                dragCoordinator: dragCoordinator
            )
        }
        .onReceive(reminderTimer) { input in
            coordinator.checkReminders(at: input)
        }
    }
}
