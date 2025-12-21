import SwiftUI
import TimeLineCore

struct RootView: View {
    @EnvironmentObject var engine: BattleEngine
    @State private var showStats = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Mode Switcher
            switch engine.state {
            case .idle, .victory, .retreat:
                // Return to Map when idle or finished
                TimelineView()
                    .transition(.opacity)
                
            case .fighting, .paused:
                // Stay in Battle screen even if paused
                BattleView()
                    .transition(.opacity)
                
            case .resting:
                BonfireView()
                    .transition(.opacity)
            }
            
            // Stats Button (Overlay)
            VStack {
                HStack {
                    Spacer()
                    Button(action: { showStats = true }) {
                        Image(systemName: "chart.bar.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .animation(.easeInOut, value: engine.state)
        .sheet(isPresented: $showStats) {
            StatsView()
        }
    }
}

// Views are now in separate files
