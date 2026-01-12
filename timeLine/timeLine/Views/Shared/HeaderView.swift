import SwiftUI
import TimeLineCore

struct HeaderView: View {
    let focusedMinutes: Int
    let progress: Double
    var onDayTap: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                dayTapTarget {
                    HStack(spacing: 8) {
                        Text("Day")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        Text("1")
                            .font(.system(.title2, design: .rounded))
                            .bold()
                            .foregroundColor(.white)
                    }
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("\(focusedMinutes)")
                        .font(.system(.headline, design: .monospaced))
                        .bold()
                        .foregroundColor(.green)
                    Text("MIN")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.green.opacity(0.7))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            dayTapTarget {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("TODAY'S PROGRESS")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.white)
                    }
                    ProgressView(value: min(max(progress, 0), 1))
                        .progressViewStyle(.linear)
                        .tint(LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.9))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(LinearGradient(colors: [.clear, .cyan.opacity(0.15), .clear], startPoint: .leading, endPoint: .trailing))
            .frame(height: 2)
        }
    }
    
    private func dayTapTarget<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Button(action: { onDayTap?() }) {
            content()
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(onDayTap == nil)
        .accessibilityLabel("Open stats")
        .accessibilityHint("Shows focus history and consistency")
    }
}
