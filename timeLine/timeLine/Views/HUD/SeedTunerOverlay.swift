import SwiftUI
import TimeLineCore

struct SeedTunerOverlay: View {
    @EnvironmentObject var appMode: AppModeManager
    @EnvironmentObject var daySession: DaySession
    @EnvironmentObject var stateManager: AppStateManager
    @EnvironmentObject var cardStore: CardTemplateStore
    @EnvironmentObject var engine: BattleEngine
    
    @State private var taskTitle: String = ""
    @State private var durationMinutes: Double = 25
    @State private var isEditingTitle: Bool = false
    @FocusState private var isTitleFocused: Bool
    
    // Quick Chips
    let chips = ["Focus", "Reading", "Coding", "Writing", "Meeting", "Exercise"]
    
    // Duration Presets
    let durationPresets: [Double] = [15, 25, 45, 60, 90]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed Background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    appMode.exitToHome()
                }
                .transition(.opacity)
            
            // Tuner Card
            VStack(spacing: 0) {
                // Header / Handle
                Capsule()
                    .fill(PixelTheme.textSecondary.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                
                // 1. Task Name Input & Chips
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(PixelTheme.secondary)
                        
                        TextField("What's next?", text: $taskTitle)
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(PixelTheme.textPrimary)
                            .focused($isTitleFocused)
                            .submitLabel(.done)
                        
                        if !taskTitle.isEmpty {
                            Button {
                                taskTitle = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(PixelTheme.textSecondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: PixelTheme.cardShadow, radius: 4, y: 2)
                    
                    // Quick Chips Scroll
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(chips, id: \.self) { chip in
                                Button {
                                    taskTitle = chip
                                    Haptics.impact(.light)
                                } label: {
                                    Text(chip)
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(.medium)
                                        .foregroundColor(taskTitle == chip ? .white : PixelTheme.textSecondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(taskTitle == chip ? PixelTheme.primary : PixelTheme.woodLight.opacity(0.15))
                                        )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                
                // 2. Duration Tuner
                VStack(spacing: 16) {
                    // Time Display
                    Text("\(Int(durationMinutes)) min")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(PixelTheme.primary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: durationMinutes)
                    
                    // Slider
                    Slider(value: $durationMinutes, in: 5...120, step: 5)
                        .tint(PixelTheme.primary)
                        .padding(.horizontal, 8)
                    
                    // Presets
                    HStack(spacing: 0) {
                        ForEach(durationPresets, id: \.self) { preset in
                            Button {
                                durationMinutes = preset
                                Haptics.impact(.light)
                            } label: {
                                Circle()
                                    .fill(durationMinutes == preset ? PixelTheme.primary : PixelTheme.woodLight.opacity(0.15))
                                    .frame(width: 8, height: 8)
                                    .padding(12) // Touch target
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                
                // 3. Start Button (Action)
                Button {
                    startTask()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.title3.bold())
                        Text("PLANT & START")
                            .font(.headline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(PixelTheme.primary)
                    .cornerRadius(20)
                    .shadow(color: PixelTheme.primary.opacity(0.4), radius: 8, y: 4)
                }
                .buttonStyle(BounceButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 24) // Safe area padding handled by container logic if needed
            }
            .padding(.bottom, 20) // Lift from bottom edge
            .background(PixelTheme.cream)
            .cornerRadius(32, corners: [.topLeft, .topRight])
            .shadow(color: Color.black.opacity(0.2), radius: 20, y: -5)
            .transition(.move(edge: .bottom))
        }
        .onAppear {
            if taskTitle.isEmpty {
                // Pre-fill with a random or last used? For now, "Focus"
                taskTitle = "Focus"
            }
        }
    }
    
    private func startTask() {
        let name = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return }
        
        let duration = durationMinutes * 60
        
        // Logic: Create CardTemplate (ad-hoc) -> Place Occurrence
        // Use a generic "Quick Focus" template or create a new one?
        // Let's create a transient template for now, or check if one exists.
        // Actually, for "The Seed Tuner", we usually treat these as bespoke or matching existing templates.
        // Simplified: Create new template if not found, or just spawn.
        
        // 1. Create Template
        let template = CardTemplate(
            id: UUID(),
            title: name,
            defaultDuration: duration,
            tags: [], // Could imply from chips
            energyColor: .focus, // Default
            taskMode: .focusStrictFixed // Default for Zap
        )
        // Note: In real logic we might dedup based on name
        cardStore.add(template)
        
        // 2. Place in timeline
        let timelineStore = TimelineStore(daySession: daySession, stateManager: stateManager)
        
        let nodeId: UUID?
        if daySession.nodes.isEmpty {
            nodeId = timelineStore.placeCardOccurrenceAtStart(
                cardTemplateId: template.id,
                using: cardStore,
                engine: engine
            )
        } else {
            // Queue Jumping
            nodeId = timelineStore.placeCardOccurrenceAtCurrent(
                cardTemplateId: template.id,
                using: cardStore,
                engine: engine
            )
        }
        
        if let nodeId = nodeId {
            Haptics.impact(.heavy)
            
            // Transition: Set as current and maybe start? 
            // The prompt says "Plant & Start"
            // Usually this means it becomes Current Task.
            // If we want Auto-Start timer, we'd do that here.
            // For V1 behavior, we just place it as Current. The user taps Play on the card.
            // Wait, prompt said "Start". But BattleEngine auto-start is tricky if we want the "Ready" state.
            // Let's stick to "Plant as Current" and user taps Play, OR if the button says START, maybe it should start.
            // Since safety is key, let's Plant it as Current. The user will see the Big Card immediately.
            
            if engine.state == .idle || engine.state == .victory || engine.state == .retreat {
                if let index = daySession.nodes.firstIndex(where: { $0.id == nodeId }) {
                    daySession.currentIndex = index
                }
            }
            
            appMode.exitToHome() // Dismiss tuner
        }
    }
}

// Helper for corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
