import SwiftUI
import TimeLineCore

struct BonfireView: View {
    @EnvironmentObject var coordinator: TimelineEventCoordinator
    
    // Simple state to animate flame
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Fire Animation (Simulated)
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: 150, height: 150)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                
                Image(systemName: "flame.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 100)
                    .foregroundColor(.orange)
                    .scaleEffect(isAnimating ? 1.05 : 0.95)
                    .animation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isAnimating)
            }
            .onAppear {
                isAnimating = true
            }
            
            Text("Rest & Recover")
                .font(.title)
                .bold()
                .foregroundColor(.white)
            
            Text("Take a deep breath.")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Button(action: {
                coordinator.completeBonfire()
            }) {
                Text("Resume Journey")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(height: 55)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 50)
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}
