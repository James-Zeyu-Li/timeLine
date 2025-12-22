import SwiftUI

// MARK: - Onboarding View
/// First-launch tutorial that explains the roguelike focus metaphor.
/// Shows once, controlled by @AppStorage("hasSeenOnboarding").
struct OnboardingView: View {
    var onComplete: () -> Void
    @State private var currentPage = 0
    
    private let totalPages = 4
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentPage) {
                // Page 1: Journey
                OnboardingPage(
                    icon: "map.fill",
                    title: "Your Day is a Journey",
                    subtitle: "Each day is a fresh dungeon run.\nComplete tasks to progress through your timeline.",
                    color: .cyan
                ).tag(0)
                
                // Page 2: Boss Battles
                OnboardingPage(
                    icon: "flame.fill",
                    title: "Tasks are Bosses",
                    subtitle: "Focus time deals damage.\nDefeat bosses by staying focused.",
                    color: .orange
                ).tag(1)
                
                // Page 3: Strict Mode
                OnboardingPage(
                    icon: "shield.fill",
                    title: "Strict Focus",
                    subtitle: "No pause button.\nBackgrounding the app = Wasted Time.\nUse Immunity to safely check your phone.",
                    color: .red
                ).tag(2)
                
                // Page 4: Get Started
                OnboardingPage(
                    icon: "bolt.fill",
                    title: "Ready to Begin?",
                    subtitle: "Your first journey awaits.\nAdd tasks and start focusing.",
                    color: .green,
                    showStartButton: true,
                    onStart: onComplete
                ).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            // Skip button - always visible
            VStack {
                HStack {
                    Spacer()
                    Button("Skip") {
                        onComplete()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Onboarding Page
/// A single page in the onboarding flow.
struct OnboardingPage: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var showStartButton = false
    var onStart: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.5), radius: 20)
            
            // Title
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Subtitle
            Text(subtitle)
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            // Start button (only on last page)
            if showStartButton {
                Button(action: { onStart?() }) {
                    Text("Start Journey")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(color)
                        .cornerRadius(30)
                }
                .padding(.top, 24)
            }
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Preview
#Preview {
    OnboardingView(onComplete: {})
}
