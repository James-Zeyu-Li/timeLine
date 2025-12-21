import SwiftUI
import Combine
import TimeLineCore

struct BattleView: View {
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var daySession: DaySession
    
    // Timer to drive the UI updates (since engine needs explicit ticks)
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Central Focus Area
            ZStack {
                // Background Rings
                Circle()
                    .stroke(Color(white: 0.1), lineWidth: 1)
                    .frame(width: 300, height: 300)
                
                Circle()
                    .stroke(Color(white: 0.1), lineWidth: 1)
                    .frame(width: 350, height: 350)
                    .opacity(0.5)
                
                if let boss = engine.currentBoss {
                    
                    if boss.style == .passive {
                        // --- PASSIVE UI ---
                        VStack(spacing: 24) {
                            VStack(spacing: 4) {
                                Text("REMINDER")
                                    .font(.system(size: 12, weight: .bold))
                                    .tracking(2)
                                    .foregroundColor(.gray)
                                
                                Text(boss.name.uppercased())
                                    .font(.system(.title, design: .rounded))
                                    .bold()
                            }
                            
                            Button(action: {
                                engine.completePassiveTask()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.2))
                                        .frame(width: 120, height: 120)
                                    
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(.green)
                                }
                            }
                            
                            Text("Tap when done")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else {
                        // --- ACTIVE BATTLE UI ---
                        Group {
                            // HP Ring
                            Circle()
                                .stroke(Color.red.opacity(0.15), lineWidth: 8)
                                .frame(width: 300, height: 300)
                            
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(Color.red, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 300, height: 300)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: progress)
                        }
                        
                        // Content
                        VStack(spacing: 16) {
                            
                            VStack(spacing: 4) {
                                Text("TASK")
                                    .font(.system(size: 12, weight: .bold))
                                    .tracking(2)
                                    .foregroundColor(.gray)
                                
                                Text(boss.name.uppercased())
                                    .font(.system(.title3, design: .rounded))
                                    .bold()
                            }
                            
                            // Hero Timer
                            Text(formatTime(boss.maxHp - (boss.maxHp - boss.currentHp + engine.wastedTime)))
                                .font(.system(size: 72, weight: .thin, design: .monospaced)) // Ultra Thin Hero
                                .foregroundColor(.white)
                                .shadow(color: .red.opacity(0.5), radius: 20, x: 0, y: 0) // Glow
                            
                            // Wasted Time Indicator
                            if engine.wastedTime > 0 {
                                HStack(spacing: 6) {
                                    Circle().fill(Color.red).frame(width: 6, height: 6)
                                    Text("WASTED: \(formatTime(engine.wastedTime))")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.red)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Minimalist Controls (Only for Active Style)
            if let boss = engine.currentBoss, boss.style == .focus {
                HStack(spacing: 40) {
                    // Retreat Button (Subtle)
                    Button(action: {
                        engine.retreat()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "flag")
                                .font(.system(size: 20))
                            Text("RETREAT")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                        }
                        .foregroundColor(Color(white: 0.4))
                    }
                    
                    // Immunity Button (Prominent if needed)
                    if engine.state == .fighting {
                        Button(action: { engine.grantImmunity() }) {
                            VStack(spacing: 8) {
                                if engine.isImmune {
                                    Image(systemName: "shield.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.blue)
                                    Text("SAFE")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1)
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "iphone")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                    Text("USE PHONE")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1)
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(width: 80, height: 80)
                            .background(
                                Circle()
                                    .stroke(engine.isImmune ? Color.blue : Color(white: 0.3), lineWidth: 1)
                            )
                        }
                        .disabled(engine.immunityCount <= 0 && !engine.isImmune)
                        .opacity((engine.immunityCount <= 0 && !engine.isImmune) ? 0.3 : 1.0)
                    }
                }
                .padding(.bottom, 60)
            } else {
                 Color.clear.frame(height: 140) // Spacer for passive
            }
            
            // DEBUG: Force Complete Button (Bottom Right Overlay)
            // Ideally this should be wrapped in #if DEBUG, but user requested it for manual testing.
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        engine.forceCompleteTask()
                    }) {
                        Image(systemName: "forward.end.fill") // Skip Icon
                            .font(.system(size: 20))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding()
                            .background(Color.black.opacity(0.01)) // Hit area
                    }
                }
            }
            .padding()
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .foregroundColor(.white)
        .onReceive(timer) { input in
            engine.tick(at: input)
            checkVictory()
        }
    }
    
    var progress: CGFloat {
        guard let boss = engine.currentBoss else { return 0 }
        return CGFloat(boss.currentHp / boss.maxHp)
    }
    
    func formatTime(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    func checkVictory() {
        if engine.state == .victory {
            daySession.advance()
        }
    }
}
