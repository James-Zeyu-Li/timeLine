import SwiftUI
import TimeLineCore
import Combine

struct PlanSheetView: View {
    @EnvironmentObject var timelineStore: TimelineStore
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var libraryStore: LibraryStore
    @EnvironmentObject var daySession: DaySession // Needed for logic
    @EnvironmentObject var engine: BattleEngine   // Needed for timeline placement
    @EnvironmentObject var stateManager: AppStateManager // Needed for persistence
    @Environment(\.dismiss) var dismiss
    
    @StateObject var viewModel = PlanViewModel()
    @State private var selectedFinishBy: FinishBySelection = .tonight
    @State private var isKeyboardVisible = false
    
    // Feedback State
    @State var showCommitSuccess = false
    @State var commitMessage = ""
    @State private var showConflictAlert = false
    
    // Theme Colors (Dark Translucent)
    private let bgGradient = LinearGradient(
        colors: [Color.black.opacity(0.85), Color.black.opacity(0.95)],
        startPoint: .top,
        endPoint: .bottom
    )
    private let primaryText = Color.white.opacity(0.9)
    private let secondaryText = Color.white.opacity(0.6)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !isKeyboardVisible {
                    // Header
                    HStack {
                        Text("Expedition Log")
                            .font(.title2)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                            .foregroundColor(primaryText)
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                    }
                    .padding()
                } else {
                     // Collapsed Header
                     HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                             Image(systemName: "chevron.down")
                                 .font(.system(size: 20, weight: .bold))
                                 .foregroundStyle(Color.white.opacity(0.3))
                        }
                     }
                     .padding(.top, 12)
                     .padding(.trailing)
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // 1. Task Library
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TASK LIBRARY")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundColor(secondaryText)
                                .padding(.leading, 4)
                            
                            ResearchLogDrawer()
                        }
                        .padding(.horizontal)
                        
                        // 2. Today's Plan (Inbox)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("INBOX / DRAFT AREA")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1)
                                .foregroundColor(secondaryText)
                                .padding(.leading, 4)
                            
                            // Magic Input
                            MagicInputBar(text: $viewModel.draftText, onCommit: {
                                viewModel.parseAndAdd(finishBy: selectedFinishBy)
                            })
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                            
                            // Inbox List (Direct from TimelineStore)
                            if timelineStore.inbox.isEmpty {
                                Text("No pending quests.")
                                    .font(.caption)
                                    .foregroundStyle(secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 20)
                            } else {
                                PlanInboxListView(
                                    inboxNodes: timelineStore.inbox,
                                    cardStore: cardStore,
                                    onDelete: { id in
                                        viewModel.deleteInboxItem(id: id)
                                    },
                                    onUpdateFinishBy: { id, finishBy in
                                        viewModel.updateTaskDeadline(nodeId: id, finishBy: finishBy)
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                        
                        // 3. Current Map (Reflects what's actually scheduled)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.vertical)
                }
                .scrollDismissesKeyboard(.interactively)
                
                // Commit Action (Launch Expedition)
                if !timelineStore.inbox.isEmpty {
                    VStack {
                        Divider().overlay(Color.white.opacity(0.1))
                        Button(action: {
                            if engine.state == .fighting || engine.state == .paused {
                                showConflictAlert = true
                            } else {
                                commitAndFeedback()
                            }
                        }) {
                            HStack {
                                Image(systemName: "safari.fill") // Compass/Safari icon
                                Text("Launch Expedition (\(timelineStore.inbox.count) Specimens)")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.8))
                            .foregroundStyle(.white)
                            .cornerRadius(16)
                            .padding()
                        }
                        .alert("Expedition Launched", isPresented: $showCommitSuccess) {
                            Button("OK") { dismiss() }
                        } message: {
                            Text(commitMessage)
                        }
                        .alert("Focus in Progress", isPresented: $showConflictAlert) {
                            Button("Add to Queue") {
                                commitAndFeedback()
                            }
                            Button("Cancel", role: .cancel) { }
                        } message: {
                             Text("An expedition is already in progress. Add these tasks to the end of the queue?")
                        }
                    }
                    .background(.ultraThinMaterial)
                }
            }
            .background(bgGradient)
            .scrollContentBackground(.hidden)
            .onAppear {
                viewModel.configure(
                    timelineStore: timelineStore,
                    cardStore: cardStore,
                    daySession: daySession,
                    engine: engine,
                    stateManager: stateManager
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.spring()) { isKeyboardVisible = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.spring()) { isKeyboardVisible = false }
            }
        }
        .presentationDetents([.fraction(0.9)])
        .presentationCornerRadius(24)
        .presentationBackground(.clear)
    }
    
}
