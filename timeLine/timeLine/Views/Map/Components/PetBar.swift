import SwiftUI
import TimeLineCore

enum PetState: String {
    case idle
    case ready
    case focus
    case distracted
    case shielded
    case victory
}

struct PetBar: View {
    @EnvironmentObject var engine: BattleEngine
    @EnvironmentObject var daySession: DaySession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var animateBreath = false
    @State private var animateHop = false
    @State private var animateShake = false
    
    private var state: PetState {
        if engine.state == .victory {
            return .victory
        }
        if engine.state == .fighting {
            if engine.isImmune {
                return .shielded
            }
            if engine.wastedTime > 0 {
                return .distracted
            }
            return .focus
        }
        if engine.state == .resting {
            return .ready
        }
        if daySession.nodes.contains(where: { !$0.isCompleted }) {
            return .ready
        }
        return .idle
    }
    
    var body: some View {
        HStack(spacing: 12) {
            petAvatar
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(PixelTheme.textPrimary)
                Text(subtitle)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(PixelTheme.textSecondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 68)
        .background(
            RoundedRectangle(cornerRadius: PixelTheme.cornerLarge)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: PixelTheme.cornerLarge)
                        .stroke(PixelTheme.cardBorder.opacity(0.6), lineWidth: PixelTheme.strokeThin)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .onAppear { startAnimations() }
        .onChange(of: state) { _, _ in
            startAnimations()
        }
    }
    
    private var title: String {
        switch state {
        case .idle: return "Welcome"
        case .ready: return "Ready when you are"
        case .focus: return "Focus mode"
        case .distracted: return "Lets get back on track"
        case .shielded: return "Shielded"
        case .victory: return "Victory!"
        }
    }
    
    private var subtitle: String {
        switch state {
        case .idle: return "Pick a room to begin"
        case .ready: return "Your next boss is waiting"
        case .focus: return "Small steps, steady hits"
        case .distracted: return "One deep breath, then go"
        case .shielded: return "You are protected this round"
        case .victory: return "Nice win. Keep the pace"
        }
    }
    
    private var accessorySymbol: String {
        switch state {
        case .shielded: return "shield.fill"
        case .victory: return "star.fill"
        case .distracted: return "questionmark.circle.fill"
        case .focus: return "questionmark.circle.fill"
        case .ready: return "questionmark.circle.fill"
        case .idle: return "questionmark.circle.fill"
        }
    }
    
    private var accessoryColor: Color {
        switch state {
        case .shielded: return .cyan
        case .victory: return .yellow
        case .distracted: return .orange
        case .focus: return .green
        case .ready: return .blue
        case .idle: return .gray
        }
    }
    
    private var petAvatar: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: PixelTheme.cornerMedium)
                .fill(PixelTheme.petBody.opacity(0.9))
                .frame(width: 48, height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: PixelTheme.cornerMedium)
                        .stroke(PixelTheme.petBody.opacity(0.6), lineWidth: PixelTheme.strokeThin)
                )
                .shadow(color: PixelTheme.petShadow, radius: PixelTheme.shadowRadius, x: 0, y: 2)
                .scaleEffect(breathScale)
                .offset(y: hopOffset)
                .rotationEffect(shakeAngle)
            
            Image(systemName: accessorySymbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(accessoryColor)
                .padding(4)
        }
    }
    
    private var breathScale: CGFloat {
        guard !reduceMotion else { return 1.0 }
        if state == .victory { return 1.0 }
        if state == .distracted { return 1.0 }
        return animateBreath ? 1.04 : 1.0
    }
    
    private var hopOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        return animateHop ? -6 : 0
    }
    
    private var shakeAngle: Angle {
        guard !reduceMotion else { return .degrees(0) }
        return animateShake ? .degrees(4) : .degrees(0)
    }
    
    private var accessibilityLabel: String {
        "\(title). \(subtitle)"
    }
    
    private func startAnimations() {
        animateBreath = false
        animateHop = false
        animateShake = false
        
        guard !reduceMotion else { return }
        
        switch state {
        case .victory:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55).repeatForever(autoreverses: true)) {
                animateHop = true
            }
        case .distracted:
            withAnimation(.linear(duration: 0.12).repeatForever(autoreverses: true)) {
                animateShake = true
            }
        default:
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                animateBreath = true
            }
        }
    }
}
