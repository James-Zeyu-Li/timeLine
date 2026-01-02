import SwiftUI
import TimeLineCore

struct RestSuggestionBanner: View {
    let event: RestSuggestionEvent
    let onRest: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(messageText)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                Button(action: onRest) {
                    Text("休息 10 分钟")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.9))
                        )
                }
                .buttonStyle(.plain)
                
                Button(action: onContinue) {
                    Text("继续专注")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var messageText: String {
        let minutes = max(1, Int(event.focusedSeconds / 60))
        return "你已专注 \(minutes) 分钟，要休息 10 分钟吗？"
    }
}
