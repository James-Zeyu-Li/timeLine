import SwiftUI
import TimeLineCore

struct RootView: View {
    @EnvironmentObject var engine: BattleEngine
    
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
            
            // 🎯 新的浮动菜单系统 - 在所有视图中都可用
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingMenu()
                        .padding()
                }
            }
        }
        .animation(.easeInOut, value: engine.state)
    }
}

// Views are now in separate files
