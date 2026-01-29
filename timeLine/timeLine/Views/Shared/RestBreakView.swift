import SwiftUI
import TimeLineCore

struct RestBreakView: View {
    @EnvironmentObject var coordinator: TimelineEventCoordinator
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: 150, height: 150)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)

                Image(systemName: "cup.and.saucer.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.orange)
                    .scaleEffect(isAnimating ? 1.05 : 0.95)
                    .animation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isAnimating)
            }
            .onAppear {
                isAnimating = true
            }

            Text("休息一下")
                .font(.title)
                .bold()
                .foregroundColor(.white)

            Text("计时已暂停，休息完继续专注。")
                .font(.subheadline)
                .foregroundColor(.gray)

            Spacer()

            Button(action: {
                coordinator.completeRestBreak()
            }) {
                Text("继续专注")
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
